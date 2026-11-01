# shellcheck shell=bash
# Update the three PWC repositories without building in the live checkouts.
set -Eeuo pipefail
umask 077

usage() {
  cat <<'HELP'
Usage: pwc-update [--check]

Run as gusahlg on sighurt-server, without sudo.
Fetch main for project_watt_cubed, voxel-engine and pwc-package-manager;
build their release workspaces and every first-party mod; fast-forward the
checkouts; save the world; deploy and restart watt-server.service.

--check fetches and checks the update plan without building or deploying.
Local tracked changes, a branch other than main, and divergent commits are
refused. Untracked saves/configuration are preserved. No reset or clean runs.
Builds use two jobs by default (PWC_BUILD_JOBS overrides this).
Logs, releases and world backups: ~/.local/state/watt-server/
HELP
}

check_only=false
case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --check) check_only=true ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { usage >&2; exit 2; }

server_user='@PWC_USER@'
server_home='@PWC_HOME_DIR@'
state="$server_home/.local/state/watt-server"
game="$server_home/project_watt_cubed"
service=watt-server.service
repos=(project_watt_cubed voxel-engine pwc-package-manager)
jobs="${PWC_BUILD_JOBS:-2}"
health_timeout="${PWC_UPDATE_HEALTH_TIMEOUT:-60}"

die() { printf 'pwc-update: %s\n' "$*" >&2; exit 1; }
[[ $(id -un) == "$server_user" && ${HOME:-} == "$server_home" ]] ||
  die "Run as $server_user with its normal HOME, without sudo."
[[ $jobs =~ ^[1-9][0-9]*$ ]] || die 'PWC_BUILD_JOBS must be a positive integer.'
[[ $health_timeout =~ ^[1-9][0-9]*$ ]] || die 'PWC_UPDATE_HEALTH_TIMEOUT must be a positive integer.'
[[ ${#health_timeout} -le 3 && $health_timeout -le 300 ]] || die 'PWC_UPDATE_HEALTH_TIMEOUT must be at most 300 seconds.'
XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR
export GIT_TERMINAL_PROMPT=0
export CARGO_BUILD_JOBS="$jobs"
mkdir -p "$state/logs" "$state/releases" "$state/staging"
exec 9>"$state/update.lock"
flock -n 9 || die 'Another PWC update is already running.'
log="$state/logs/update-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
exec > >(tee -a "$log") 2>&1
printf 'PWC update started at %s; log: %s\n' "$(date -Is)" "$log"

declare -A old_revs new_revs
stage=''
release=''
previous=''
probe_pid=''
rollback_needed=false
backup_ready=false
worktrees=()

atomic_link() {
  local target=$1 link=$2
  ln -s "$target" "$link.next-$$"
  mv -Tf "$link.next-$$" "$link"
}

healthy() {
  local wanted=$1 pid exe
  systemctl --user is-active --quiet "$service" || return 1
  pid=$(systemctl --user show "$service" -p MainPID --value) || return 1
  [[ $pid =~ ^[1-9][0-9]*$ ]] || return 1
  exe=$(readlink -f "/proc/$pid/exe") || return 1
  [[ $exe == "$wanted/bin/watt_server" ]] || return 1
  ss -H -lunp '( sport = :5555 )' | rg "pid=$pid," >/dev/null
}

wait_healthy() {
  local wanted=$1 until_time=$((SECONDS + health_timeout))
  while (( SECONDS < until_time )); do
    if healthy "$wanted"; then
      sleep 3
      healthy "$wanted" && return 0
    fi
    sleep 1
  done
  return 1
}

restore_world() {
  local name
  for name in world.save world.save.bak; do
    if [[ -f $release/rollback/$name ]]; then
      cp -p "$release/rollback/$name" "$game/$name.restore-$$" || return 1
      mv -f "$game/$name.restore-$$" "$game/$name" || return 1
    elif [[ -f $release/rollback/$name.absent ]]; then
      rm -f "$game/$name" || return 1
    fi
  done
}

cleanup() {
  local status=$? repo
  trap - EXIT INT TERM HUP
  set +e
  cd "$server_home" || cd /
  if [[ -n $probe_pid ]]; then
    kill -TERM "$probe_pid" 2>/dev/null
    wait "$probe_pid" 2>/dev/null
  fi
  if $rollback_needed; then
    printf 'Deployment failed; restoring the previous executable and saved world.\n' >&2
    if ! systemctl --user stop "$service" || systemctl --user is-active --quiet "$service"; then
      printf 'Could not stop the candidate safely. World left untouched; backup: %s/rollback\n' "$release" >&2
      status=1
    elif $backup_ready && ! restore_world; then
      printf 'World restoration failed. Service left stopped; backup: %s/rollback\n' "$release" >&2
      status=1
    elif ! atomic_link "$previous" "$state/active-release"; then
      printf 'Could not restore the release link. Service left stopped; previous: %s\n' "$previous" >&2
      status=1
    else
      systemctl --user reset-failed "$service"
      systemctl --user start "$service"
      if wait_healthy "$previous"; then
        printf 'Previous server restored and listening on UDP 5555.\n'
      else
        printf 'Previous server failed its health check; inspect journalctl --user -u %s.\n' "$service" >&2
        status=1
      fi
    fi
  fi
  for repo in "${worktrees[@]}"; do
    git -C "$server_home/$repo" worktree remove --force "$stage/$repo" ||
      printf 'Cleanup incomplete: git -C %q worktree remove --force %q\n' "$server_home/$repo" "$stage/$repo" >&2
  done
  if (( status != 0 )); then
    printf 'Update failed (status %s). Log: %s\n' "$status" "$log" >&2
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

clean_main() {
  local repo=$1 dir="$server_home/$1" operation path
  [[ $(git -C "$dir" rev-parse --show-toplevel) == "$dir" ]] || die "$repo is not the expected checkout."
  [[ $(git -C "$dir" symbolic-ref --quiet --short HEAD) == main ]] || die "$repo must be on main."
  git -C "$dir" diff --quiet HEAD -- || die "$repo has tracked changes; commit or stash them yourself first."
  for operation in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
    path=$(git -C "$dir" rev-parse --git-path "$operation")
    [[ $path = /* ]] || path="$dir/$path"
    [[ ! -e $path ]] || die "$repo has an unfinished Git operation."
  done
}

check_collisions() {
  local repo=$1 dir="$server_home/$1" path
  while IFS= read -r -d '' path; do
    if git -C "$dir" cat-file -e "${new_revs[$repo]}:$path" 2>/dev/null; then
      die "$repo: upstream would overwrite untracked file $path. Move it yourself first."
    fi
  done < <(git -C "$dir" ls-files --others --exclude-standard -z)
  if [[ $repo == project_watt_cubed ]]; then
    [[ -z $(git -C "$dir" ls-tree --name-only "${new_revs[$repo]}" -- saves world.save world.save.bak ops.txt mods.toml) ]] ||
      die 'Upstream tracks a live save/policy path; refusing to overwrite server data.'
  fi
}

systemctl --user is-active --quiet "$service" || die "$service must be running before updating."
[[ $(systemctl --user show "$service" -p ExecStart --value) == *"$state/launch.sh"* ]] ||
  die "Unexpected $service launcher; refusing to replace it."
pid=$(systemctl --user show "$service" -p MainPID --value)
[[ $(basename "$(readlink -f "/proc/$pid/exe")") == watt_server ]] ||
  die 'The live watt_server executable is not ready; wait for the service to finish starting.'
ss -H -lunp '( sport = :5555 )' | rg "pid=$pid," >/dev/null ||
  die 'The live server is not listening on UDP 5555; resolve that before updating.'
for repo in "${repos[@]}"; do
  clean_main "$repo"
  old_revs[$repo]=$(git -C "$server_home/$repo" rev-parse HEAD)
  url=$(git -C "$server_home/$repo" remote get-url origin)
  case "$url" in
    "https://github.com/gusahlg/$repo"|"https://github.com/gusahlg/$repo.git"|"git@github.com:gusahlg/$repo.git"|"ssh://git@github.com/gusahlg/$repo.git") ;;
    *) die "$repo has an unexpected origin; expected gusahlg/$repo on github.com." ;;
  esac
done
for repo in "${repos[@]}"; do
  printf '\nFetching %s/main over HTTPS...\n' "$repo"
  timeout 180 git -C "$server_home/$repo" -c credential.interactive=false fetch --no-tags \
    "https://github.com/gusahlg/$repo.git" '+refs/heads/main:refs/remotes/origin/main'
  new_revs[$repo]=$(git -C "$server_home/$repo" rev-parse refs/remotes/origin/main)
  git -C "$server_home/$repo" merge-base --is-ancestor "${old_revs[$repo]}" "${new_revs[$repo]}" ||
    die "$repo/main diverged from upstream; resolve it yourself. No reset will be performed."
  check_collisions "$repo"
  printf '%s: %s -> %s\n' "$repo" "${old_revs[$repo]}" "${new_revs[$repo]}"
done
if $check_only; then
  printf '\nPreflight passed. Run pwc-update to build and deploy this plan.\n'
  exit 0
fi

# Pin the currently running executable before touching source branches. Future
# automatic restarts must never compile from a partly updated checkout.
if [[ ! -L $state/active-release ]]; then
  baseline=$(mktemp -d "$state/releases/baseline-XXXXXXXX")
  mkdir -p "$baseline/bin"
  pid=$(systemctl --user show "$service" -p MainPID --value)
  cp "/proc/$pid/exe" "$baseline/bin/watt_server"
  chmod 755 "$baseline/bin/watt_server"
  nix-store --add-root "$baseline/dev-shell" --indirect --realise "$(readlink -f "$state/dev-shell")"
  cp -p "$state/launch.sh" "$baseline/previous-launch.sh"
  atomic_link "$baseline" "$state/active-release"
fi
previous=$(readlink -e "$state/active-release")
[[ -x $previous/bin/watt_server && -e $previous/dev-shell ]] || die 'The active release is incomplete.'
cat > "$state/launch.sh.next-$$" <<LAUNCH
#!/run/current-system/sw/bin/bash
# Managed by pwc-update: run a complete release, independently of source checkouts.
set -euo pipefail
release=\$(readlink -e '$state/active-release')
cd '$game'
export WATT_ASSET_DIR="\$release/assets"
exec /run/current-system/sw/bin/nix develop "\$release/dev-shell" \\
  --command "\$release/bin/watt_server" --world world.save --port 5555
LAUNCH
chmod 755 "$state/launch.sh.next-$$"
mv -f "$state/launch.sh.next-$$" "$state/launch.sh"

stage=$(mktemp -d "$state/staging/update-XXXXXXXX")
release=$(mktemp -d "$state/releases/$(date -u +%Y%m%dT%H%M%SZ)-XXXXXXXX")
mkdir -p "$release/bin" "$state/build-target"
for repo in "${repos[@]}"; do
  git -C "$server_home/$repo" worktree add --detach "$stage/$repo" "${new_revs[$repo]}"
  worktrees+=("$repo")
  git -C "$stage/$repo" submodule update --init --recursive
  printf '%s\t%s\n' "$repo" "${new_revs[$repo]}" >> "$release/commits.tsv"
done
export CARGO_TARGET_DIR="$state/build-target"
printf '\nBuilding the game, renderer, package-manager workspaces and release binaries...\n'
cd "$stage/project_watt_cubed"
nice -n 10 nix develop --no-write-lock-file --override-input voxel-engine \
  "github:gusahlg/voxel-engine/${new_revs[voxel-engine]}" \
  --profile "$release/dev-shell" --command cargo build --release --locked --workspace --bins
for repo in voxel-engine pwc-package-manager; do
  (cd "$stage/$repo" && nice -n 10 nix develop "$release/dev-shell" --command cargo build --release --locked --workspace --bins)
done
find "$CARGO_TARGET_DIR/release" -maxdepth 1 -type f -executable \
  -exec install -m 755 -t "$release/bin" {} +
cp -a "$stage/project_watt_cubed/assets" "$release/assets"
[[ -x $release/bin/watt_server && -x $release/bin/pwc ]] || die 'Required release executables are missing.'

printf '\nBuilding a separate client with every first-party mod...\n'
export PWC_HOME="$stage/mod-instance"
export PWC_NO_WRAPPER=1
mkdir -p "$PWC_HOME/cache"
ln -s "$CARGO_TARGET_DIR" "$PWC_HOME/cache/target"
mod_sources=()
for manifest in "$stage/pwc-package-manager/mods/"*/mod.toml; do
  [[ -f $manifest ]] && mod_sources+=("${manifest%/mod.toml}")
done
(( ${#mod_sources[@]} > 0 )) || die 'No first-party mod packages were found.'
nix develop "$release/dev-shell" --command "$release/bin/pwc" setup \
  --pwc "$stage/project_watt_cubed" --repository "$stage/pwc-package-manager/mods"
nix develop "$release/dev-shell" --command "$release/bin/pwc" instance create update-check --use
nix develop "$release/dev-shell" --command "$release/bin/pwc" mod add "${mod_sources[@]}"
mod_build=$(nice -n 10 nix develop "$release/dev-shell" --command "$release/bin/pwc" build --force --print-dir | tail -n 1)
[[ $mod_build == "$PWC_HOME/cache/builds/"* && -d $mod_build ]] || die 'Package manager returned an unexpected build directory.'
install -m 755 "$mod_build/bin/pwc-game" "$mod_build/bin/pwc-golden" "$release/bin/"
cp "$PWC_HOME/data/instances/update-check/pwc.lock" "$release/mods.lock"
unset PWC_HOME PWC_NO_WRAPPER CARGO_TARGET_DIR

# Load and save a COPY of the live world with the candidate, on an ephemeral
# port. This catches incompatible saves/configuration before any downtime.
printf '\nChecking the candidate server against a copy of the current world...\n'
probe="$release/probe"
mkdir -p "$probe"
for name in world.save world.save.bak ops.txt mods.toml; do
  [[ ! -f $game/$name ]] || cp -p "$game/$name" "$probe/$name"
done
(
  cd "$probe"
  export WATT_DATA_DIR="$probe" WATT_ASSET_DIR="$release/assets"
  exec nix develop "$release/dev-shell" --command "$release/bin/watt_server" --world world.save --port 0
) > "$release/probe.log" 2>&1 &
probe_pid=$!
until_time=$((SECONDS + health_timeout))
while ! rg -q 'watt-cubed server listening on' "$release/probe.log"; do
  kill -0 "$probe_pid" 2>/dev/null || { cat "$release/probe.log"; die 'Candidate server exited during its startup check.'; }
  (( SECONDS < until_time )) || die "Candidate startup timed out; inspect $release/probe.log."
  sleep 1
done
sleep 3
kill -0 "$probe_pid" 2>/dev/null || die 'Candidate server did not remain running.'
kill -TERM "$probe_pid"
wait "$probe_pid"
probe_pid=''
[[ -s $probe/world.save ]] || die 'Candidate did not save its test world cleanly.'
! rg -q 'could not save ' "$release/probe.log" || die 'Candidate reported an error saving its test world.'

# Recheck after the long builds in case somebody edited a checkout meanwhile.
for repo in "${repos[@]}"; do
  clean_main "$repo"
  [[ $(git -C "$server_home/$repo" rev-parse HEAD) == "${old_revs[$repo]}" ]] || die "$repo moved during the build."
  check_collisions "$repo"
done
for repo in "${repos[@]}"; do
  git -C "$server_home/$repo" -c core.hooksPath=/dev/null merge --ff-only "${new_revs[$repo]}"
done

printf '\nBuild checks passed. Saving the world and deploying the candidate...\n'
rollback_needed=true
cutover_time=$(date -Is)
systemctl --user stop "$service"
if journalctl --user -u "$service" --since "$cutover_time" -o cat --no-pager | rg 'could not save ' >/dev/null; then
  die 'The old server reported a shutdown save error; refusing deployment.'
fi
mkdir -p "$release/rollback"
for name in world.save world.save.bak; do
  if [[ -f $game/$name ]]; then
    cp -p "$game/$name" "$release/rollback/$name"
  else
    touch "$release/rollback/$name.absent"
  fi
done
[[ -s $release/rollback/world.save ]] || die 'The old server did not leave a saved world; refusing deployment.'
backup_ready=true
atomic_link "$release" "$state/active-release"
systemctl --user reset-failed "$service"
systemctl --user start "$service"
wait_healthy "$release" || { journalctl --user -u "$service" -n 30 --no-pager; die 'New server failed its health check.'; }
atomic_link "$previous" "$state/previous-release"
rollback_needed=false
printf '\nPWC updated successfully. Server is healthy on UDP 5555.\nRelease: %s\nWorld backup: %s/rollback\n' "$release" "$release"

# PWC server updater

`pwc-update` is included in `sighurt-server`'s `environment.systemPackages`.
After activating that NixOS configuration, run it as `gusahlg`, without sudo:

```bash
pwc-update --check
pwc-update
```

To activate the configuration containing this command:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#sighurt-server
```

The package can also be built without activating the system:

```bash
nix build /etc/nixos#pwc-update
./result/bin/pwc-update --check
```

## What it updates and builds

The three checkouts under `/home/gusahlg` are `project_watt_cubed`,
`voxel-engine`, and `pwc-package-manager`. The updater fetches their public
GitHub `main` branches over HTTPS, including when origin is configured as
an SSH URL. It verifies the expected origin and records the exact revisions.
Each checkout must already be on `main`, have no tracked changes or unfinished
Git operation, and be eligible for a fast-forward. It checks that upstream
will not overwrite untracked files or take ownership of live save/policy paths.
`--check` updates the remote-tracking refs and prints this plan; it leaves source
branches, builds and the running service alone.

Detached Git worktrees preserve the live checkouts during compilation. The
game's Nix development environment supplies Rust, Slang and native libraries.
Its renderer input is overridden to the exact fetched renderer revision, while
the Cargo path dependency points at that renderer's sibling worktree. Every
workspace's release binaries are built with its committed Cargo lockfile.

PWC mods are native Rust packages compiled into client instances, rather than
server plugins. The updater also builds an isolated client containing every
first-party package from the package-manager checkout. This checks the mod API
and package compatibility without altering any existing user instance or lock.
All resulting executables and the game assets are copied into one release.

## Deployment and recovery

An exclusive `flock` prevents overlapping updates. Builds use two jobs by
default, at reduced scheduling priority; `PWC_BUILD_JOBS=1 pwc-update` lowers
the parallelism further. `PWC_UPDATE_HEALTH_TIMEOUT` changes the default 60s
startup deadline (maximum 300s).

On the first actual update, the currently running server executable and its Nix
environment are preserved as a baseline release. The launcher is changed to
run the selected release directly. The process still uses the original working
directory and `--world world.save --port 5555`; source edits and partial builds
can no longer influence automatic server restarts.

Before downtime, the candidate must start with a copy of the live world and
policy files, remain running, and save that copy on SIGTERM. The original
checkouts are rechecked and then advanced with `git merge --ff-only`.
The service is stopped cleanly, its shutdown journal is checked for save errors,
and `world.save` plus `world.save.bak` are backed up before the release switch.

The active-release symlink is replaced atomically. The new service must run the
candidate executable, own UDP 5555, and remain healthy. A failed activation
stops the candidate, restores the world backup and prior release, and starts
the old server. If the candidate cannot be stopped safely, restoration is
refused rather than overwriting a world that may still be in use. Successful
source fast-forwards are retained even when deployment is rolled back.

Logs and retained releases live under `~/.local/state/watt-server/`:

| Path | Purpose |
| --- | --- |
| `logs/update-*.log` | Full update output |
| `active-release` | Complete release selected by the launcher |
| `previous-release` | Release preceding the last successful deployment |
| `releases/*/commits.tsv` | Exact source revisions |
| `releases/*/mods.lock` | Exact packages of the built first-party client |
| `releases/*/rollback/` | World snapshots taken just before deployment |
| `releases/*/probe.log` | Candidate startup/shutdown check |
| `build-target/` | Reusable Cargo build cache |

Release environments are Nix garbage-collection roots. Releases and logs are
retained for recovery; inspect these directories periodically before removing
older releases. Keep the targets of `active-release` and `previous-release`.
An untrappable interruption such as SIGKILL or a power loss during deployment
cannot run the Bash recovery trap; the retained world snapshot and prior
release provide the recovery materials. The command does not promise that
arbitrary future main-branch changes will compile or accept old worlds.

## Validation

The Nix package's default checks run Bash syntax validation and ShellCheck.
`scripts/tests/pwc-update.py` exercises the transaction with real temporary Git
repositories and mocked builders/service tools, including source protection,
fetch/build/startup failures, successful deployment, and world rollback.
Run it with Python 3, Git, Bash and the normal core/utility commands on PATH:

```bash
python3 /etc/nixos/scripts/tests/pwc-update.py
```

## Research references

- [Nixpkgs writeShellApplication](https://nixos.org/manual/nixpkgs/unstable/#trivial-builder-writeShellApplication): dependency PATH and default syntax/ShellCheck validation.
- [Git worktree](https://git-scm.com/docs/git-worktree): detached worktrees for separate builds.
- [Git merge](https://git-scm.com/docs/git-merge): fast-forward-only updates that refuse divergence.
- [PWC package manager](https://github.com/gusahlg/pwc-package-manager): compiled-in mods, instances and lockfiles.
- Package-manager checkout: `docs/spec/build.md`, `docs/spec/filesystem.md`, and `docs/spec/cli.md` were inspected for build outputs, PWC_HOME isolation and CLI arguments.
- Game checkout: `flake.nix`, `src/bin/watt_server.rs`, and persistence/shutdown code were inspected for renderer pinning, launch arguments and world saving.

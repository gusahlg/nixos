{ pkgs }:

let
  checkStorage = import ./check-storage.nix { inherit pkgs; };
in
pkgs.writeShellApplication {
  name = "safe-rebuild";
  runtimeInputs = [ checkStorage pkgs.nixos-rebuild pkgs.util-linux pkgs.coreutils ];
  text = ''
    if [ "$#" -eq 0 ]; then
      echo "Usage: sudo safe-rebuild switch --flake /etc/nixos#sighurt" >&2
      exit 2
    fi
    if (( EUID != 0 )); then
      echo "Run safe-rebuild with sudo." >&2
      exit 2
    fi

    exec 9>/run/lock/safe-rebuild.lock
    if ! flock --nonblock 9; then
      echo "Another safe-rebuild is running; wait for it to finish." >&2
      exit 1
    fi
    check-storage 200

    # Also protect the first rebuild, before this configuration is activated.
    swap_file=/persist/swap/swapfile
    if [[ ! -f "$swap_file" || -L "$swap_file" ]] ||
       [[ "$(stat -c '%u:%a:%s' "$swap_file")" != 0:600:34359738368 ]] ||
       [[ "$(stat -c '%d' "$swap_file")" != "$(stat -c '%d' /persist)" ]]; then
      echo "Expected a root-owned, private 32 GiB swap file at $swap_file." >&2
      exit 1
    fi
    swap_active=false
    while read -r name _; do
      if [[ "$name" == "$swap_file" ]]; then
        swap_active=true
        break
      fi
    done < /proc/swaps
    if [[ "$swap_active" != true ]]; then
      swapon --priority 0 "$swap_file"
    fi

    # Explicit options cover both root's local store and daemon-backed builds.
    exec nixos-rebuild "$@" --max-jobs 1 --cores 2 \
      --option build-dir /data/nixos-data/nix-builds \
      --option min-free 107374182400 --option max-free 214748364800
  '';
}

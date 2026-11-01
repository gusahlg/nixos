{ pkgs }:

pkgs.writeShellApplication {
  name = "check-storage";
  runtimeInputs = [ pkgs.coreutils pkgs.util-linux ];
  text = ''
    if [ "$#" -gt 1 ]; then
      echo "Usage: check-storage [minimum-free-GiB] (default: 200 on each drive)" >&2
      exit 2
    fi

    minimum_gib="''${1:-200}"
    if [[ ! "$minimum_gib" =~ ^[1-9][0-9]{0,3}$ ]]; then
      echo "minimum-free-GiB must be an integer from 1 to 9999." >&2
      exit 2
    fi

    # Trigger the automount, then require the actual HDD, never a fallback
    # directory on the RAM-backed root or SSD.
    if ! stat /data/nixos-data >/dev/null 2>&1 ||
       [[ "$(findmnt --noheadings --raw --mountpoint /data --types ext4 --output UUID)" != e020b0d9-c58d-4687-b229-92d53109620d ]]; then
      echo "The expected HDD is not mounted at /data; refusing a large rebuild." >&2
      exit 1
    fi

    required=$((minimum_gib * 1024 * 1024 * 1024))
    for path in /nix/store /data; do
      available=$(df --block-size=1 --output=avail "$path" | tail -n 1)
      available="''${available//[[:space:]]/}"
      if [[ ! "$available" =~ ^[0-9]+$ ]]; then
        echo "Could not determine free space on $path." >&2
        exit 2
      fi
      available_human=$(numfmt --to=iec-i --suffix=B "$available")
      if (( available < required )); then
        echo "Low disk space: $path has $available_human available; require at least $minimum_gib GiB." >&2
        echo "Free space or move bulk data before starting a large rebuild." >&2
        exit 1
      fi
      echo "$path has $available_human available (minimum: $minimum_gib GiB)."
    done
  '';
}

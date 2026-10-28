# /etc/nixos/scripts/copy-latest-recording.nix
{ pkgs }:

pkgs.writeShellApplication {
  name = "copy-latest-recording";

  runtimeInputs = [
    pkgs.wf-recorder
    pkgs.wl-clipboard
    pkgs.libnotify
    pkgs.procps
    pkgs.coreutils
    pkgs.findutils
  ];

  text = ''
    set -euo pipefail

    DIR="$HOME/Videos/Recordings"

    if pgrep -x wf-recorder >/dev/null; then
      pkill -INT wf-recorder
      sleep 0.5
    fi

    LATEST="$(find "$DIR" -maxdepth 1 -type f -name '*.mp4' -printf '%T@ %p\n' 2>/dev/null \
              | sort -nr | head -n 1 | cut -d' ' -f2- || true)"

    if [[ -z "''${LATEST}" ]]; then
      notify-send "No recording found" "$DIR"
      exit 0
    fi

    # Copy as "file" URI list.
    # Many apps treat this like copying a file in a file manager.
    printf "file://%s\n" "$LATEST" | wl-copy --type text/uri-list

    notify-send "Recording stopped" "Copied file for pasting/upload: $(basename "$LATEST")"
  '';
}

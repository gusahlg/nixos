# /etc/nixos/scripts/toggle-recording.nix
{ pkgs }:

pkgs.writeShellApplication {
  name = "toggle-recording";

  runtimeInputs = [
    pkgs.wf-recorder
    pkgs.slurp
    pkgs.wl-clipboard
    pkgs.libnotify
    pkgs.procps
    pkgs.coreutils
  ];

  text = ''
    set -euo pipefail

    DIR="$HOME/Videos/Recordings"
    mkdir -p "$DIR"

    # If already recording -> stop
    if pgrep -x wf-recorder >/dev/null; then
      pkill -INT wf-recorder
      notify-send "Recording stopped"
      exit 0
    fi

    TS="$(date +%Y-%m-%d_%H-%M-%S)"
    OUT="$DIR/rec_$TS.mp4"

    # Select region, then record
    GEOM="$(slurp)"

    # If slurp was cancelled
    if [ -z "$GEOM" ]; then
      exit 0
    fi

    wf-recorder -g "$GEOM" -f "$OUT" & disown

    # Copy path immediately
    printf "%s" "$OUT" | wl-copy
    notify-send "Recording started" "Saved to: $OUT (path copied)"
  '';
}

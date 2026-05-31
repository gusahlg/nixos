# /etc/nixos/scripts/toggle-night-light.nix
{ pkgs }:

pkgs.writeShellApplication {
  name = "toggle-night-light";

  runtimeInputs = [
    pkgs.wlsunset
    pkgs.gammastep
    pkgs.procps
    pkgs.coreutils
  ];

  text = ''
    set -euo pipefail

    CMD_WLSUNSET=(wlsunset -t 3400 -g 0.90)   # warmer temp, slight dim

    if pgrep -x wlsunset >/dev/null; then
      pkill -x wlsunset
      exit 0
    fi

    if pgrep -x gammastep >/dev/null; then
      pkill -x gammastep
      exit 0
    fi

    # Prefer wlsunset. Since it is in runtimeInputs, it will always exist.
    "''${CMD_WLSUNSET[@]}" &
  '';
}

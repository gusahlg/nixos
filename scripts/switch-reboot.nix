# /etc/nixos/scripts/switch-reboot.nix
{ pkgs }:

let
  safeRebuild = import ./safe-rebuild.nix { inherit pkgs; };
in

pkgs.writeShellApplication {
  name = "switch-reboot";

  runtimeInputs = [
    pkgs.systemd
    safeRebuild
  ];

  text = ''
    set -euo pipefail

    if [ "$#" -ne 1 ]; then
      echo "Usage: switch-reboot <flake-host>"
      echo "Example: switch-reboot sighurt"
      exit 1
    fi

    host="$1"

    sudo ${safeRebuild}/bin/safe-rebuild switch --flake "/etc/nixos#$host"

    echo "NixOS rebuild succeeded. Rebooting..."
    sudo systemctl reboot
  '';
}

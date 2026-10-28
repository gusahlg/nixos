# /etc/nixos/scripts/switch-reboot.nix
{ pkgs }:

pkgs.writeShellApplication {
  name = "switch-reboot";

  runtimeInputs = [
    pkgs.nixos-rebuild
    pkgs.systemd
  ];

  text = ''
    set -euo pipefail

    if [ "$#" -ne 1 ]; then
      echo "Usage: switch-reboot <flake-host>"
      echo "Example: switch-reboot sighurt"
      exit 1
    fi

    host="$1"

    sudo nixos-rebuild switch --flake "/etc/nixos#$host"

    echo "NixOS rebuild succeeded. Rebooting..."
    sudo systemctl reboot
  '';
}

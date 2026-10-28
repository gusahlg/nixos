# /etc/nixos/modules/scripts.nix
{ pkgs, lib, ... }:

let
    load-project = import ../scripts/load-project.nix { inherit pkgs; inherit lib; };
    load-session = import ../scripts/load-session.nix { inherit pkgs; inherit lib; };

    record = import ../scripts/record.nix { inherit pkgs; };
    record-stop = import ../scripts/record-stop.nix { inherit pkgs; };

    night-light = import ../scripts/night-light.nix { inherit pkgs; };

    switch-reboot = import ../scripts/switch-reboot.nix { inherit pkgs; };
in
{
    environment.systemPackages = [
        load-project
        load-session
        record
        record-stop
        night-light
        switch-reboot
    ];
}

{ pkgs, ... }:

let
  roblox = import ../packages/roblox.nix { inherit pkgs; };
in
{
  # Install the launcher and desktop entry for every user on this host.
  environment.systemPackages = [ roblox.package ];
}

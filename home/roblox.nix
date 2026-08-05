{ pkgs, ... }:

let
  roblox = import ../packages/roblox.nix { inherit pkgs; };
in
{
  home.packages = [ roblox.package ];

  # Make the entry available immediately through the user's XDG data directory.
  # The package remains in home.packages so it is also part of the normal
  # NixOS-managed per-user profile after a system rebuild.
  xdg.dataFile."applications/roblox.desktop".source =
    "${roblox.desktopItem}/share/applications/roblox.desktop";
}

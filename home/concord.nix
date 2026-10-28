{ ... }:

{
  # concord (TUI Discord client) is installed as a system package from its
  # flake input; here we only manage its declarative config. Same approach as
  # nvim.nix — source files are pinned from this repo into ~/.config so edits
  # stay in version control. concord writes its mutable state/credentials under
  # ~/.local/state/concord, so these read-only symlinks don't get in its way.
  xdg.configFile = {
    "concord/config.toml".source = ./concord/config.toml;
    "concord/keymap.toml".source = ./concord/keymap.toml;
  };
}

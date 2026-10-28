{ ... }:

{
  # Keep the workstation shell, editor, terminal, browser, Discord TUI,
  # launcher, media, Git and tmux configuration. Desktop monitor rules,
  # gaming integrations, Roblox and Hackatime remain desktop-only.
  imports = [ ./home/workstation.nix ];
}

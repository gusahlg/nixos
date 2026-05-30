{ config, pkgs, ... }:

{
  home.username = "gusahlg";
  home.homeDirectory = "/home/gusahlg";

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    fastfetch
    ripgrep
    fd
    rust-analyzer
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  imports = [
    ./home/fish.nix
    ./home/fastfetch.nix
    ./home/mangohud.nix
    ./home/rio.nix
    ./home/nvim.nix
    ./home/qutebrowser.nix
    ./home/git.nix
    ./home/mpv.nix
    ./home/htop.nix
    ./home/fonts.nix
    ./home/tmux.nix
    ./home/tmuxp.nix
  ];
}

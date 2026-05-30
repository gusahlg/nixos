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
  ];

  programs.fish = {
    enable = true;

    shellAliases = {
      ll = "ls -la";
      gs = "git status";
      rebuild = "sudo nixos-rebuild switch";
    };

    interactiveShellInit = ''
      set fish_greeting
    '';
  };

  programs.fastfetch = {
    enable = true;

    settings = {
      logo.source = "nixos";
      display.separator = "  ";
      modules = [
        "title"
        "os"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "terminal"
        "cpu"
        "gpu"
        "memory"
      ];
    };
  };
}

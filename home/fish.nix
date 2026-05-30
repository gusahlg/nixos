{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

    plugins = [
      {
        name = "tide";
        inherit (pkgs.fishPlugins.tide) src;
      }
    ];

    shellAbbrs = {
      # General
      ll = "ls -lah";
      gs = "git status";
      gl = "git log --oneline --graph --decorate --all";
      v = "nvim";

      # Git
      ga = "git add";
      gap = "git add -p";
      gc = "git commit";
      gco = "git checkout";
      gd = "git diff";
      gds = "git diff --staged";
      gp = "git push";
      gpl = "git pull";
      gb = "git branch";

      # Cargo
      cb = "cargo build";
      cr = "cargo run";
      ct = "cargo test";
      cc = "cargo check";

      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    interactiveShellInit = ''
      set -g fish_greeting
      fish_vi_key_bindings
    '';
  };
}

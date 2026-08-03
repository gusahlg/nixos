{ pkgs, ... }:

{
  home.username = "gusahlg";
  home.homeDirectory = "/home/gusahlg";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Keep the development stack on the maintenance account rather than
  # exposing development applications in Louise's profile.
  home.packages = with pkgs; [
    blas
    cargo
    chezmoi
    clang
    claude-code
    clippy
    cmake
    fastfetch
    fd
    fzf
    gcc
    git-lfs
    glslang
    htop
    hyperfine
    libxkbcommon
    lapack
    ninja
    nnn
    nodejs
    nvtopPackages.full
    openblas
    pkg-config
    ripgrep
    rust-analyzer
    rustc
    rustfmt
    shaderc
    spirv-headers
    spirv-tools
    tmuxp
    vulkan-headers
    vulkan-loader
    vulkan-tools
    vulkan-validation-layers
    wl-clipboard
    (python3.withPackages (ps: with ps; [
      numpy
      scipy
      torch
      onnxruntime
    ]))
  ];

  home.sessionVariables.EDITOR = "nvim";
  home.sessionPath = [ "$HOME/.local/bin" ];

  imports = [
    ./home/fish.nix
    ./home/fastfetch.nix
    ./home/rio.nix
    ./home/nvim.nix
    ./home/concord.nix
    ./home/git.nix
    ./home/mpv.nix
    ./home/htop.nix
    ./home/fonts.nix
    ./home/tmux.nix
    ./home/tmuxp.nix
    ./home/zoxide.nix
    ./home/hackatime.nix
  ];
}

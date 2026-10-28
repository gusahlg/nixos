{ pkgs, ... }:

{
  # Shared development environment for the desktop and MacBook workstation
  # hosts. GPU-vendor tooling stays in the hardware-specific host modules.
  environment.systemPackages = with pkgs; [
    cargo
    chezmoi
    clang
    claude-code
    clippy
    cmake
    fastfetch
    fzf
    gcc
    git
    git-lfs
    glslang
    htop
    hyperfine
    libxkbcommon
    neovim
    ninja
    nnn
    nodejs
    pkg-config
    python3Packages.pip
    ripgrep
    rustc
    rustfmt
    shaderc
    spirv-headers
    spirv-tools
    unzip
    vim
    vulkan-headers
    vulkan-loader
    vulkan-tools
    vulkan-validation-layers
    wayland
    wget

    # BLAS/LAPACK and the same Python scientific/ML stack as the desktop.
    openblas
    blas
    lapack
    (python3.withPackages (
      ps: with ps; [
        numpy
        scipy
        torch
        onnxruntime
      ]
    ))

    pkgs.perf
  ];
}

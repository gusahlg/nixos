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
    ./home/concord.nix
    ./home/qutebrowser.nix
    ./home/tofi.nix
    ./home/git.nix
    ./home/mpv.nix
    ./home/htop.nix
    ./home/fonts.nix
    ./home/tmux.nix
    ./home/tmuxp.nix
    ./home/zoxide.nix
    ./home/hackatime.nix
  ];

  # Global ignore file for `fd`. Keeps the project-picker (and ad-hoc `fd`
  # use) from descending into bulk-data, cache, vendored and credential
  # trees. The picker in scripts/load-project.nix relies on this.
  home.file.".fdignore".text = ''
    # Bulk data / caches
    .cache/
    .local/
    .steam/
    .var/
    .factorio/
    .paradoxlauncher/
    My Games/
    Games/
    ai-data/
    TinyStories/
    browser-benchmark-results/
    Downloads/
    Pictures/
    Videos/
    PDX/

    # Language / package caches
    .cargo/registry/
    .cargo/git/
    .rustup/
    .npm/
    .npm-global/
    .ollama/
    .nv/
    .gradle/
    .m2/repository/
    .pyenv/
    .rbenv/
    .nvm/

    # Vendored / build output
    node_modules/
    target/
    dist/
    build/
    .next/
    .venv/
    venv/
    __pycache__/
    .mypy_cache/
    .pytest_cache/
    .tox/
    .terraform/
    .direnv/
    vendor/
    .git/

    # Credential / browser state
    .ssh/
    .gnupg/
    .pki/
    .mozilla/
    .thunderbird/
    .config/google-chrome/
    .config/chromium/
  '';
}

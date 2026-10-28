{ pkgs, ... }:

{
  home.username = "gusahlg";
  home.homeDirectory = "/home/gusahlg";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    fastfetch
    fd
    ripgrep
    rust-analyzer
  ];

  home.sessionVariables.EDITOR = "nvim";
  home.sessionPath = [ "$HOME/.local/bin" ];

  systemd.user.targets.river-session.Unit.Description = "River compositor session";

  imports = [
    ./fish.nix
    ./fastfetch.nix
    ./rio.nix
    ./nvim.nix
    ./concord.nix
    ./qutebrowser.nix
    ./tofi.nix
    ./git.nix
    ./mpv.nix
    ./htop.nix
    ./fonts.nix
    ./tmux.nix
    ./tmuxp.nix
    ./zoxide.nix
  ];

  # Shared ignore list used by fd and the project/session picker scripts.
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

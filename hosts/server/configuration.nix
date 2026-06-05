{ config, lib, pkgs, ... }:

{
  imports = [
    # Generate this on the target machine with: nixos-generate-config --show-hardware-config
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "sighurt-server";
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  time.timeZone = "Europe/Stockholm";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "sv-latin1";
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.tailscale.enable = true;

  users.users.gusahlg = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    openssh.authorizedKeys.keys = [
      # Add SSH public keys here, e.g.:
      # "ssh-ed25519 AAAA... user@host"
    ];
  };

  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [
    vim
    neovim
    git
    wget
    curl
    htop
    fastfetch
    ripgrep
    fzf
    tmux
    fish
    nnn
  ];

  programs.fish.enable = true;

  system.stateVersion = "25.11";
}

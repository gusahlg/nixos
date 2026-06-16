{ config, lib, pkgs, ... }:

{
  imports = [
    # Generate this on the target machine with: nixos-generate-config --show-hardware-config
    ./hardware-configuration.nix
  ];

  # Headless server: no GUI needed, so graphics acceleration is left off.
  # Uncomment this together with `weston` in systemPackages below if a
  # local graphical session is ever required.
  # hardware.graphics.enable = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Keep the Nix store from growing without bound on an always-on box:
  # deduplicate automatically and garbage-collect old generations weekly.
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Headless laptop-server: blank the built-in console/backlight after 60s of
  # inactivity so the screen is normally off. (Adjust the seconds as desired;
  # 0 disables blanking.)
  boot.kernelParams = [ "consoleblank=60" ];

  networking.hostName = "sighurt-server";
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    # Allow all traffic over the Tailscale interface (incl. SSH via 100.x addrs).
    trustedInterfaces = [ "tailscale0" ];
    # SSH reachable on all interfaces (LAN + Tailscale).
    allowedTCPPorts = [ 22 ];
    # Tailscale's UDP port for establishing direct (non-relayed) connections.
    allowedUDPPorts = [ config.services.tailscale.port ];
    # Loose reverse-path filtering so Tailscale's NAT-traversal packets aren't
    # dropped (recommended for hosts running Tailscale).
    checkReversePath = "loose";
  };

  time.timeZone = "Europe/Stockholm";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "sv-latin1";
  };

  # This is a laptop repurposed as an always-on headless server: never suspend
  # when the lid is closed, regardless of AC/battery/dock state.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # Don't let the system suspend/hibernate on its own (no desktop to do it, but
  # belt-and-suspenders for an always-on server).
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AuthenticationMethods = "publickey";
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII3n+0ub5N5WkzhLOq0ZPZcjeDVBMrjIFDyruOEwSEcm gustav@Fredriks-Air.localdomain"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjkDOw36d9LqkJ6luwXicOou/zBniUHNZNoRH4OycrY nixos-pc"
    ];
  };

  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [
    vim
    neovim
    claude-code
    # Minimal Wayland compositor, disabled for a headless server. Uncomment
    # this (and `hardware.graphics.enable` above) if a GUI is ever needed.
    # weston
    git
    wget
    curl
    htop
    fastfetch
    ripgrep
    fzf
    tmux
    fish
  ];

  programs.fish.enable = true;

  system.stateVersion = "25.11";
}

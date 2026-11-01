{ config, lib, pkgs, concord, home-manager, ... }:

let
  hardwareConfig = ./hardware-configuration.nix;
in
{
  # Generate this file on Louise's computer with `nixos-generate-config`.
  # Keeping it separate prevents this host from inheriting sighurt's disks,
  # NVIDIA settings, or monitor assumptions.
  imports = [
    home-manager.nixosModules.home-manager
    ../../modules/roblox.nix
    ../../modules/wakeonlan.nix
    ../../modules/distributed-gpu.nix
  ]
    ++ lib.optional (builtins.pathExists hardwareConfig) hardwareConfig;

  # RTX 4060 worker: llama-rpc-server on LAN port 50052 for sighurt's 3070.
  distributedGpu = {
    enable = true;
    role = "worker";
  };

  warnings = lib.optional (!(builtins.pathExists hardwareConfig)) ''
    Louise's hardware-configuration.nix is missing. The software profile can
    be evaluated, but must not be installed until the generated hardware file
    has been added at hosts/louise/hardware-configuration.nix.
  '';

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.gusahlg = import ../../home-louise.nix;
  };

  networking = {
    hostName = "louise";
    networkmanager.enable = true;
    # Wake-on-LAN is configured in ../../modules/wakeonlan.nix (via NetworkManager).
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts = [ 22 ];
      allowedUDPPorts = [ config.services.tailscale.port ];
      checkReversePath = "loose";
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "sv-latin1";

  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    # Use the proprietary NVIDIA driver instead of the default nouveau.
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      nvidiaPersistenced = true;
      open = false;
    };
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services = {
    openssh = {
      enable = true;
      openFirewall = false;
    };
    tailscale.enable = true;
    printing.enable = true;
    flatpak.enable = true;

    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      xkb.layout = "se";
      desktopManager.cinnamon.enable = true;
      displayManager.lightdm.enable = true;
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };

  services.displayManager.defaultSession = "cinnamon";
  security.rtkit.enable = true;

  users.users = {
    louise = {
      isNormalUser = true;
      description = "Louise";
      extraGroups = [
        "networkmanager"
        "video"
      ];
    };

    gusahlg = {
      isNormalUser = true;
      description = "Maintenance account";
      shell = pkgs.fish;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      packages = [ concord.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    };
  };

  programs.fish.enable = true;
  programs.gamemode.enable = true;
  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    protontricks.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  services.ollama.enable = true;

  environment.systemPackages = with pkgs; [
    firefox
    heroic
    lutris
    wineWow64Packages.staging
    winetricks
    protonup-qt
    equibop
    mangohud
    gamemode
    mpv
    unzip
    wget
  ];

  system.stateVersion = "26.05";
}

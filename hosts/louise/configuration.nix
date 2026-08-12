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
  ]
    ++ lib.optional (builtins.pathExists hardwareConfig) hardwareConfig;

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
    networkmanager = {
      enable = true;
      # Apply WoL through NetworkManager, which manages this interface.
      settings = {
        "connection-wol" = {
          "match-device" = "interface-name:enp4s0";
          "ethernet.wake-on-lan" = "magic";
        };
      };
    };
    # The default Wake-on-LAN policy wakes on magic packets.
    interfaces.enp4s0.wakeOnLan.enable = true;
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts = [ 22 ];
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
      extraGroups = [ "networkmanager" ];
    };

    gusahlg = {
      isNormalUser = true;
      description = "Maintenance account";
      shell = pkgs.fish;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      packages = [ concord.packages.${pkgs.system}.default ];
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

  # Keep the local API available for maintenance/development without assuming
  # a particular GPU acceleration backend before the hardware is known.
  services.ollama.enable = true;

  environment.systemPackages = with pkgs; [
    firefox
    heroic
    lutris
    wineWow64Packages.staging
    winetricks
    protonup-qt
    equibop
    ethtool
    wakeonlan
    mangohud
    gamemode
    mpv
    unzip
    wget
  ];

  system.stateVersion = "26.05";
}

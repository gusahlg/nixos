{
  concord,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/development.nix
    ../../modules/river.nix
    ../../modules/scripts.nix
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  # Kernel, device trees, m1n1/U-Boot payload, peripheral firmware extraction,
  # GPU support, sensors, and speaker-safe PipeWire configuration.
  hardware.asahi.enable = true;
  # Flakes cannot import firmware directly from /boot. Keep the installer's
  # firmware.cpio in the flake-local, gitignored firmware directory instead.
  hardware.asahi.peripheralFirmwareDirectory = ../../firmware;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # U-Boot exposes the ESP but does not provide writable EFI variables. The
  # Apple Silicon module also installs m1n1/boot.bin through systemd-boot.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  networking = {
    hostName = "macbook";
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts = [ 22 ];
      allowedUDPPorts = [ config.services.tailscale.port ];
      checkReversePath = "loose";
    };
  };

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "sv-latin1";
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services = {
    openssh = {
      enable = true;
      openFirewall = false;
      settings.PasswordAuthentication = true;
    };
    tailscale.enable = true;
    printing.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
    dbus.enable = true;
    pipewire = {
      enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };

  security.polkit.enable = true;
  security.rtkit.enable = true;

  users.users.gusahlg = {
    isNormalUser = true;
    description = "Gustav";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "render"
    ];
  };

  programs = {
    fish.enable = true;
    thunar.enable = true;
  };

  environment = {
    localBinInPath = true;
    sessionVariables.NIXOS_OZONE_WL = "1";
    systemPackages = with pkgs; [
      bemenu
      concord.packages.${pkgs.stdenv.hostPlatform.system}.default
      librewolf
      mpv
      tmux
      herdr
      tmuxp
      wf-recorder
      wlr-randr
      xwayland
      zathura
    ];
  };

  # Preserve the compatibility behavior chosen by the system already running
  # on this MacBook.
  system.stateVersion = "26.11";
}

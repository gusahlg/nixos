{ config, lib, pkgs, ... }:

let
  pkgsFixed = pkgs.extend (final: prev: {
    openldap = prev.openldap.overrideAttrs (old: {
      doCheck = false;
    });
  });
in
{
  imports = [
    ./hardware-configuration.nix
    ./modules/river.nix
    # Since I have VIA on my keyboard this is not needed
    # ./keyboard.nix
  ];

  # Defining the core system details is done in this file whilst other parts are imported instead.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "sighurt";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  time.timeZone = "Europe/Stockholm";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "sv-latin1";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.openssh.enable = true;
  services.printing.enable = true;
  services.dbus.enable = true;
  services.tailscale.enable = true;
  services.flatpak.enable = true;

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --cmd 'river -c /etc/river/init' --remember";
      user = "greeter";
    };
  };

  environment.localBinInPath = true;
  xdg.portal = {
    enable = true;

    wlr = {
      enable = true;
      settings = {
        screencast = {
          chooser_type = "simple";
          chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -ro";
          max_fps = 60;
        };
      };
    };

    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];

    config = {
      common = {
        default = [ "gtk" ];
      };

      river = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };
  };

  users.users.gusahlg = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  programs.gamemode.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.thunar.enable = true;

  services.ollama.enable = true;

  environment.systemPackages =
    (with pkgsFixed; [
      lutris
      wineWow64Packages.staging
      winetricks
    ])
    ++
    (with pkgs; [
      equibop

      # Cool browser.
      # surf
      claude-code
      rustfmt
      clippy
      mpv
      zathura
      fzf
      swaybg
      mangohud
      gamemode
      vim
      cargo
      rustc
      wget
      git
      neovim
      fastfetch
      ripgrep
      gcc
      river
      waybar
      wl-clipboard
      grim
      slurp
      tofi
      bemenu
      chezmoi
      rio
      fish
      tmux
      tmuxp
      nnn
      nodejs
      htop
      shaderc
      pkg-config
      wayland
      libxkbcommon
      vulkan-loader
      vulkan-headers
      vulkan-tools
      git-lfs
      cmake
      hyperfine
      wlsunset
      qutebrowser
      krita
      wf-recorder

      (pkgs.ollama.override {
        acceleration = "cuda";
      })
    ]);

  system.stateVersion = "25.11";
}

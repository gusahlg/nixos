{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes" ];

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
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
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
      command = "${pkgs.tuigreet}/bin/tuigreet --cmd river --remember";
      user = "greeter";
    };
  };

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

  environment.systemPackages = with pkgs; [
    equibop

# Cool browser.
#   surf

    claude-code
    rustfmt
    clippy
    mpv
    zathura
    fzf
    swaybg
    mangohud
    vim
    cargo
    rustc
    wget
    git
    neovim
    fastfetch
    ripgrep
    gcc
    river-classic
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

    (makeDesktopItem {
      name = "equibop-wayland";
      desktopName = "equibop";
      genericName = "Discord client";
      categories = [ "Network" "Chat" ];
      exec = "env NIXOS_OZONE_WL=1 ELECTRON_OZONE_PLATFORM_HINT=wayland equibop --ozone-platform=wayland";
      terminal = false;
    })
  ];

  services.ollama.enable = true;

  programs.river-classic.enable = true;
  programs.thunar.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  system.stateVersion = "25.11";
}

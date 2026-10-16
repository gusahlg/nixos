{
  config,
  lib,
  pkgs,
  concord,
  ...
}:

let
  pkgsFixed = pkgs.extend (
    final: prev: {
      openldap = prev.openldap.overrideAttrs (old: {
        doCheck = false;
      });
    }
  );
in
{
  imports = [
    ./hardware-configuration.nix
    ./impermanence.nix
    ../../modules/river.nix
    ../../modules/roblox.nix
    # Since I have VIA on my keyboard this is not needed
    # ../../keyboard.nix
    ../../modules/scripts.nix
    ../../modules/wakeonlan.nix
    ../../modules/distributed-gpu.nix
  ];

  # RTX 3070 master: local CUDA plus llama.cpp talking to louise's 4060 over Ethernet.
  distributedGpu = {
    enable = true;
    role = "master";
    workerHost = "louise.local";
  };

  # Defining the core system details is done in this file whilst other parts are imported instead.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Keep the Nix store from growing without bound: deduplicate automatically
  # and garbage-collect generations older than 30 days weekly. (The store hit
  # 100% disk with ~96 generations in Sep 2026 and broke nixos-rebuild.)
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "sighurt";
  networking.networkmanager.enable = true;
  # Wake-on-LAN is configured in ../../modules/wakeonlan.nix (via NetworkManager).
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    checkReversePath = "loose";
  };

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
    nvidiaPersistenced = true;
    open = false;
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };
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
      command = "${pkgs.tuigreet}/bin/tuigreet --cmd '${pkgs.river}/bin/river -c /etc/river/init' --remember";
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

  users.mutableUsers = false;

  users.users.gusahlg = {
    isNormalUser = true;

    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    hashedPasswordFile = "/persist/secrets/gusahlg-password";
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
    ++ (with pkgs; [
      equibop

      # Cool browser.
      # surf
      claude-code
      opencode
      chawan
      heroic
      herdr      
      xwayland
      concord.packages.${pkgs.stdenv.hostPlatform.system}.default
      rustfmt
      librewolf
      clippy
      mpv
      python3Packages.pip
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
      unzip
      neovim
      fastfetch
      ripgrep
      gcc
      clang
      ninja
      river
      wl-clipboard
      grim
      slurp
      tofi
      bemenu
      chezmoi
      wlr-randr
      rio
      fish
      tmux
      tmuxp
      nnn
      nodejs
      htop
      shaderc
      glslang
      spirv-tools
      spirv-headers
      pkg-config
      wayland
      libxkbcommon
      vulkan-loader
      vulkan-headers
      vulkan-tools
      vulkan-validation-layers
      git-lfs
      cmake
      hyperfine
      wlsunset
      qutebrowser
      krita
      wf-recorder

      # BLAS / LAPACK
      openblas
      blas
      lapack

      # Python + scientific/ML stack
      (python3.withPackages (
        ps: with ps; [
          numpy
          scipy
          torch
          onnxruntime
        ]
      ))

    ])
    ++ [
      pkgs.perf
    ];

  system.stateVersion = "25.11";
}

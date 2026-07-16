# /etc/nixos/modules/river.nix
{ pkgs, lib, gharialSrc, meanderSrc, ... }:

let
  font = "${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/Hack/HackNerdFont-Regular.ttf";

  # These are built from the local script definitions and added to PATH so
  # the Rust River init can refer to stable command names instead of stale
  # Nix store paths embedded in a generated shell script.
  createSession = import ../scripts/create-session.nix { inherit pkgs lib; };
  attachSession = import ../scripts/attach-session.nix { inherit pkgs lib; };
  loadSession = import ../scripts/load-session.nix { inherit pkgs lib; };
  nightLight = import ../scripts/night-light.nix { inherit pkgs; };
  record = import ../scripts/record.nix { inherit pkgs; };
  recordStop = import ../scripts/record-stop.nix { inherit pkgs; };

  gharial = pkgs.callPackage ../packages/gharial.nix {
    src = gharialSrc;
  };

  gharialInit = pkgs.callPackage ../packages/gharial-init.nix {
    gharialIpcSrc = "${gharialSrc}/crates/gharial-ipc";
    src = ../river/gharial-init;
  };

  meanderBar = pkgs.callPackage ../packages/meander-bar.nix {
    inherit font meanderSrc;
    src = ../river/meander-bar;
  };

  riverInit = pkgs.writeShellApplication {
    name = "river-init";
    text = ''
      export GHARIAL_DAEMON="${gharial}/bin/gharial"
      export FONT="${font}"
      exec "${gharialInit}/bin/gharial-init-rs"
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.river
    pkgs.rio
    gharial
    pkgs.qutebrowser
    pkgs.thunar
    pkgs.neovim
    pkgs.tofi
    meanderBar
    pkgs.wl-clipboard
    pkgs.cliphist
    pkgs.swaybg
    pkgs.grim
    pkgs.slurp
    pkgs.wireplumber
    pkgs.brightnessctl
    pkgs.playerctl
    pkgs.nerd-fonts.hack
    createSession
    attachSession
    loadSession
    nightLight
    record
    recordStop
  ];

  # River reads XKB_DEFAULT_* at compositor startup. The init binary reads
  # FONT at runtime, so a rebuild can change the store path safely.
  environment.sessionVariables = {
    XKB_DEFAULT_LAYOUT = "se";
    FONT = font;
  };

  environment.etc."river/init" = {
    mode = "0755";
    text = ''
      #!${pkgs.runtimeShell}
      exec ${riverInit}/bin/river-init "$@"
    '';
  };
}

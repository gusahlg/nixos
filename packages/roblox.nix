{ pkgs }:

let
  launcher = pkgs.writeShellApplication {
    name = "roblox";
    runtimeInputs = with pkgs; [
      flatpak
      libnotify
    ];
    text = ''
      # Keep Sober current, but still launch it when an update check fails
      # (for example, while offline).
      if ! flatpak update -y org.vinegarhq.Sober; then
        notify-send \
          --app-name="Roblox" \
          --urgency=normal \
          "Roblox update check failed" \
          "Starting the currently installed version of Sober."
      fi

      exec flatpak run org.vinegarhq.Sober "$@"
    '';
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "roblox";
    desktopName = "Roblox";
    genericName = "Roblox Player";
    comment = "Play, chat and explore on Roblox";
    icon = ../assets/roblox-icon.jpg;
    exec = "${launcher}/bin/roblox %u";
    terminal = false;
    categories = [ "Game" ];
    keywords = [
      "roblox"
      "sober"
      "game"
      "gaming"
    ];
    mimeTypes = [
      "x-scheme-handler/roblox"
      "x-scheme-handler/roblox-player"
    ];
    extraConfig = {
      PrefersNonDefaultGPU = "true";
      SingleMainWindow = "true";
    };
  };

  package = pkgs.symlinkJoin {
    name = "roblox";
    paths = [
      launcher
      desktopItem
    ];
  };
in
{
  inherit desktopItem launcher package;
}

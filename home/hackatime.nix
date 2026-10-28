{ pkgs, ... }:

let
  # Hackatime's terminal tracker (github.com/hackclub/terminal-wakatime).
  # The upstream release is a fully-static Go binary, so we just drop it into
  # the store as-is -- no autoPatchelf needed. Config lives in ~/.wakatime.cfg
  # (written imperatively by the hackatime installer).
  terminal-wakatime = pkgs.stdenv.mkDerivation rec {
    pname = "terminal-wakatime";
    version = "1.1.5";

    src = pkgs.fetchurl {
      url = "https://github.com/hackclub/terminal-wakatime/releases/download/v${version}/terminal-wakatime-linux-amd64";
      hash = "sha256-oTEGDF34fI3GgfMFMjtA/uHMo3WE/WiUM6xqhhEGgOE=";
    };

    dontUnpack = true;

    installPhase = ''
      install -Dm755 $src $out/bin/terminal-wakatime
    '';
  };
in
{
  # wakatime-cli is what vim-wakatime shells out to for heartbeats; providing
  # it from nixpkgs (found via g:wakatime_CLIPath in nvim/lua/plugins/
  # wakatime.lua) beats the plugin's self-downloaded binary on NixOS.
  home.packages = [
    terminal-wakatime
    pkgs.wakatime-cli
  ];

  # Register the fish preexec/postexec heartbeat hooks. This is the line the
  # hackatime installer failed to append because home-manager owns config.fish.
  programs.fish.interactiveShellInit = ''
    ${terminal-wakatime}/bin/terminal-wakatime init fish | source
  '';
}

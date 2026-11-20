{ pkgs }:

pkgs.writeShellApplication {
  name = "pwc-update";
  runtimeInputs = with pkgs; [
    bash
    coreutils
    findutils
    git
    iproute2
    nix
    ripgrep
    systemd
    util-linux
  ];
  text = builtins.replaceStrings
    [ "@PWC_USER@" "@PWC_HOME_DIR@" ]
    [ "gusahlg" "/home/gusahlg" ]
    (builtins.readFile ./pwc-update.sh);
}

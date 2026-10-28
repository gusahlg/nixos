{ pkgs, ... }:

{
  fonts.fontconfig = {
    enable = true;

    defaultFonts = {
      monospace = [ "Hack Nerd Font Mono" ];
      sansSerif = [ "Hack Nerd Font" ];
      serif = [ "Hack Nerd Font" ];
    };
  };

  home.packages = with pkgs; [
    nerd-fonts.hack
  ];
}

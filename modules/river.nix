# /etc/nixos/modules/river.nix
{ pkgs, ... }:

let
  mod = "Super";

  font = "${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/Hack/HackNerdFont-Regular.ttf";

  # Use absolute Nix store paths for programs that should be guaranteed.
  dbusUpdateActivationEnvironment = "${pkgs.dbus}/bin/dbus-update-activation-environment";
  systemctl = "${pkgs.systemd}/bin/systemctl";

# gharial = "${pkgs.gharial}/bin/gharial";
# gharialctl = "${pkgs.gharial}/bin/gharialctl";
  gharial = "/home/gusahlg/.local/bin/gharial";
  gharialctl = "/home/gusahlg/.local/bin/gharialctl";

  rio = "${pkgs.rio}/bin/rio";
  qutebrowser = "${pkgs.qutebrowser}/bin/qutebrowser";
  thunar = "${pkgs.xfce.thunar}/bin/thunar";
  nvim = "${pkgs.neovim}/bin/nvim";
  tofiDrun = "${pkgs.tofi}/bin/tofi-drun";

  waybar = "${pkgs.waybar}/bin/waybar";
  wlPaste = "${pkgs.wl-clipboard}/bin/wl-paste";
  wlCopy = "${pkgs.wl-clipboard}/bin/wl-copy";
  cliphist = "${pkgs.cliphist}/bin/cliphist";
  swaybg = "${pkgs.swaybg}/bin/swaybg";

  grim = "${pkgs.grim}/bin/grim";
  slurp = "${pkgs.slurp}/bin/slurp";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  playerctl = "${pkgs.playerctl}/bin/playerctl";

in
{
  environment.systemPackages = [
    pkgs.river
    pkgs.rio
    pkgs.qutebrowser
    pkgs.xfce.thunar
    pkgs.neovim
    pkgs.tofi
    pkgs.waybar
    pkgs.wl-clipboard
    pkgs.cliphist
    pkgs.swaybg
    pkgs.grim
    pkgs.slurp
    pkgs.wireplumber
    pkgs.brightnessctl
    pkgs.playerctl
    pkgs.nerd-fonts.hack
  ];

  environment.etc."river/init" = {
    mode = "0755";

    text = ''
      #!${pkgs.runtimeShell}
      set -eu

      mod="${mod}"

      # ─── Session environment ────────────────────────────────────────────
      export XDG_CURRENT_DESKTOP=river
      export XDG_SESSION_TYPE=wayland
      export FONT="${font}"

      ${dbusUpdateActivationEnvironment} --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
      ${systemctl} --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

      # ─── Start the WM ───────────────────────────────────────────────────
      ${gharial} &
      ${gharialctl} wait

      # ─── Layout defaults ────────────────────────────────────────────────
      ${gharialctl} set gaps 0
      ${gharialctl} set outer-padding 0
      ${gharialctl} set main-ratio 0.55
      ${gharialctl} set smart-gaps on

      # ─── Application keybindings ────────────────────────────────────────
      ${gharialctl} bind "$mod+Q"      spawn ${rio}
      ${gharialctl} bind "$mod+T"      spawn ${qutebrowser}
      ${gharialctl} bind "$mod+E"      spawn ${thunar}
      ${gharialctl} bind "$mod+C"      close
      ${gharialctl} bind "$mod+R"      spawn ${tofiDrun} --drun-launch=true --font "$FONT" --height 1000 --width 500 --font-size 12
      ${gharialctl} bind "$mod+D"      spawn ${rio} -e ${nvim} "$HOME/DOCUMENTATION.txt"

      # ─── Focus and swap ─────────────────────────────────────────────────
      ${gharialctl} bind "$mod+H"        focus prev
      ${gharialctl} bind "$mod+L"        focus next
      ${gharialctl} bind "$mod+K"        focus prev
      ${gharialctl} bind "$mod+J"        focus next

      ${gharialctl} bind "$mod+Shift+H"  swap prev
      ${gharialctl} bind "$mod+Shift+L"  swap next
      ${gharialctl} bind "$mod+Shift+K"  swap prev
      ${gharialctl} bind "$mod+Shift+J"  swap next

      # ─── Tags ───────────────────────────────────────────────────────────
      for i in 1 2 3 4 5 6 7 8 9 10; do
          if [ "$i" -eq 10 ]; then
              key=0
          else
              key=$i
          fi

          ${gharialctl} bind "$mod+$key"        tag focus "$i"
          ${gharialctl} bind "$mod+Shift+$key"  tag move  "$i"
      done

      # ─── tile_ratio mode ────────────────────────────────────────────────
      ${gharialctl} bind "$mod+B"                       mode tile_ratio
      ${gharialctl} bind --mode tile_ratio "$mod+H"     main-ratio -0.05
      ${gharialctl} bind --mode tile_ratio "$mod+L"     main-ratio +0.05
      ${gharialctl} bind --mode tile_ratio "$mod+B"     mode exit
      ${gharialctl} bind --mode tile_ratio Escape       mode exit

      # ─── Utilities ──────────────────────────────────────────────────────
      ${gharialctl} bind "$mod+F1" spawn "$HOME/.local/share/night-light"

      ${gharialctl} bind "$mod+Z" spawn sh -c 'mkdir -p "$HOME/Pictures/Screenshots" && ${grim} -g "$(${slurp})" - | tee "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png" | ${wlCopy}'

      ${gharialctl} bind "$mod+X"        spawn "$HOME/.local/share/rec"
      ${gharialctl} bind "$mod+Shift+X"  spawn "$HOME/.local/share/rec-stop"

      # ─── Media keys ─────────────────────────────────────────────────────
      ${gharialctl} bind XF86AudioRaiseVolume spawn ${wpctl} set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
      ${gharialctl} bind XF86AudioLowerVolume spawn ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-
      ${gharialctl} bind XF86AudioMute        spawn ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle
      ${gharialctl} bind XF86AudioMicMute     spawn ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle

      ${gharialctl} bind XF86MonBrightnessUp   spawn ${brightnessctl} -e4 -n2 set 5%+
      ${gharialctl} bind XF86MonBrightnessDown spawn ${brightnessctl} -e4 -n2 set 5%-

      ${gharialctl} bind XF86AudioNext  spawn ${playerctl} next
      ${gharialctl} bind XF86AudioPrev  spawn ${playerctl} previous
      ${gharialctl} bind XF86AudioPlay  spawn ${playerctl} play-pause
      ${gharialctl} bind XF86AudioPause spawn ${playerctl} play-pause

      # ─── Autostart ──────────────────────────────────────────────────────
      ${gharialctl} spawn ${waybar}
      ${gharialctl} spawn ${wlPaste} --type text  --watch ${cliphist} store
      ${gharialctl} spawn ${wlPaste} --type image --watch ${cliphist} store
      ${swaybg} -i "$HOME/Pictures/doctor_nath.png" -m fill &

      wait
    '';
  };
}

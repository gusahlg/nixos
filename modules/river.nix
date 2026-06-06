# /etc/nixos/modules/river.nix
{ pkgs, lib, ... }:

let
  mod = "Super";

  font = "${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/Hack/HackNerdFont-Regular.ttf";

  # ─── Border config — single-color outlines ──────────────────────────
  # Hex values are straight RGBA (RR GG BB AA), the same form
  # riverctl's `border-color-*` commands accepted; gharial premultiplies
  # alpha internally per the wayland protocol. Full alpha gives vivid
  # colours — drop AA to soften.
  borderWidth          = 3;
  borderColorFocused   = "0xC8324BFF";
  borderColorUnfocused = "0x00C896FF";

  # ─── Absolute store-pinned binary paths ─────────────────────────────
  dbusUpdateActivationEnvironment = "${pkgs.dbus}/bin/dbus-update-activation-environment";
  systemctl = "${pkgs.systemd}/bin/systemctl";

  # gharial binaries — currently user-installed under ~/.local/bin. Swap
  # to `${pkgs.gharial}/bin/...` once a nix package exists.
  gharial = "${pkgs.gharial}/bin/gharial";
  gharialctl = "${pkgs.gharial}/bin/gharialctl";

  rio = "${pkgs.rio}/bin/rio";
  qutebrowser = "${pkgs.qutebrowser}/bin/qutebrowser";
  thunar = "${pkgs.thunar}/bin/thunar";
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

  # Personal tmux/tmuxp launchers — built from ../scripts/*.nix and
  # pinned to the nix store.
  loadProjectPkg = import ../scripts/load-project.nix { inherit pkgs lib; };
  loadSessionPkg = import ../scripts/load-session.nix { inherit pkgs lib; };
  nightLightPkg  = import ../scripts/night-light.nix  { inherit pkgs; };
  recordPkg      = import ../scripts/record.nix       { inherit pkgs; };
  recordStopPkg  = import ../scripts/record-stop.nix  { inherit pkgs; };

  loadDevSession = "${loadProjectPkg}/bin/load-project";
  loadSession    = "${loadSessionPkg}/bin/tmuxp-session";
  nightLight     = "${nightLightPkg}/bin/toggle-night-light";
  record         = "${recordPkg}/bin/toggle-recording";
  recordStop     = "${recordStopPkg}/bin/copy-latest-recording";

in
{
  environment.systemPackages = [
    pkgs.river
    pkgs.rio
    pkgs.gharial
    pkgs.qutebrowser
    pkgs.thunar
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

  # ─── Keyboard layout (replaces `riverctl keyboard-layout se`) ────────
  # wlroots reads XKB_DEFAULT_* from the environment at startup. Setting
  # via sessionVariables propagates through /etc/profile to greetd-launched
  # wayland sessions. gharial does not expose a layout command — owning
  # XKB is a compositor concern, not a WM concern.
  environment.sessionVariables = {
    XKB_DEFAULT_LAYOUT = "se";
  };

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

      # ─── Borders (single-color outlines) ───────────────────────────────
      ${gharialctl} set border-width ${toString borderWidth}
      ${gharialctl} set border-color-focused   ${borderColorFocused}
      ${gharialctl} set border-color-unfocused ${borderColorUnfocused}

      # ─── Application keybindings ────────────────────────────────────────
      ${gharialctl} bind "$mod+Q"      spawn ${rio}
      ${gharialctl} bind "$mod+T"      spawn ${qutebrowser}
      ${gharialctl} bind "$mod+E"      spawn ${thunar}
      ${gharialctl} bind "$mod+C"      close
      ${gharialctl} bind "$mod+V"      toggle-float
      ${gharialctl} bind "$mod+R"      spawn ${tofiDrun} --drun-launch=true --font "$FONT" --height 1000 --width 500 --font-size 12
      ${gharialctl} bind "$mod+D"      spawn ${rio} -e ${nvim} "$HOME/Notes"

      # ─── Focus and swap — HJKL is directional (layout-agnostic) ────────
      ${gharialctl} bind "$mod+H"        focus left
      ${gharialctl} bind "$mod+L"        focus right
      ${gharialctl} bind "$mod+K"        focus up
      ${gharialctl} bind "$mod+J"        focus down

      ${gharialctl} bind "$mod+Shift+H"  swap left
      ${gharialctl} bind "$mod+Shift+L"  swap right
      ${gharialctl} bind "$mod+Shift+K"  swap up
      ${gharialctl} bind "$mod+Shift+J"  swap down

      # ─── Tags (1-10; '0' key targets tag 10) ───────────────────────────
      for i in 1 2 3 4 5 6 7 8 9 10; do
          if [ "$i" -eq 10 ]; then
              key=0
          else
              key=$i
          fi
          ${gharialctl} bind "$mod+$key"        tag focus "$i"
          ${gharialctl} bind "$mod+Shift+$key"  tag move  "$i"
      done

      # ─── Modes ──────────────────────────────────────────────────────────
      # tile_ratio: nudge the master/stack split with H/L.
      ${gharialctl} bind "$mod+B"                       mode tile_ratio
      ${gharialctl} bind --mode tile_ratio "$mod+H"     main-ratio -0.05
      ${gharialctl} bind --mode tile_ratio "$mod+L"     main-ratio +0.05
      ${gharialctl} bind --mode tile_ratio "$mod+B"     mode exit
      ${gharialctl} bind --mode tile_ratio Escape       mode exit

      # sessions: load tmuxp-defined sessions in a fresh rio terminal.
      ${gharialctl} bind "$mod+Tab"                     mode sessions
      ${gharialctl} bind --mode sessions 1     spawn ${rio} -e ${loadDevSession} project-1
      ${gharialctl} bind --mode sessions 2     spawn ${rio} -e ${loadDevSession} project-2
      ${gharialctl} bind --mode sessions 3     spawn ${rio} -e ${loadDevSession} project-3
      ${gharialctl} bind --mode sessions 4     spawn ${rio} -e ${loadDevSession} project-4
      ${gharialctl} bind --mode sessions 5     spawn ${rio} -e ${loadDevSession} project-5
      ${gharialctl} bind --mode sessions 6     spawn ${rio} -e ${loadDevSession} project-6
      ${gharialctl} bind --mode sessions 7     spawn ${rio} -e ${loadDevSession} project-7
      ${gharialctl} bind --mode sessions 8     spawn ${rio} -e ${loadDevSession} project-8
      ${gharialctl} bind --mode sessions 9     spawn ${rio} -e ${loadDevSession} project-9
      ${gharialctl} bind --mode sessions 0     spawn ${rio} -e ${loadSession}    config
      ${gharialctl} bind --mode sessions Escape mode exit

      # ─── Utilities ──────────────────────────────────────────────────────
      ${gharialctl} bind "$mod+F1" spawn ${nightLight}

      ${gharialctl} bind "$mod+Z" spawn sh -c 'mkdir -p "$HOME/Pictures/Screenshots" && ${grim} -g "$(${slurp})" - | tee "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png" | ${wlCopy}'
      ${gharialctl} bind "$mod+Ctrl+Z" spawn sh -c 'mkdir -p "$HOME/Pictures/hall-of-fame" && ${grim} -g "$(${slurp})" - | tee "$HOME/Pictures/hall-of-fame/$(date +%Y-%m-%d_%H-%M-%S).png" | ${wlCopy}'

      ${gharialctl} bind "$mod+X"        spawn ${record}
      ${gharialctl} bind "$mod+Shift+X"  spawn ${recordStop}

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

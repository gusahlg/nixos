{
  programs.tmux = {
    enable = true;

    prefix = "C-a";
    keyMode = "vi";
    mouse = true;
    escapeTime = 0;
    historyLimit = 100000;
    baseIndex = 1;
    terminal = "tmux-256color";
    shell = "/run/current-system/sw/bin/fish";
    customPaneNavigationAndResize = true;

    extraConfig = ''
      # Unbind bindings
      unbind f

      # Window/pane numbering
      setw -g pane-base-index 1
      set -g renumber-windows on

      # Clipboard
      set -g set-clipboard on

      # Truecolor
      set -as terminal-features ",xterm-256color:RGB"

      # Splits (open in current path)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux reloaded"

      # Kill current session
      bind c tmux kill-session

      # Window navigation (Alt+N)
      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5

      # Sessions
      bind s choose-tree -sZ
      bind S command-prompt -p "new session:" "new-session -s '%%'"
      bind f display-popup -E "fish -lc /bin/load-project"

      # Copy mode (vi style)
      bind Escape copy-mode
      bind -T copy-mode-vi Escape send -X cancel
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe "wl-copy"

      # Status bar
      set -g status-interval 2
      set -g status-left  " #[bold]#S #[default]"
      set -g status-right "CODING SESSION"

      # minimal bar
      set -g window-status-format "#[fg=#666666] #I:#W "
      set -g window-status-current-format "#[fg=#ffffff,bg=#333333,bold] #W "
      set -g status-style "bg=#0f0f0f fg=#d0d0d0"

      # Pane
      set -g pane-border-style "fg=#222222"
      set -g pane-active-border-style "fg=#888888"
    '';
  };
}

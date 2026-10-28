# /etc/nixos/scripts/attach-session.nix
{ pkgs, lib }:

pkgs.writeTextFile {
  name = "attach-session";
  destination = "/bin/attach-session";
  executable = true;

  text = ''
    #!${pkgs.fish}/bin/fish

    set -gx PATH ${lib.makeBinPath [
      pkgs.tmux
      pkgs.tofi
    ]} $PATH

    # Mirror of create-session: only "project-N" sessions are development
    # sessions, so we list just those — never "config" or any other kind —
    # and let tofi fuzzy-search them. Selecting one attaches it (it already
    # exists), as opposed to create-session which always makes a fresh one.

    set -l prefix project

    set -l sessions
    for s in (tmux ls -F '#{session_name}' 2>/dev/null)
        if string match -rq '^'$prefix'-[0-9]+$' -- $s
            set -a sessions $s
        end
    end

    if test (count $sessions) -eq 0
        echo "no development sessions running — press enter to close"
        read
        exit 0
    end

    set -l choice (printf '%s\n' $sessions | tofi --prompt-text "session > ")
    test -z "$choice"; and exit 0

    exec tmux attach -t "$choice"
  '';
}

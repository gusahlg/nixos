# /etc/nixos/scripts/create-session.nix
{ pkgs, lib }:

let
  loadProject = import ./load-project.nix { inherit pkgs lib; };
in
pkgs.writeTextFile {
  name = "create-session";
  destination = "/bin/create-session";
  executable = true;

  text = ''
    #!${pkgs.fish}/bin/fish

    set -gx PATH ${lib.makeBinPath [
      pkgs.tmux
    ]} $PATH

    # Development sessions are named "project-N" and are the only sessions
    # carrying this prefix, so they can be told apart from other kinds
    # (e.g. "config"). Rather than persist a counter — which would drift
    # whenever a non-highest session is deleted — we read ground truth from
    # `tmux ls` on every run and assign the smallest free index. Because the
    # index is chosen against the set of *live* sessions, it can never
    # collide; deleting a middle session simply frees its slot for reuse.

    set -l prefix project

    set -l used
    for s in (tmux ls -F '#{session_name}' 2>/dev/null)
        set -l n (string replace -r '^'$prefix'-([0-9]+)$' '$1' -- $s)
        # `string replace` leaves the input untouched on no match, so a
        # changed value means the session matched "project-<n>".
        if test "$n" != "$s"
            set -a used $n
        end
    end

    set -l i 1
    while contains -- $i $used
        set i (math $i + 1)
    end

    exec ${loadProject}/bin/load-project "$prefix-$i"
  '';
}

# /etc/nixos/scripts/tmuxp-session.nix
{ pkgs, lib }:

pkgs.writeTextFile {
  name = "tmuxp-session";
  destination = "/bin/tmuxp-session";
  executable = true;

  text = ''
    #!${pkgs.fish}/bin/fish

    set -gx PATH ${lib.makeBinPath [
      pkgs.tmux
      pkgs.tmuxp
      pkgs.coreutils
    ]} $PATH

    set name "$argv[1]"

    if test -z "$name"
        echo "usage: tmuxp-session <session-name>"
        exit 1
    end

    # If it exists -> attach, else load
    if tmux has-session -t "$name" 2>/dev/null
        exec tmux attach -t "$name"
    end

    tmuxp load -y "$HOME/.config/tmuxp/$name.yaml"
    or begin
        set -l ec $status
        echo
        echo "tmuxp exited with status $ec — press enter to close"
        read
    end
  '';
}

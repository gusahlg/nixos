# /etc/nixos/scripts/load-project.nix
{ pkgs, lib }:

pkgs.writeTextFile {
  name = "load-project";
  destination = "/bin/load-project";
  executable = true;

  text = ''
    #!${pkgs.fish}/bin/fish

    set -gx PATH ${lib.makeBinPath [
      pkgs.tmux
      pkgs.tmuxp
      pkgs.fzf
      pkgs.findutils
      pkgs.coreutils
    ]} $PATH

    # Usage check
    if test -z "$argv[1]"
        echo "usage: load-project <session-name>"
        exit 1
    end

    # If session already exists, just attach it
    if tmux has-session -t "$argv[1]" 2>/dev/null
        exec tmux attach -t "$argv[1]"
    end

    set target (find ~ -type d 2>/dev/null | sort | fzf --prompt="project dir > ")

    # Should not attach if entered blank
    if test -z "$target"
        exit 0
    end

    set -gx SESSION_NAME "$argv[1]"
    set -gx PROJECT_DIR "$target"

    exec tmuxp load -y "$HOME/.config/tmuxp/dev_env.yaml"
  '';
}

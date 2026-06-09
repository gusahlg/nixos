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
      pkgs.fd
      pkgs.zoxide
      pkgs.gawk
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

    set -l cache_dir $XDG_CACHE_HOME
    test -z "$cache_dir"; and set cache_dir "$HOME/.cache"
    set -l cache "$cache_dir/load-project/dirs.list"
    mkdir -p (dirname $cache)

    function __lp_refresh_dirs --argument-names cache
        set -l tmp (mktemp "$cache.XXXXXX")
        fd --type d --hidden --max-depth 6 . "$HOME" /etc/nixos > $tmp 2>/dev/null
        mv $tmp $cache
    end

    # Cold start: build synchronously so we have something to show fzf.
    test -s $cache; or __lp_refresh_dirs $cache

    # Refresh in the background so the next invocation is up to date.
    __lp_refresh_dirs $cache &
    disown 2>/dev/null

    set target (begin
        zoxide query -l 2>/dev/null
        cat $cache
    end | awk '!seen[$0]++' | fzf \
        --prompt="project dir > " \
        --tiebreak=index \
        --scheme=path \
        --height=80% --reverse)

    # Should not attach if entered blank
    if test -z "$target"
        exit 0
    end

    set -gx SESSION_NAME "$argv[1]"
    set -gx PROJECT_DIR "$target"

    tmuxp load -y "$HOME/.config/tmuxp/dev_env.yaml"
    or begin
        set -l ec $status
        echo
        echo "tmuxp exited with status $ec — press enter to close"
        read
    end
  '';
}

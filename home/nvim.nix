{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
  };

  # Link the configuration tree recursively so new Lua modules do not need a
  # second declaration here. Unmanaged files such as lazy-lock.json can still
  # live alongside these Home Manager links.
  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };
}

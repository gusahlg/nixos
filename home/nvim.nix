{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
  };

  xdg.configFile = {
    "nvim/init.lua".source = ./nvim/init.lua;
    "nvim/flake.nix".source = ./nvim/flake.nix;

    "nvim/lua/community.lua".source = ./nvim/lua/community.lua;
    "nvim/lua/lazy_setup.lua".source = ./nvim/lua/lazy_setup.lua;
    "nvim/lua/polish.lua".source = ./nvim/lua/polish.lua;

    "nvim/lua/plugins/astrocore.lua".source = ./nvim/lua/plugins/astrocore.lua;
    "nvim/lua/plugins/astrolsp.lua".source = ./nvim/lua/plugins/astrolsp.lua;
    "nvim/lua/plugins/blink.lua".source = ./nvim/lua/plugins/blink.lua;
    "nvim/lua/plugins/harpoon.lua".source = ./nvim/lua/plugins/harpoon.lua;
    "nvim/lua/plugins/mason.lua".source = ./nvim/lua/plugins/mason.lua;
    "nvim/lua/plugins/theme.lua".source = ./nvim/lua/plugins/theme.lua;
    "nvim/lua/plugins/treesitter.lua".source = ./nvim/lua/plugins/treesitter.lua;
    "nvim/lua/plugins/ts-autotag.lua".source = ./nvim/lua/plugins/ts-autotag.lua;
    "nvim/lua/plugins/wakatime.lua".source = ./nvim/lua/plugins/wakatime.lua;

    "nvim/lua/user/toggles.lua".source = ./nvim/lua/user/toggles.lua;
  };
}

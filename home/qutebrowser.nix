{
  programs.qutebrowser = {
    enable = true;
    loadAutoconfig = true;

    settings = {
      tabs = {
        position = "left";
        width = "14%";
        show = "switching";
        title = {
          format = "{index}: {current_title}";
          format_pinned = "[{index}] {host}";
        };
      };

      editor.command = [ "rio" "-e" "nvim" "{file}" ];

      url = {
        searchengines = {
          DEFAULT = "https://search.brave.com/search?q={}";
        };
        start_pages = [ "https://search.brave.com" ];
        default_page = "https://search.brave.com";
      };

      statusbar = {
        position = "top";
        show = "always";
        widgets = [ "keypress" "search_match" "url" "scroll" "tabs" ];
      };

      colors = {
        webpage = {
          preferred_color_scheme = "dark";
          darkmode.enabled = true;
        };
        statusbar = {
          normal = {
            bg = "#111111";
            fg = "#e5e5e5";
          };
          insert.bg = "#1f4d2e";
          command.bg = "#1a1a1a";
        };
        tabs = {
          bar.bg = "#0f0f0f";
          selected = {
            even.bg = "#1d1d1d";
            odd.bg = "#1d1d1d";
          };
          even.bg = "#141414";
          odd.bg = "#141414";
        };
      };

      hints = {
        chars = "arstgmneio";
        auto_follow = "full-match";
      };

      keyhint.delay = 0;

      window.hide_decoration = true;
    };

    extraConfig = ''
      c.url.yank_ignored_parameters += ["fbclid", "si"]
    '';

    keyBindings = {
      normal = {
        "go" = "cmd-set-text -s :quickmark-load";
        "gn" = "cmd-set-text -s :quickmark-load --tab";
        "gO" = "cmd-set-text :open {url:pretty}";
        "gN" = "cmd-set-text :open -t {url:pretty}";
      };
    };

    quickmarks = {
      chatgpt = "https://chatgpt.com/";
      ch = "https://chatgpt.com";
      gh = "https://github.com";
      st = "https://stoat.chat/app";
    };
  };
}

{
  programs.rio = {
    enable = true;

    settings = {
      confirm-before-quit = false;

      editor = {
        program = "nvim";
        args = [ "~" ];
      };

      fonts = {
        family = "Hack Nerd Font";
        size = 12;
      };

      shell = {
        program = "/run/current-system/sw/bin/fish";
        args = [ "--login" ];
      };

      colors = {
        cursor = "#11591f";
      };
    };
  };
}

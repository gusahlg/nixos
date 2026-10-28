{
  services.xserver.xkb.layout = "se";

  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];

      settings = {
        main = {
          capslock = "esc";
          esc = "capslock";
        };
      };
    };
  };
}

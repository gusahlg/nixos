{
  programs.git = {
    enable = true;

    lfs.enable = true;

    ignores = [
      "**/.claude/settings.local.json"
    ];

    settings = {
      user = {
        name = "gusahlg";
        email = "gusahlg@gmail.com";
      };
      safe.directory = "/etc/nixos";
    };
  };
}

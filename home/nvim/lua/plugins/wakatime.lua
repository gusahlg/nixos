-- Hackatime editor tracking (shares ~/.wakatime.cfg with terminal-wakatime).
-- lazy = false so heartbeats start with the editor, not on first keypress of
-- some unrelated event.
return {
  "wakatime/vim-wakatime",
  lazy = false,
  init = function()
    -- Use the Nix-provided wakatime-cli instead of letting the plugin
    -- download a binary into ~/.wakatime/ (auto-downloaded binaries are
    -- unreliable on NixOS).
    local cli = vim.fn.exepath "wakatime-cli"
    if cli ~= "" then vim.g.wakatime_CLIPath = cli end
  end,
}

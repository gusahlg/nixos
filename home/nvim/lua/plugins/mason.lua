local lsp = require "user.lsp"

return {
  {
    "mason-org/mason.nvim",
    opts = {
      PATH = lsp.is_nixos and "skip" or "prepend",
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.automatic_enable = not lsp.is_nixos
      opts.ensure_installed = lsp.is_nixos and {} or vim.deepcopy(lsp.preferred_servers)
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      opts.ensure_installed = lsp.is_nixos and {} or vim.deepcopy(lsp.mason_tools)
    end,
  },
}

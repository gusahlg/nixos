local lsp = require("user.lsp")

return {
	"AstroNvim/astrolsp",
	opts = {
		features = {
			-- CodeLens resolving caused a redraw/request feedback loop in Nvim
			-- 0.12. Keep the useful LSP features without the idle CPU cost.
			codelens = false,
			inlay_hints = true,
			semantic_tokens = true,
		},
		formatting = {
			format_on_save = false,
			timeout_ms = 2000,
		},
		servers = lsp.enabled_servers(),
		config = {
			lua_ls = {
				settings = {
					Lua = {
						runtime = { version = "LuaJIT" },
						diagnostics = { globals = { "vim" } },
						telemetry = { enable = false },
						workspace = {
							checkThirdParty = false,
							library = vim.api.nvim_get_runtime_file("", true),
						},
					},
				},
			},
			nil_ls = {
				settings = {
					["nil"] = {
						formatting = { command = { "nixfmt" } },
					},
				},
			},
			nixd = {
				settings = {
					nixd = {
						formatting = { command = { "nixfmt" } },
						nixpkgs = {
							expr = "import <nixpkgs> { }",
						},
					},
				},
			},
			rust_analyzer = {
				cmd = lsp.command("rust_analyzer"),
				settings = {
					["rust-analyzer"] = {
						cachePriming = { enable = false },
						cargo = { allTargets = false },
						completion = {
							autoimport = { enable = true },
							autoself = { enable = true },
							postfix = { enable = true },
						},
						check = {
							allTargets = false,
							command = "check",
						},
						diagnostics = { enable = true },
						imports = {
							granularity = { group = "module" },
							prefix = "self",
						},
						lens = { enable = false },
						procMacro = { enable = true },
					},
				},
			},
			yamlls = {
				settings = {
					yaml = {
						keyOrdering = false,
					},
				},
			},
		},
		mappings = {
			n = {
				gd = {
					function()
						vim.lsp.buf.definition()
					end,
					desc = "Definition",
					cond = "textDocument/definition",
				},
				gD = {
					function()
						vim.lsp.buf.declaration()
					end,
					desc = "Declaration",
					cond = "textDocument/declaration",
				},
				gi = {
					function()
						vim.lsp.buf.implementation()
					end,
					desc = "Implementation",
					cond = "textDocument/implementation",
				},
				gr = {
					function()
						vim.lsp.buf.references()
					end,
					desc = "References",
					cond = "textDocument/references",
				},
				K = {
					function()
						vim.lsp.buf.hover()
					end,
					desc = "Hover documentation",
					cond = "textDocument/hover",
				},
				["<C-h>"] = {
					function()
						vim.lsp.buf.signature_help()
					end,
					desc = "Signature help",
					cond = "textDocument/signatureHelp",
				},
				["<leader>rn"] = {
					function()
						vim.lsp.buf.rename()
					end,
					desc = "Rename symbol",
				},
				["<leader>ca"] = {
					function()
						vim.lsp.buf.code_action()
					end,
					desc = "Code action",
				},
				["[d"] = {
					function()
						vim.diagnostic.jump({ count = -1, float = true })
					end,
					desc = "Previous diagnostic",
				},
				["]d"] = {
					function()
						vim.diagnostic.jump({ count = 1, float = true })
					end,
					desc = "Next diagnostic",
				},
				["[e"] = {
					function()
						vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR, float = true })
					end,
					desc = "Previous error",
				},
				["]e"] = {
					function()
						vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR, float = true })
					end,
					desc = "Next error",
				},
				["<leader>e"] = {
					function()
						vim.diagnostic.open_float()
					end,
					desc = "Line diagnostics",
				},
				["<leader>q"] = {
					function()
						vim.diagnostic.setloclist()
					end,
					desc = "Diagnostics loclist",
				},
			},
			i = {
				["<C-h>"] = {
					function()
						vim.lsp.buf.signature_help()
					end,
					desc = "Signature help",
					cond = "textDocument/signatureHelp",
				},
			},
		},
	},
}

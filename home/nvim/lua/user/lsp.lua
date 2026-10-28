local M = {}

M.is_nixos = vim.fn.filereadable("/etc/NIXOS") == 1

M.server_commands = {
	bashls = "bash-language-server",
	clangd = "clangd",
	cssls = "vscode-css-language-server",
	docker_compose_language_service = "docker-compose-langserver",
	dockerls = "docker-langserver",
	eslint = "vscode-eslint-language-server",
	gopls = "gopls",
	html = "vscode-html-language-server",
	jsonls = "vscode-json-language-server",
	lua_ls = "lua-language-server",
	marksman = "marksman",
	nil_ls = "nil",
	nixd = "nixd",
	pyright = "pyright-langserver",
	rust_analyzer = "rust-analyzer",
	taplo = "taplo",
	terraformls = "terraform-ls",
	ts_ls = "typescript-language-server",
	yamlls = "yaml-language-server",
	zls = "zls",
}

M.preferred_servers = {
	"lua_ls",
	"nixd",
	"rust_analyzer",
	"clangd",
	"pyright",
	"ts_ls",
	"eslint",
	"bashls",
	"jsonls",
	"yamlls",
	"taplo",
	"marksman",
	"dockerls",
	"docker_compose_language_service",
	"html",
	"cssls",
	"gopls",
	"terraformls",
	"zls",
}

M.mason_tools = {
	"lua-language-server",
	"nixd",
	"rust-analyzer",
	"clangd",
	"pyright",
	"typescript-language-server",
	"eslint-lsp",
	"bash-language-server",
	"json-lsp",
	"yaml-language-server",
	"taplo",
	"marksman",
	"dockerfile-language-server",
	"docker-compose-language-service",
	"html-lsp",
	"css-lsp",
	"gopls",
	"terraform-ls",
	"zls",
	"tree-sitter-cli",
}

local function executable(command)
	return vim.fn.executable(command) == 1
end

local function can_use_nix_develop(server)
	return M.is_nixos
		and server == "rust_analyzer"
		and executable("nix")
		and vim.fn.filereadable(vim.fn.stdpath("config") .. "/flake.nix") == 1
end

function M.server_command(server)
	return M.server_commands[server] or server
end

function M.command(server)
	local command = M.server_command(server)
	if executable(command) then return nil end
	if can_use_nix_develop(server) then
		return { "nix", "develop", "path:" .. vim.fn.stdpath("config"), "--command", command }
	end
end

local function available(server)
	return executable(M.server_command(server)) or can_use_nix_develop(server)
end

function M.enabled_servers()
	if not M.is_nixos then return vim.deepcopy(M.preferred_servers) end

	local servers = {}
	for _, server in ipairs(M.preferred_servers) do
		if server == "nixd" then
			if available("nixd") then
				table.insert(servers, "nixd")
			elseif available("nil_ls") then
				table.insert(servers, "nil_ls")
			end
		elseif available(server) then
			table.insert(servers, server)
		end
	end

	return servers
end

return M

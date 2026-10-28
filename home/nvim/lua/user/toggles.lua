local M = {}
local paused_analyzers

local function bool_text(value)
	return value and "on" or "off"
end

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Editor toggles" })
end

local function hide_completion_menu()
	local ok, blink = pcall(require, "blink.cmp")
	if ok and blink and blink.hide then
		local hidden, err = pcall(blink.hide)
		if not hidden then
			notify(("Could not hide completion menu: %s"):format(err), vim.log.levels.WARN)
		end
	end
end

function M.toggle_buffer_completion()
	local ok, astrocore = pcall(require, "astrocore")
	if not ok then
		notify("Could not toggle code suggestions: astrocore is unavailable", vim.log.levels.ERROR)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	if vim.b[bufnr].completion == nil then
		vim.b[bufnr].completion = vim.tbl_get(astrocore.config, "features", "cmp") ~= false
	end

	vim.b[bufnr].completion = not vim.b[bufnr].completion
	if not vim.b[bufnr].completion then
		hide_completion_menu()
	end

	notify(("Code suggestions %s for this buffer"):format(bool_text(vim.b[bufnr].completion)))
end

function M.toggle_global_completion()
	local ok, astrocore = pcall(require, "astrocore")
	if not ok then
		notify("Could not toggle code suggestions: astrocore is unavailable", vim.log.levels.ERROR)
		return
	end

	astrocore.config.features.cmp = not astrocore.config.features.cmp
	if not astrocore.config.features.cmp then
		hide_completion_menu()
	end

	notify(("Code suggestions %s globally"):format(bool_text(astrocore.config.features.cmp)))
end

function M.toggle_diagnostics()
	local enabled = not vim.diagnostic.is_enabled()
	local ok, err = pcall(vim.diagnostic.enable, enabled)
	if not ok then
		notify(("Could not toggle diagnostics: %s"):format(err), vim.log.levels.ERROR)
		return
	end

	notify(("Error detection %s"):format(bool_text(vim.diagnostic.is_enabled())))
end

local function enabled_analyzers()
	local names = {}
	local seen = {}
	local ok, astrolsp = pcall(require, "astrolsp")
	local configured = ok and astrolsp.config and astrolsp.config.servers or {}

	for _, name in ipairs(configured) do
		if vim.lsp.is_enabled(name) and not seen[name] then
			seen[name] = true
			table.insert(names, name)
		end
	end

	-- Include clients started outside AstroLSP as long as they use Nvim's
	-- managed LSP configuration.
	for _, client in ipairs(vim.lsp.get_clients()) do
		if vim.lsp.is_enabled(client.name) and not seen[client.name] then
			seen[client.name] = true
			table.insert(names, client.name)
		end
	end

	table.sort(names)
	return names
end

function M.toggle_language_analyzers()
	if paused_analyzers then
		local ok, err = pcall(vim.lsp.enable, paused_analyzers.names, true)
		if not ok then
			notify(("Could not start language analyzers: %s"):format(err), vim.log.levels.ERROR)
			return
		end

		vim.diagnostic.enable(paused_analyzers.diagnostics_enabled)
		paused_analyzers = nil
		notify("Language analyzers on")
		return
	end

	local names = enabled_analyzers()
	if vim.tbl_isempty(names) then
		notify("No managed language analyzers are enabled", vim.log.levels.WARN)
		return
	end

	local state = {
		names = names,
		diagnostics_enabled = vim.diagnostic.is_enabled(),
	}
	local ok, err = pcall(vim.lsp.enable, names, false)
	if not ok then
		notify(("Could not stop language analyzers: %s"):format(err), vim.log.levels.ERROR)
		return
	end

	paused_analyzers = state
	vim.diagnostic.enable(false)
	notify("Language analyzers off")
end

return M

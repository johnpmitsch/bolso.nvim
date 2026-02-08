local M = {}

--- Set up bolso.nvim with optional user configuration.
---@param opts? table  User config overrides (see config.lua for defaults)
function M.setup(opts)
	local config = require("bolso.config")
	config.setup(opts)

	-- Install the yank capture autocmd
	local stack = require("bolso.stack")
	stack.install_autocmd()

	-- Create user command
	vim.api.nvim_create_user_command("Bolso", function()
		M.open()
	end, { desc = "Open bolso yank/delete history" })

	vim.api.nvim_create_user_command("BolsoClear", function()
		stack.clear()
		vim.notify("bolso: stack cleared", vim.log.levels.INFO)
	end, { desc = "Clear bolso stack" })

	-- Set default keymap if not already mapped
	local trigger = (opts and opts.keymap) or "<leader>b"
	if trigger ~= false then
		vim.keymap.set("n", trigger, function()
			M.open()
		end, { desc = "Open bolso yank/delete history", silent = true })
	end
end

--- Open the bolso picker window.
function M.open()
	local ui = require("bolso.ui")
	ui.open()
end

--- Programmatic access to the stack.
---@return BolsoEntry[]
function M.entries()
	return require("bolso.stack").entries
end

return M

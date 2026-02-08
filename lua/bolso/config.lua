local M = {}

---@class BolsoWindowConfig
---@field width number
---@field border string

---@class BolsoConfig
---@field labels string
---@field max_items number
---@field window BolsoWindowConfig
---@field actions table<string, string>

---@type BolsoConfig
M.defaults = {
	labels = "asdfghjkl",
	max_items = 9,
	window = {
		width = 60,
		border = "rounded",
	},
	actions = {
		p = "paste_after",
		P = "paste_before",
		y = "yank_to_clipboard",
	},
}

---@type BolsoConfig
M.options = {}

---@param opts? table
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

	-- Clamp max_items to number of labels
	local label_count = #M.options.labels
	if M.options.max_items > label_count then
		M.options.max_items = label_count
	end
end

return M

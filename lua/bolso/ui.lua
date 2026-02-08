local config = require("bolso.config")
local stack = require("bolso.stack")
local actions = require("bolso.actions")

local M = {}

---@type number|nil  Buffer handle for the floating window
M.buf = nil
---@type number|nil  Window handle for the floating window
M.win = nil
---@type number|nil  1-based index of the selected entry
M.selected = nil

-- State: 'closed' | 'selecting' | 'acting'
---@type string
M.state = "closed"

-- Highlight groups
local ns = vim.api.nvim_create_namespace("bolso")

local function define_highlights()
	-- Label highlight (the [a], [s], etc.)
	vim.api.nvim_set_hl(0, "BolsoLabel", { link = "Identifier", default = true })
	-- Content text
	vim.api.nvim_set_hl(0, "BolsoContent", { link = "Normal", default = true })
	-- Selected line
	vim.api.nvim_set_hl(0, "BolsoSelected", { link = "Visual", default = true })
	-- Title
	vim.api.nvim_set_hl(0, "BolsoTitle", { link = "Title", default = true })
	-- Hint line
	vim.api.nvim_set_hl(0, "BolsoHint", { link = "Comment", default = true })
end

--- Build the display lines and highlight data for the floating window.
---@return string[] lines
---@return table[] highlights  -- { line, col_start, col_end, hl_group }
local function build_lines()
	local labels = config.options.labels
	local count = math.min(stack.count(), #labels)
	local lines = {}
	local highlights = {}
	local win_width = config.options.window.width

	if count == 0 then
		table.insert(lines, "  (empty)")
		return lines, highlights
	end

	for i = 1, count do
		local entry = stack.get(i)
		if not entry then
			break
		end

		local label = labels:sub(i, i)

		-- Take first line of content, truncate if needed
		local first_line = entry.content:match("^([^\n]*)") or ""
		local type_indicator = ({ l = "¶", b = "█", c = "" })[entry.regtype] or ""

		-- Build the display line
		local prefix = string.format(" [%s] ", label)
		local max_content = win_width - #prefix - #type_indicator - 3
		if #first_line > max_content then
			first_line = first_line:sub(1, max_content - 1) .. "…"
		end

		local line = prefix .. first_line
		if type_indicator ~= "" then
			line = line .. " " .. type_indicator
		end

		table.insert(lines, line)

		-- Highlights for label bracket
		local lnum = #lines - 1 -- 0-indexed
		table.insert(highlights, { lnum, 1, 4, "BolsoLabel" })
		table.insert(highlights, { lnum, 5, #line, "BolsoContent" })
	end

	return lines, highlights
end

--- Render content into the buffer.
local function render()
	if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
		return
	end

	vim.bo[M.buf].modifiable = true

	local lines, highlights = build_lines()

	-- Add hint line
	local hint
	if M.state == "selecting" then
		hint = " Press label to select, <Esc> to cancel"
	elseif M.state == "acting" then
		local labels = config.options.labels
		local label = labels:sub(M.selected, M.selected)
		hint = string.format(" [%s] selected → p paste after · P paste before · y yank · <Esc> cancel", label)
	end

	if hint then
		table.insert(lines, "")
		table.insert(lines, hint)
		table.insert(highlights, { #lines - 1, 0, #hint, "BolsoHint" })
	end

	vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)

	-- Apply highlights
	vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)
	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(M.buf, ns, hl[4], hl[1], hl[2], hl[3])
	end

	-- Highlight selected line
	if M.selected and M.state == "acting" then
		local sel_line = M.selected - 1 -- 0-indexed
		if sel_line >= 0 and sel_line < stack.count() then
			vim.api.nvim_buf_add_highlight(M.buf, ns, "BolsoSelected", sel_line, 0, -1)
		end
	end

	vim.bo[M.buf].modifiable = false
end

--- Close the floating window and reset state.
function M.close()
	if M.win and vim.api.nvim_win_is_valid(M.win) then
		vim.api.nvim_win_close(M.win, true)
	end
	if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
		vim.api.nvim_buf_delete(M.buf, { force = true })
	end
	M.win = nil
	M.buf = nil
	M.selected = nil
	M.state = "closed"
end

--- Set up keymaps for the floating window buffer.
local function setup_keymaps()
	local buf = M.buf
	local opts = { buffer = buf, noremap = true, nowait = true, silent = true }

	-- Escape always closes
	vim.keymap.set("n", "<Esc>", function()
		M.close()
	end, opts)

	vim.keymap.set("n", "q", function()
		M.close()
	end, opts)

	-- Label keys for selection
	local labels = config.options.labels
	for i = 1, #labels do
		local label = labels:sub(i, i)
		vim.keymap.set("n", label, function()
			if M.state ~= "selecting" then
				return
			end
			if i > stack.count() then
				return
			end -- no entry for this label

			M.selected = i
			M.state = "acting"
			render()
		end, opts)
	end

	-- Action keys
	for key, action_name in pairs(config.options.actions) do
		vim.keymap.set("n", key, function()
			if M.state ~= "acting" or not M.selected then
				return
			end

			local entry = stack.get(M.selected)
			if not entry then
				return
			end

			-- Close window before executing action so paste goes to the right buffer
			M.close()

			-- Execute the action
			local action_fn = actions[action_name]
			if action_fn then
				action_fn(entry)
			else
				vim.notify('bolso.nvim: unknown action "' .. action_name .. '"', vim.log.levels.WARN)
			end
		end, opts)
	end
end

--- Open the bolso floating window.
function M.open()
	if M.state ~= "closed" then
		M.close()
	end

	define_highlights()

	-- Create buffer
	M.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[M.buf].bufhidden = "wipe"
	vim.bo[M.buf].filetype = "bolso"

	-- Calculate window dimensions
	local win_width = config.options.window.width
	local item_count = math.min(stack.count(), #config.options.labels)
	local content_lines = math.max(item_count, 1) -- at least 1 for "(empty)"
	local win_height = content_lines + 2 -- +2 for blank line + hint

	-- Center the window
	local editor_width = vim.o.columns
	local editor_height = vim.o.lines
	local row = math.floor((editor_height - win_height) / 2)
	local col = math.floor((editor_width - win_width) / 2)

	-- Open floating window
	M.win = vim.api.nvim_open_win(M.buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		style = "minimal",
		border = config.options.window.border,
		title = " bolso ",
		title_pos = "center",
	})

	-- Window options
	vim.wo[M.win].cursorline = false
	vim.wo[M.win].number = false
	vim.wo[M.win].relativenumber = false
	vim.wo[M.win].signcolumn = "no"
	vim.wo[M.win].wrap = false

	M.state = "selecting"

	-- Render content and set keymaps
	render()
	setup_keymaps()

	-- Close on BufLeave as safety net
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = M.buf,
		once = true,
		callback = function()
			-- Defer so any pending action completes first
			vim.schedule(function()
				if M.state ~= "closed" then
					M.close()
				end
			end)
		end,
	})
end

return M

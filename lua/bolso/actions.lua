local M = {}

--- Split content back into lines for nvim_put.
---@param content string
---@return string[]
local function content_to_lines(content)
	return vim.split(content, "\n", { plain = true })
end

--- Paste entry after the cursor (like `p`).
---@param entry BolsoEntry
function M.paste_after(entry)
	local lines = content_to_lines(entry.content)
	-- nvim_put: {lines}, {type}, {after}, {follow}
	-- type: "c" charwise, "l" linewise, "b" blockwise
	vim.api.nvim_put(lines, entry.regtype, true, true)
end

--- Paste entry before the cursor (like `P`).
---@param entry BolsoEntry
function M.paste_before(entry)
	local lines = content_to_lines(entry.content)
	vim.api.nvim_put(lines, entry.regtype, false, true)
end

--- Yank entry content to the system clipboard (register "+).
---@param entry BolsoEntry
function M.yank_to_clipboard(entry)
	vim.fn.setreg("+", entry.content, entry.regtype)
	-- Also set the unnamed register so `p` works immediately
	vim.fn.setreg('"', entry.content, entry.regtype)

	local preview = entry.content:sub(1, 40)
	if #entry.content > 40 then
		preview = preview .. "…"
	end
	vim.notify("bolso: yanked to clipboard", vim.log.levels.INFO)
end

return M

local config = require("bolso.config")

local M = {}

---@class BolsoEntry
---@field content string
---@field regtype string  -- "v" | "V" | "\22" (charwise / linewise / blockwise)
---@field event string    -- "y" | "d" | "c"

---@type BolsoEntry[]
M.entries = {}

--- Normalize regtype from vim.v.event into the format nvim_put expects.
---@param regtype string
---@return string
local function normalize_regtype(regtype)
	-- vim.v.event.regtype uses: "v" (charwise), "V" (linewise), "<C-V>width" (blockwise)
	if regtype:sub(1, 1) == "\22" or regtype:sub(1, 1) == "" then
		return "b" -- blockwise for nvim_put
	elseif regtype == "V" then
		return "l" -- linewise
	else
		return "c" -- charwise
	end
end

--- Push a new entry onto the stack (LIFO). Deduplicates consecutive identical content.
---@param content string
---@param regtype string
---@param event string
function M.push(content, regtype, event)
	-- Skip empty content
	if content == "" then
		return
	end

	-- Dedupe: skip if identical to the top of the stack
	if #M.entries > 0 and M.entries[1].content == content then
		return
	end

	---@type BolsoEntry
	local entry = {
		content = content,
		regtype = normalize_regtype(regtype),
		event = event,
	}

	-- Prepend (LIFO)
	table.insert(M.entries, 1, entry)

	-- Trim to max size
	local max = config.options.max_items or 9
	while #M.entries > max do
		table.remove(M.entries)
	end
end

--- Get entry by 1-based index.
---@param idx number
---@return BolsoEntry|nil
function M.get(idx)
	return M.entries[idx]
end

--- Get the number of entries in the stack.
---@return number
function M.count()
	return #M.entries
end

--- Clear the entire stack.
function M.clear()
	M.entries = {}
end

--- Install the TextYankPost autocmd that feeds the stack.
function M.install_autocmd()
	local group = vim.api.nvim_create_augroup("BolsoYankCapture", { clear = true })

	vim.api.nvim_create_autocmd("TextYankPost", {
		group = group,
		desc = "bolso.nvim: capture yanks and deletes into unified stack",
		callback = function()
			local event = vim.v.event
			if not event then
				return
			end

			local operator = event.operator -- "y", "d", "c"
			local regname = event.regname -- "" for unnamed, or a named register

			-- Only capture operations that go to the unnamed register.
			-- If the user explicitly yanked to a named register ("ayy), skip it.
			if regname ~= "" then
				return
			end

			local content = table.concat(event.regcontents, "\n")
			local regtype = event.regtype or "v"

			M.push(content, regtype, operator)
		end,
	})
end

return M

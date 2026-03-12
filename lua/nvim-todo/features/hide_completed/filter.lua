-- Core filtering logic and state for hiding completed tasks.
local M = {}

---@class HideCompletedState
---@field active boolean Whether completed tasks are currently hidden
---@field hidden_ranges { start: number, lines: string[] }[] Ranges of hidden lines
---@field original_lines string[]? Full buffer snapshot before hiding
---@field line_map number[]? Mapping of visible line index -> original line index
local state = {
  active = false,
  hidden_ranges = {},
  original_lines = nil,
  line_map = nil,
}

---Get direct access to state (for toggle.lua).
---@return HideCompletedState
function M.get_state()
  return state
end

---Check if a line is a checked (completed) todo.
---@param line string
---@return boolean
local function is_checked(line)
  return line:match('^%s*%- %[x%]') ~= nil or line:match('^%s*%- %[X%]') ~= nil
end

---Check if a line is an unchecked (pending) todo.
---@param line string
---@return boolean
local function is_unchecked(line)
  return line:match('^%s*%- %[ %]') ~= nil
end

---Compute visible lines, hidden ranges, and a line_map from a set of lines.
---@param lines string[]
---@return string[] visible_lines, { start: number, lines: string[] }[] hidden_ranges, number[] line_map
function M.compute_ranges(lines)
  local visible = {}
  local ranges = {}
  local line_map = {}
  local hiding = false
  local current_hidden = {}
  local current_start = nil

  for orig_idx, line in ipairs(lines) do
    if hiding then
      if is_unchecked(line) then
        table.insert(ranges, { start = current_start, lines = current_hidden })
        current_hidden = {}
        hiding = false
        table.insert(visible, line)
        table.insert(line_map, orig_idx)
      else
        table.insert(current_hidden, line)
      end
    else
      if is_checked(line) then
        hiding = true
        current_start = #visible + 1
        current_hidden = { line }
      else
        table.insert(visible, line)
        table.insert(line_map, orig_idx)
      end
    end
  end

  if hiding and #current_hidden > 0 then
    table.insert(ranges, { start = #visible + 1, lines = current_hidden })
  end

  return visible, ranges, line_map
end

---Check if hide mode is active.
---@return boolean
function M.is_active()
  return state.active
end

---Get full lines including hidden ranges, merging any edits made while hidden.
---@param bufnr number
---@return string[]
function M.get_full_lines(bufnr)
  if not state.active or not state.original_lines then
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    end
    return {}
  end

  local visible = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local result = {}
  for _, line in ipairs(visible) do
    table.insert(result, line)
  end

  local sorted = {}
  for _, range in ipairs(state.hidden_ranges) do
    table.insert(sorted, range)
  end
  table.sort(sorted, function(a, b) return a.start > b.start end)

  for _, range in ipairs(sorted) do
    local pos = math.min(range.start, #result + 1)
    for i = #range.lines, 1, -1 do
      table.insert(result, pos, range.lines[i])
    end
  end

  return result
end

---Get full content as a string including hidden lines (for saving).
---@param bufnr number
---@return string
function M.get_full_content(bufnr)
  local lines = M.get_full_lines(bufnr)
  return table.concat(lines, "\n")
end

---Get the original line number for a visible line number.
---@param visible_lnum number 1-based visible line number
---@return number original 1-based original line number
function M.get_original_lnum(visible_lnum)
  if state.active and state.line_map and state.line_map[visible_lnum] then
    return state.line_map[visible_lnum]
  end
  return visible_lnum
end

---Reset state (called on window close).
function M.reset()
  state.active = false
  state.hidden_ranges = {}
  state.original_lines = nil
  state.line_map = nil
end

return M

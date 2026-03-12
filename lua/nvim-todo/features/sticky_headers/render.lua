-- Overlay rendering and update logic for sticky markdown headers.
local M = {}

---@class StickyHeaderState
---@field overlay_win number?
---@field overlay_buf number?
---@field notepad_win number?
---@field notepad_buf number?
---@field _adjusting boolean Guard against recursive CursorMoved triggers
---@field _overlay_height number Current overlay height (0 when hidden)
local state = {
  overlay_win = nil,
  overlay_buf = nil,
  notepad_win = nil,
  notepad_buf = nil,
  _adjusting = false,
  _overlay_height = 0,
}

---Set the window/buffer state (called by setup).
---@param winid number
---@param bufnr number
function M.set_state(winid, bufnr)
  state.notepad_win = winid
  state.notepad_buf = bufnr
end

---Get direct access to state (for setup cleanup).
---@return StickyHeaderState
function M.get_state()
  return state
end

---Check if a line is a separator (3+ dashes).
---@param line string
---@return boolean
local function is_separator(line)
  return line:match('^%-%-%-+%s*$') ~= nil
end

---Get header level from a line, or nil if not a header.
---@param line string
---@return number?
local function get_header_level(line)
  local hashes = line:match('^(#+)')
  if hashes then
    return #hashes
  end
  return nil
end

---Build the header stack by scanning upward from the first truly visible line.
---@param bufnr number
---@param first_visible number 1-indexed first visible line
---@param overlay_height number Current overlay height (lines covered by overlay)
---@return {level: number, text: string}[]
local function build_header_stack(bufnr, first_visible, overlay_height)
  local stack = {}
  local min_level = math.huge

  local first_uncovered = first_visible + overlay_height

  local lines = vim.api.nvim_buf_get_lines(bufnr, first_uncovered - 1, first_uncovered, false)
  if lines[1] then
    local level = get_header_level(lines[1])
    if level then
      min_level = level
    end
  end

  for lnum = first_uncovered - 1, 1, -1 do
    local line_tbl = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)
    local line = line_tbl[1]
    if not line then break end

    if is_separator(line) then
      break
    end

    local level = get_header_level(line)
    if level and level < min_level then
      table.insert(stack, 1, { level = level, text = line })
      min_level = level
      if min_level <= 1 then break end
    end
  end

  return stack
end

---Check how many overlay lines we can show without covering a separator.
---@param bufnr number
---@param first_visible number
---@param desired_height number
---@return number
local function get_max_overlay_height(bufnr, first_visible, desired_height)
  local lines = vim.api.nvim_buf_get_lines(bufnr, first_visible - 1, first_visible - 1 + desired_height, false)
  for i, line in ipairs(lines) do
    if is_separator(line) then
      return i - 1
    end
  end
  return desired_height
end

---Close the overlay window if open.
function M.close_overlay()
  if state.overlay_win and vim.api.nvim_win_is_valid(state.overlay_win) then
    vim.api.nvim_win_close(state.overlay_win, true)
  end
  state.overlay_win = nil
  if state.overlay_buf and vim.api.nvim_buf_is_valid(state.overlay_buf) then
    vim.api.nvim_buf_delete(state.overlay_buf, { force = true })
  end
  state.overlay_buf = nil
  state._overlay_height = 0
end

---Create or update the overlay window with the given header lines.
---@param header_lines string[]
local function show_overlay(header_lines)
  local notepad_win = state.notepad_win
  if not notepad_win or not vim.api.nvim_win_is_valid(notepad_win) then
    M.close_overlay()
    return
  end

  local width = vim.api.nvim_win_get_width(notepad_win)
  local height = #header_lines

  if state.overlay_win and vim.api.nvim_win_is_valid(state.overlay_win) then
    if state.overlay_buf and vim.api.nvim_buf_is_valid(state.overlay_buf) then
      vim.api.nvim_buf_set_lines(state.overlay_buf, 0, -1, false, header_lines)
      vim.api.nvim_win_set_config(state.overlay_win, {
        relative = 'win',
        win = notepad_win,
        row = 0,
        col = 0,
        width = width,
        height = height,
      })
    end
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, header_lines)
  vim.bo[buf].filetype = 'markdown'

  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'win',
    win = notepad_win,
    row = 0,
    col = 0,
    width = width,
    height = height,
    focusable = false,
    zindex = 200,
    style = 'minimal',
    noautocmd = true,
  })

  state.overlay_buf = buf
  state.overlay_win = win
end

---Recalculate and update the sticky header overlay.
function M.update()
  local notepad_win = state.notepad_win
  local notepad_buf = state.notepad_buf
  if not notepad_win or not vim.api.nvim_win_is_valid(notepad_win) then
    M.close_overlay()
    return
  end
  if not notepad_buf or not vim.api.nvim_buf_is_valid(notepad_buf) then
    M.close_overlay()
    return
  end

  local first_visible = vim.api.nvim_win_call(notepad_win, function()
    return vim.fn.line('w0')
  end)

  if first_visible <= 1 then
    M.close_overlay()
    return
  end

  local stack = build_header_stack(notepad_buf, first_visible, state._overlay_height)
  if #stack == 0 then
    M.close_overlay()
    return
  end

  local max_height = get_max_overlay_height(notepad_buf, first_visible, #stack)
  if max_height <= 0 then
    M.close_overlay()
    return
  end

  local height = math.min(#stack, max_height)

  if height ~= state._overlay_height then
    stack = build_header_stack(notepad_buf, first_visible, height)
    if #stack == 0 then
      M.close_overlay()
      return
    end
    max_height = get_max_overlay_height(notepad_buf, first_visible, #stack)
    if max_height <= 0 then
      M.close_overlay()
      return
    end
    height = math.min(#stack, max_height)
  end

  local header_lines = {}
  local start_idx = #stack - height + 1
  if start_idx < 1 then start_idx = 1 end
  for i = start_idx, #stack do
    table.insert(header_lines, stack[i].text)
  end

  show_overlay(header_lines)
  state._overlay_height = #header_lines

  if not state._adjusting and notepad_win == vim.api.nvim_get_current_win() then
    local visual_row = vim.api.nvim_win_call(notepad_win, function()
      return vim.fn.winline()
    end)
    if visual_row <= #header_lines then
      state._adjusting = true
      local cursor_line = vim.api.nvim_win_get_cursor(notepad_win)[1]
      local new_topline = cursor_line - #header_lines
      if new_topline < 1 then new_topline = 1 end
      vim.api.nvim_win_call(notepad_win, function()
        vim.fn.winrestview({ topline = new_topline })
      end)
      vim.schedule(function()
        state._adjusting = false
      end)
    end
  end
end

return M

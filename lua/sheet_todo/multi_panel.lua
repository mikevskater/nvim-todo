-- Multi-panel UI for group tabs
-- Left panel: group list with CRUD keymaps
-- Right panel: editable markdown with all notepad features
local M = {}

local cfg = require('sheet_todo.config')
local group_manager = require('sheet_todo.group_manager')
local hide_completed = require('sheet_todo.features.hide_completed')
local folding = require('sheet_todo.features.folding')
local sticky_headers = require('sheet_todo.features.sticky_headers')

---@class MultiPanelState
---@field panel_state table? MultiPanelState from nvim-float
---@field right_buf number?
---@field right_win number?
---@field saved_content string? Last saved content (for unsaved detection)
---@field has_unsaved_changes boolean
---@field ignore_changes boolean
---@field on_save function? Save callback from init.lua
local state = {
  panel_state = nil,
  right_buf = nil,
  right_win = nil,
  saved_content = nil,
  has_unsaved_changes = false,
  ignore_changes = false,
  on_save = nil,
}

local PANEL_GROUPS = "groups"
local PANEL_EDITOR = "editor"
local unsaved_marker = "\u{25cf}"

-- ============================================================================
-- HIGHLIGHT GROUPS
-- ============================================================================

local function setup_highlights()
  vim.api.nvim_set_hl(0, 'SheetTodoActiveGroup', { default = true, bold = true })
end

-- ============================================================================
-- LEFT PANEL RENDERING
-- ============================================================================

---Render the left panel group list.
---@param _mp_state table MultiPanelState (unused, groups come from group_manager)
---@return string[] lines, table[] highlights
local function render_left_panel(_mp_state)
  local groups = group_manager.get_groups()
  local lines = {}
  local highlights = {}

  for i, g in ipairs(groups) do
    local prefix = g.is_active and "\u{25b8} " or "  "
    local line = prefix .. g.name
    table.insert(lines, line)

    if g.is_active then
      table.insert(highlights, {
        line = i - 1,  -- 0-indexed
        col_start = 0,
        col_end = #line,
        hl_group = 'SheetTodoActiveGroup',
      })
    end
  end

  if #lines == 0 then
    lines = { "  (no groups)" }
  end

  return lines, highlights
end

-- ============================================================================
-- RIGHT PANEL HELPERS
-- ============================================================================

---Get content from the right panel buffer.
---@return string
local function get_right_content()
  if not state.right_buf or not vim.api.nvim_buf_is_valid(state.right_buf) then
    return ""
  end
  local lines = vim.api.nvim_buf_get_lines(state.right_buf, 0, -1, false)
  return table.concat(lines, "\n")
end

---Get full content including hidden completed tasks.
---@return string
local function get_right_full_content()
  if hide_completed.is_active() then
    return hide_completed.get_full_content(state.right_buf)
  end
  return get_right_content()
end

---Set content in the right panel buffer.
---@param content string
local function set_right_content(content)
  if not state.right_buf or not vim.api.nvim_buf_is_valid(state.right_buf) then
    return
  end

  state.ignore_changes = true

  vim.api.nvim_buf_set_option(state.right_buf, 'modifiable', true)
  local lines = vim.split(content, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(state.right_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.right_buf, 'modified', false)

  state.saved_content = content
  state.has_unsaved_changes = false

  vim.schedule(function()
    state.ignore_changes = false
  end)
end

---Get cursor position from the right panel.
---@return { line: number, col: number }
local function get_right_cursor()
  if not state.right_win or not vim.api.nvim_win_is_valid(state.right_win) then
    return { line = 1, col = 0 }
  end
  local pos = vim.api.nvim_win_get_cursor(state.right_win)
  return { line = pos[1], col = pos[2] }
end

---Set cursor position in the right panel.
---@param pos { line: number, col: number }
local function set_right_cursor(pos)
  if not state.right_win or not vim.api.nvim_win_is_valid(state.right_win) then
    return
  end
  if not state.right_buf or not vim.api.nvim_buf_is_valid(state.right_buf) then
    return
  end
  local total = vim.api.nvim_buf_line_count(state.right_buf)
  local line = math.max(1, math.min(pos.line or 1, total))
  vim.api.nvim_win_set_cursor(state.right_win, { line, pos.col or 0 })
end

-- ============================================================================
-- UNSAVED STATE
-- ============================================================================

local function update_unsaved_state()
  if not state.right_buf or not vim.api.nvim_buf_is_valid(state.right_buf) then
    return
  end

  local current = get_right_content()
  local prev = state.has_unsaved_changes

  if state.saved_content then
    state.has_unsaved_changes = (current ~= state.saved_content)
  else
    state.has_unsaved_changes = (#current > 0)
  end

  -- Update right panel title if state changed
  if prev ~= state.has_unsaved_changes and state.panel_state then
    local group_name = group_manager.get_active_group() or "Editor"
    local title = state.has_unsaved_changes
      and (unsaved_marker .. " " .. group_name .. " ")
      or (" " .. group_name .. " ")
    state.panel_state:update_panel_title(PANEL_EDITOR, title)
  end
end

-- ============================================================================
-- GROUP SWITCHING
-- ============================================================================

---Switch to a different group.
---@param name string Group name to switch to
local function switch_group(name)
  if not state.panel_state then return end
  if name == group_manager.get_active_group() then return end

  -- Save current right-panel content and cursor to group_manager
  -- Must get full content BEFORE resetting hide_completed (to capture hidden lines)
  local full_content = get_right_full_content()
  hide_completed.reset()
  group_manager.set_active_content(full_content)
  group_manager.set_active_cursor(get_right_cursor())

  -- Switch active group
  group_manager.set_active_group(name)

  -- Load new group's content
  set_right_content(group_manager.get_active_content())

  -- Restore cursor
  vim.schedule(function()
    set_right_cursor(group_manager.get_active_cursor())
  end)

  -- Update right panel title
  state.panel_state:update_panel_title(PANEL_EDITOR, " " .. name .. " ")

  -- Re-render left panel
  state.panel_state:render_panel(PANEL_GROUPS)
end

-- ============================================================================
-- LEFT PANEL KEYMAPS
-- ============================================================================

---Get the group name under cursor in the left panel.
---@return string?
local function get_group_under_cursor()
  if not state.panel_state then return nil end
  local row = state.panel_state:get_cursor(PANEL_GROUPS)
  if not row then return nil end
  return group_manager.get_group_at(row)
end

local function handle_select_group()
  local name = get_group_under_cursor()
  if name then
    switch_group(name)
  end
end

local function handle_add_group()
  vim.ui.input({ prompt = "New group name: " }, function(name)
    if not name or name == "" then return end
    vim.schedule(function()
      if group_manager.add_group(name) then
        state.panel_state:render_panel(PANEL_GROUPS)
        vim.notify("Group '" .. name .. "' added", vim.log.levels.INFO)
      else
        vim.notify("Group '" .. name .. "' already exists", vim.log.levels.WARN)
      end
    end)
  end)
end

local function handle_delete_group()
  local name = get_group_under_cursor()
  if not name then return end
  if group_manager.get_group_count() <= 1 then
    vim.notify("Cannot delete the last group", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "Delete group '" .. name .. "'? (y/n): " }, function(answer)
    if answer ~= "y" and answer ~= "Y" then return end
    vim.schedule(function()
      local was_active = (name == group_manager.get_active_group())
      if group_manager.remove_group(name) then
        if was_active then
          -- Load the new active group's content
          set_right_content(group_manager.get_active_content())
          vim.schedule(function()
            set_right_cursor(group_manager.get_active_cursor())
          end)
          local new_name = group_manager.get_active_group() or "Editor"
          state.panel_state:update_panel_title(PANEL_EDITOR, " " .. new_name .. " ")
        end
        state.panel_state:render_panel(PANEL_GROUPS)
        vim.notify("Group '" .. name .. "' deleted", vim.log.levels.INFO)
      end
    end)
  end)
end

local function handle_rename_group()
  local name = get_group_under_cursor()
  if not name then return end

  vim.ui.input({ prompt = "Rename '" .. name .. "' to: ", default = name }, function(new_name)
    if not new_name or new_name == "" or new_name == name then return end
    vim.schedule(function()
      if group_manager.rename_group(name, new_name) then
        state.panel_state:render_panel(PANEL_GROUPS)
        -- Update right panel title if this was the active group
        if group_manager.get_active_group() == new_name then
          state.panel_state:update_panel_title(PANEL_EDITOR, " " .. new_name .. " ")
        end
        vim.notify("Renamed to '" .. new_name .. "'", vim.log.levels.INFO)
      else
        vim.notify("Name '" .. new_name .. "' already exists", vim.log.levels.WARN)
      end
    end)
  end)
end

local function handle_reorder_down()
  local name = get_group_under_cursor()
  if name and group_manager.reorder_down(name) then
    state.panel_state:render_panel(PANEL_GROUPS)
    -- Move cursor down to follow the group
    local row = state.panel_state:get_cursor(PANEL_GROUPS)
    if row then
      state.panel_state:set_cursor(PANEL_GROUPS, row + 1, 0)
    end
  end
end

local function handle_reorder_up()
  local name = get_group_under_cursor()
  if name and group_manager.reorder_up(name) then
    state.panel_state:render_panel(PANEL_GROUPS)
    -- Move cursor up to follow the group
    local row = state.panel_state:get_cursor(PANEL_GROUPS)
    if row then
      state.panel_state:set_cursor(PANEL_GROUPS, row - 1, 0)
    end
  end
end

-- ============================================================================
-- RIGHT PANEL ACTIONS
-- ============================================================================

local function handle_save()
  if state.on_save then
    state.on_save()
  end
end

local function handle_revert()
  if not state.saved_content then
    vim.notify("No saved content to revert to", vim.log.levels.WARN)
    return
  end
  hide_completed.reset()
  set_right_content(state.saved_content)
  vim.notify("Reverted to last saved content", vim.log.levels.INFO)
end

local function handle_toggle_completed()
  if state.right_buf and vim.api.nvim_buf_is_valid(state.right_buf) then
    hide_completed.toggle(state.right_buf)
  end
end

local function handle_next_todo()
  if not state.right_buf or not vim.api.nvim_buf_is_valid(state.right_buf) then
    return
  end
  if not state.right_win or not vim.api.nvim_win_is_valid(state.right_win) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(state.right_buf, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(state.right_win)
  local current_line = cursor[1]
  local total = #lines

  for offset = 1, total do
    local idx = ((current_line - 1 + offset) % total) + 1
    if lines[idx]:match('^%s*%- %[ %]') then
      vim.api.nvim_win_set_cursor(state.right_win, { idx, 0 })
      return
    end
  end

  vim.notify("No unchecked todos", vim.log.levels.INFO)
end

local function handle_close()
  M.close()
end

-- ============================================================================
-- CONTROLS
-- ============================================================================

---Format a key or key table for display.
---@param k string|string[]
---@return string
local function fmt_key(k)
  if type(k) == 'table' then return table.concat(k, ' / ') end
  return k
end

---Build controls array for nvim-float's "? = Controls" footer.
---@return table[]
local function build_controls()
  local km = cfg.get('keymaps')
  return {
    { header = "Groups", keys = {
      { key = "Enter", desc = "Select group" },
      { key = "a", desc = "Add group" },
      { key = "d", desc = "Delete group" },
      { key = "r", desc = "Rename group" },
      { key = "J / K", desc = "Reorder group" },
    }},
    { header = "Editing", keys = {
      { key = fmt_key(km.save), desc = "Save to cloud" },
      { key = fmt_key(km.revert), desc = "Revert to saved" },
    }},
    { header = "View", keys = {
      { key = fmt_key(km.toggle_completed), desc = "Hide/show completed" },
      { key = fmt_key(km.next_todo), desc = "Jump to next todo" },
    }},
    { header = "Folding", keys = {
      { key = "za", desc = "Toggle fold" },
      { key = "zM", desc = "Close all folds" },
      { key = "zR", desc = "Open all folds" },
    }},
    { header = "Navigation", keys = {
      { key = "Tab / S-Tab", desc = "Switch panel" },
      { key = fmt_key(km.close), desc = "Close" },
      { key = "?", desc = "Show controls" },
    }},
  }
end

-- ============================================================================
-- FEATURE SETUP
-- ============================================================================

---Disable autocomplete on the right panel buffer.
---@param buf number
local function disable_completion(buf)
  if not cfg.get('disable_completion') then
    return
  end
  vim.b[buf].sheet_todo_buffer = true
  vim.b[buf].completion = false -- blink.cmp
  pcall(function()
    require('cmp').setup.buffer({ enabled = false }) -- nvim-cmp
  end)
end

---Set up change tracking on the right panel buffer.
---@param buf number
local function attach_change_tracking(buf)
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if state.ignore_changes then
        return
      end
      vim.schedule(function()
        update_unsaved_state()
      end)
    end,
  })
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Show the multi-panel UI.
---@param on_save_callback function Save callback from init.lua
function M.show(on_save_callback)
  local ok, nvim_float = pcall(require, 'nvim-float')
  if not ok then
    vim.notify("nvim-float required for multi-panel mode", vim.log.levels.ERROR)
    return
  end

  nvim_float.ensure_setup()
  setup_highlights()

  state.on_save = on_save_callback
  state.has_unsaved_changes = false
  state.saved_content = nil
  state.ignore_changes = false

  local controls = build_controls()
  local km = cfg.get('keymaps')

  local panel_state = nvim_float.create_multi_panel({
    layout = {
      split = "horizontal",
      children = {
        {
          name = PANEL_GROUPS,
          title = " Groups ",
          ratio = cfg.get('left_panel_width'),
          on_render = render_left_panel,
        },
        {
          name = PANEL_EDITOR,
          title = " Editor ",
          ratio = 1 - cfg.get('left_panel_width'),
          filetype = "markdown",
          on_create = function(buf, win)
            -- Make editable
            vim.api.nvim_buf_set_option(buf, 'modifiable', true)
            vim.api.nvim_buf_set_option(buf, 'readonly', false)
          end,
        },
      },
    },
    total_width_ratio = 0.85,
    total_height_ratio = 0.8,
    initial_focus = PANEL_EDITOR,
    controls = controls,
    on_close = function()
      M.cleanup()
    end,
  })

  if not panel_state then
    vim.notify("Failed to create multi-panel layout", vim.log.levels.ERROR)
    return
  end

  state.panel_state = panel_state
  state.right_buf = panel_state:get_panel_buffer(PANEL_EDITOR)
  state.right_win = panel_state:get_panel_window(PANEL_EDITOR)

  -- Set up right panel features
  if state.right_buf and state.right_win then
    -- Wrap and linebreak for markdown
    vim.api.nvim_set_option_value('wrap', true, { win = state.right_win })
    vim.api.nvim_set_option_value('linebreak', true, { win = state.right_win })

    -- Change tracking
    attach_change_tracking(state.right_buf)

    -- Disable autocomplete
    disable_completion(state.right_buf)

    -- Collapsible headers
    folding.setup(state.right_win, state.right_buf)

    -- Sticky headers
    sticky_headers.setup(state.right_win, state.right_buf)
  end

  -- Set up shared keymaps (both panels)
  local close_keys = km.close
  if type(close_keys) ~= 'table' then close_keys = { close_keys } end

  local shared_keymaps = {}
  for _, key in ipairs(close_keys) do
    shared_keymaps[key] = handle_close
  end
  shared_keymaps['<Tab>'] = function() panel_state:focus_next_panel() end
  shared_keymaps['<S-Tab>'] = function() panel_state:focus_prev_panel() end
  panel_state:set_keymaps(shared_keymaps)

  -- Set up left panel keymaps
  panel_state:set_panel_keymaps(PANEL_GROUPS, {
    ['<CR>'] = handle_select_group,
    ['a'] = handle_add_group,
    ['d'] = handle_delete_group,
    ['r'] = handle_rename_group,
    ['J'] = handle_reorder_down,
    ['K'] = handle_reorder_up,
  })

  -- Set up right panel keymaps
  local right_keymaps = {}
  local save_key = km.save
  if type(save_key) == 'table' then save_key = save_key[1] end
  right_keymaps[save_key] = handle_save

  local revert_key = km.revert
  if type(revert_key) == 'table' then revert_key = revert_key[1] end
  right_keymaps[revert_key] = handle_revert

  local toggle_key = km.toggle_completed
  if type(toggle_key) == 'table' then toggle_key = toggle_key[1] end
  right_keymaps[toggle_key] = handle_toggle_completed

  local next_key = km.next_todo
  if type(next_key) == 'table' then next_key = next_key[1] end
  right_keymaps[next_key] = handle_next_todo

  panel_state:set_panel_keymaps(PANEL_EDITOR, right_keymaps)

  -- Insert-mode save keymap on right panel
  if state.right_buf and vim.api.nvim_buf_is_valid(state.right_buf) then
    vim.keymap.set('i', save_key, handle_save, { buffer = state.right_buf, nowait = true, silent = true })
  end
end

---Set content in the right panel (called after loading from Pantry).
---@param content string
function M.set_content(content)
  set_right_content(content)
end

---Get content from the right panel.
---@return string
function M.get_content()
  return get_right_full_content()
end

---Get cursor position from the right panel.
---@return { line: number, col: number }
function M.get_cursor()
  return get_right_cursor()
end

---Set cursor position in the right panel.
---@param pos { line: number, col: number }
function M.set_cursor(pos)
  set_right_cursor(pos)
end

---Mark content as saved.
function M.mark_as_saved()
  state.saved_content = get_right_content()
  state.has_unsaved_changes = false
  if state.panel_state then
    local name = group_manager.get_active_group() or "Editor"
    state.panel_state:update_panel_title(PANEL_EDITOR, " " .. name .. " ")
  end
end

---Render the left panel (refresh group list).
function M.render_groups()
  if state.panel_state then
    state.panel_state:render_panel(PANEL_GROUPS)
  end
end

---Update the right panel title with active group name.
function M.update_editor_title()
  if state.panel_state then
    local name = group_manager.get_active_group() or "Editor"
    state.panel_state:update_panel_title(PANEL_EDITOR, " " .. name .. " ")
  end
end

---Set ignore changes flag (used during spinner/loading).
---@param value boolean
function M.set_ignore_changes(value)
  state.ignore_changes = value
end

---Clean up on close.
function M.cleanup()
  -- Save current right-panel content to group_manager
  if state.right_buf and vim.api.nvim_buf_is_valid(state.right_buf) then
    local full_content = get_right_full_content()
    group_manager.set_active_content(full_content)
    group_manager.set_active_cursor(get_right_cursor())
  end

  sticky_headers.cleanup()
  hide_completed.reset()

  state.panel_state = nil
  state.right_buf = nil
  state.right_win = nil
  state.saved_content = nil
  state.has_unsaved_changes = false
  state.ignore_changes = false
  state.on_save = nil
end

---Close the multi-panel UI.
function M.close()
  if state.panel_state then
    state.panel_state:close()
  end
end

---Check if multi-panel is currently open.
---@return boolean
function M.is_open()
  return state.panel_state ~= nil
    and state.right_win ~= nil
    and vim.api.nvim_win_is_valid(state.right_win)
end

return M

local M = {}

local notepad = require('sheet_todo.notepad')
local pantry = require('sheet_todo.pantry')
local config = require('sheet_todo.config')
local ui = require('sheet_todo.ui')
local float_provider = require('sheet_todo.float_provider')
local multi_panel = require('sheet_todo.multi_panel')
local group_manager = require('sheet_todo.group_manager')

-- State tracking
M.state = {
  bufnr = nil,
  winnr = nil,
  loading = false,
  saving = false,
  last_error = nil
}

-- Show the notepad (routes between single-panel and multi-panel)
function M.show()
  if config.get('multi_panel') and float_provider.has_nvim_float() then
    M.show_multi_panel()
  else
    M.show_single_panel()
  end
end

-- Show single-panel mode (original behavior)
function M.show_single_panel()
  if M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    -- Already open, focus it
    if M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then
      vim.api.nvim_set_current_win(M.state.winnr)
      return
    end
  end

  -- Create floating window
  M.state.bufnr, M.state.winnr = notepad.create_float()

  -- Set up save callback
  notepad.on_save = M.save

  -- Check if there are unsaved changes to restore
  if notepad.has_unsaved_content() then
    local unsaved_content = notepad.get_unsaved_content()
    local lines = vim.split(unsaved_content, "\n", { plain = true })
    vim.schedule(function()
      if M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
        -- Use the proper API that handles change tracking
        notepad.restore_unsaved_content(lines)
      end
    end)
    vim.notify("Restored unsaved changes", vim.log.levels.INFO)
    return
  end

  -- Disable change tracking for initial load sequence
  notepad.set_ignore_changes(true)

  -- Start animated spinner
  ui.start_spinner("Loading from Pantry", function(frame)
    if M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
      vim.schedule(function()
        if M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
          vim.api.nvim_buf_set_option(M.state.bufnr, 'modifiable', true)
          vim.api.nvim_buf_set_lines(M.state.bufnr, 0, -1, false, {
            "",
            "  " .. frame .. " Loading from Pantry...",
            ""
          })
          vim.api.nvim_buf_set_option(M.state.bufnr, 'modifiable', false)
        end
      end)
    end
  end)

  -- Load content from Pantry
  M.state.loading = true

  pantry.get_content(function(success, data, err)
    M.state.loading = false
    ui.stop_spinner()

    if not success then
      M.state.last_error = err
      vim.notify("Failed to load: " .. (err or "unknown error"), vim.log.levels.ERROR)
      -- Still allow editing with empty content
      notepad.set_content({" "})
      return
    end

    if data and data.content then
      -- Split content into lines
      local lines = vim.split(data.content, "\n", { plain = true })
      notepad.set_content(lines)

      -- Restore cursor position
      if data.cursor_pos then
        notepad.set_cursor(data.cursor_pos.line, data.cursor_pos.col)
      end

      vim.notify("Notepad loaded", vim.log.levels.INFO)
    else
      -- Empty basket or first time
      notepad.set_content({" "})
      vim.notify("New notepad created", vim.log.levels.INFO)
    end
  end)
end

-- Show multi-panel mode (groups + editor)
function M.show_multi_panel()
  -- Already open, focus it
  if multi_panel.is_open() then
    return
  end

  -- Create multi-panel UI
  multi_panel.show(M.save_multi_panel)

  -- Disable change tracking during load
  multi_panel.set_ignore_changes(true)

  -- Load content from Pantry (raw data for group_manager)
  M.state.loading = true

  pantry.get_raw_data(function(success, data, err)
    M.state.loading = false

    if not success then
      M.state.last_error = err
      vim.notify("Failed to load: " .. (err or "unknown error"), vim.log.levels.ERROR)
      -- Load empty default group
      group_manager.load(nil)
      multi_panel.set_content(group_manager.get_active_content())
      multi_panel.render_groups()
      multi_panel.update_editor_title()
      return
    end

    -- Load into group_manager (handles format detection/migration)
    group_manager.load(data)

    -- Set right panel content from active group
    multi_panel.set_content(group_manager.get_active_content())

    -- Restore cursor position
    vim.schedule(function()
      local cursor = group_manager.get_active_cursor()
      if cursor then
        multi_panel.set_cursor(cursor)
      end
    end)

    -- Render left panel with groups
    multi_panel.render_groups()

    -- Update right panel title
    multi_panel.update_editor_title()

    vim.notify("Notepad loaded (" .. group_manager.get_group_count() .. " groups)", vim.log.levels.INFO)
  end)
end

-- Save the notepad content (routes between single-panel and multi-panel)
function M.save()
  if config.get('multi_panel') and multi_panel.is_open() then
    M.save_multi_panel()
  else
    M.save_single_panel()
  end
end

-- Save single-panel mode (original behavior)
function M.save_single_panel()
  if not M.state.bufnr or not vim.api.nvim_buf_is_valid(M.state.bufnr) then
    vim.notify("No notepad buffer to save", vim.log.levels.WARN)
    return
  end

  if M.state.saving then
    vim.notify("Already saving...", vim.log.levels.WARN)
    return
  end

  -- Get current content (including hidden completed tasks) and cursor position
  local content = notepad.get_full_content()
  local cursor_pos = notepad.get_cursor()

  M.state.saving = true
  vim.notify("Saving to Pantry...", vim.log.levels.INFO)

  pantry.save_content(content, cursor_pos, function(success, err)
    M.state.saving = false

    if success then
      vim.notify("Saved successfully", vim.log.levels.INFO)
      M.state.last_error = nil
      -- Mark content as saved in notepad
      notepad.mark_as_saved()
    else
      M.state.last_error = err
      vim.notify("Save failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  end)
end

-- Save multi-panel mode (all groups to Pantry)
function M.save_multi_panel()
  if M.state.saving then
    vim.notify("Already saving...", vim.log.levels.WARN)
    return
  end

  -- Collect right panel content into group_manager
  group_manager.set_active_content(multi_panel.get_content())
  group_manager.set_active_cursor(multi_panel.get_cursor())

  -- Serialize all groups and save
  local data = group_manager.serialize()

  M.state.saving = true
  vim.notify("Saving to Pantry...", vim.log.levels.INFO)

  pantry.save_raw_data(data, function(success, err)
    M.state.saving = false

    if success then
      vim.notify("Saved successfully", vim.log.levels.INFO)
      M.state.last_error = nil
      multi_panel.mark_as_saved()
    else
      M.state.last_error = err
      vim.notify("Save failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  end)
end

-- Close the notepad
function M.close()
  if config.get('multi_panel') and multi_panel.is_open() then
    multi_panel.close()
    group_manager.reset()
  else
    notepad.close()
  end
  M.state.winnr = nil
  M.state.bufnr = nil
end

-- Show status
function M.status()
  local mp_active = config.get('multi_panel') and float_provider.has_nvim_float()
  local lines = {
    "Sheet Todo Notepad Status",
    "========================",
    "",
    "Configuration:",
    "  Pantry ID: " .. (config.get('pantry_id') or "NOT SET"),
    "  Basket: " .. (config.get('basket_name') or "NOT SET"),
    "  Float Provider: " .. (float_provider.has_nvim_float() and "nvim-float" or "raw"),
    "  Multi-Panel: " .. (mp_active and "enabled" or "disabled"),
    "",
    "State:",
    "  Buffer: " .. (M.state.bufnr and "active" or "inactive"),
    "  Window: " .. (mp_active and (multi_panel.is_open() and "open (multi-panel)" or "closed") or (M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) and "open" or "closed")),
    "  Loading: " .. (M.state.loading and "yes" or "no"),
    "  Saving: " .. (M.state.saving and "yes" or "no"),
    "  Last Error: " .. (M.state.last_error or "none"),
  }

  if mp_active and group_manager.is_loaded() then
    table.insert(lines, "")
    table.insert(lines, "Groups:")
    table.insert(lines, "  Active: " .. (group_manager.get_active_group() or "none"))
    table.insert(lines, "  Count: " .. group_manager.get_group_count())
  end
  
  -- Create status buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  -- Open in split
  vim.cmd('split')
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_height(win, #lines + 2)
end

-- Setup function
function M.setup(opts)
  opts = opts or {}

  -- Initialize config with all user options
  config.setup(opts)
  
  -- Register commands
  vim.api.nvim_create_user_command('TodoShow', M.show, {})
  vim.api.nvim_create_user_command('TodoSave', M.save, {})
  vim.api.nvim_create_user_command('TodoClose', M.close, {})
  vim.api.nvim_create_user_command('TodoStatus', M.status, {})
  
  -- Register keymap
  vim.keymap.set('n', '<leader>otd', M.show, { desc = 'Open Todo notepad' })
  
  vim.notify("Sheet Todo Notepad ready. Use :TodoShow or <leader>otd to open.", vim.log.levels.INFO)
end

return M

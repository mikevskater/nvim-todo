---@class nvim-todo.data.group
local M = {}

local state = require('nvim-todo.data.group.state')
local path = require('nvim-todo.data.group.path')
local tree = require('nvim-todo.data.group.tree')
local cursor = require('nvim-todo.data.group.cursor')
local crud = require('nvim-todo.data.group.crud')

-- State
M.state = state
M.reset = state.reset

-- Path utilities
M.split_path = path.split_path
M.join_path = path.join_path
M.get_parent_path = path.get_parent_path

-- Tree
M.find_group = tree.find_group
M.build_tree = tree.build_tree

-- Cursor
M.get_active_cursor = cursor.get_active_cursor
M.set_active_cursor = cursor.set_active_cursor

-- CRUD
M.add_group = crud.add_group
M.remove_group = crud.remove_group
M.rename_group = crud.rename_group
M.reorder_up = crud.reorder_up
M.reorder_down = crud.reorder_down
M.get_reparent_targets = crud.get_reparent_targets
M.reparent_group = crud.reparent_group
M.set_icon = crud.set_icon
M.set_colors = crud.set_colors
M.get_group_count = crud.get_group_count

return M

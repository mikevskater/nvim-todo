-- Re-exports for folding feature.
local M = {}

local expr = require('nvim-todo.features.folding.expr')
local setup_mod = require('nvim-todo.features.folding.setup')

M.setup = setup_mod.setup
M.fold_text = expr.fold_text
M.toggle_fold = expr.toggle_fold
M.close_all_folds = expr.close_all_folds
M.open_all_folds = expr.open_all_folds

return M

-- Neovim autoload entry point for nvim-todo.
-- Setup is called from the user's lazy.nvim config, not here.
-- This file just guards against double-load.
if vim.g.loaded_nvim_todo then
  return
end
vim.g.loaded_nvim_todo = true

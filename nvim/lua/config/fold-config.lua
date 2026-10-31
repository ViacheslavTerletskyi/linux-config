vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99

local has_ts = pcall(require, "nvim-treesitter.configs")

if has_ts and vim.treesitter and vim.treesitter.foldexpr then
  vim.o.foldmethod = "expr"
  vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
else
  vim.o.foldmethod = "indent"
end

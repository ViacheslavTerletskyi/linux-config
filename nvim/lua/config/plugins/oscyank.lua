return {
  "ojroques/vim-oscyank",
  cond = function()
    return vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
  end,
  config = function()
    vim.keymap.set("n", "<leader>y", "<Plug>OSCYankOperator", {silent = true})
    vim.keymap.set("n", "<leader>yy", "<leader>y_", {remap = true, silent = true})
    vim.keymap.set("v", "<leader>y", "<Plug>OSCYankVisual", {silent = true})
  end
}


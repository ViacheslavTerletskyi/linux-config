vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set("x", "J", ":move '>+1<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set("x", "K", ":move '<-2<CR>gv=gv", { noremap = true, silent = true })

vim.keymap.set("n", "<leader>y", "\"+y")
vim.keymap.set("v", "<leader>y", "\"+y")
vim.keymap.set("n", "<leader>Y", "\"+Y")

vim.keymap.set("n", "<M-j>", "<cmd>cnext<CR>")
vim.keymap.set("n", "<M-k>", "<cmd>cprev<CR>")

vim.keymap.set('n', '<leader>ca', function() vim.lsp.buf.code_action({apply=true}) end, bufopts)

vim.keymap.set('n', '<leader>gd', function() vim.lsp.buf.definition() end, bufopts)

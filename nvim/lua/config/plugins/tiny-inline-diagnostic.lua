return {
  "rachartier/tiny-inline-diagnostic.nvim",
  event = "VeryLazy",
  priority = 1000,
  config = function()
    require "tiny-inline-diagnostic".setup {
      break_line = {
        enabled = true,
        after = 10,
      },
    }
    vim.diagnostic.config({ virtual_text = false })
  end,
}

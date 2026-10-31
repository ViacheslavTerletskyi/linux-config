return {
  "stevearc/conform.nvim",
   keys = {
    {
      "<leader>af",
      function()
        require("conform").format({
          async = true,
          lsp_fallback = false,
        })
      end,
      desc = "Format with Prettier",
    },
  },
  opts = {
    formatters_by_ft = {
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      scss = { "prettier" },
      markdown = { "prettier" },
      htmlangular = { "prettier" },
    },
    format_on_save = false,
  },
}

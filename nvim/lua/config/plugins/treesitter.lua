return {
  {
    'nvim-treesitter/nvim-treesitter', 
    lazy = false,
    build = ':TSUpdate',
    config = function()
      require ('nvim-treesitter').setup {
        ensure_installed = { "c_sharp", "javascript", "typescript", "c", "lua", "go", "gomod", "gowork", "gosum", "vim", "vimdoc", "query", "markdown", "markdown_inline" },

        sync_install = false,
        auto_install = false,

        disable = function(lang, buf)
          local max_filesize = 200 * 1024 -- 200 KB
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then
            return true
          end
        end,

        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
      }
    end
  }
}

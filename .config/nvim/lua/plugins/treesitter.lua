return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local config = require("nvim-treesitter.configs")
    config.setup({
      ensure_installed = {
        "yaml",
        "markdown",
        "markdown_inline",
      },
      auto_install = true,
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
    })
  end
}

-- return {
--   "nvim-treesitter/nvim-treesitter",
--   branch = "main",
--   lazy = false,
--   build = ":TSUpdate",
--   config = function()
--     local config = require("nvim-treesitter.configs")
--     config.setup({
--       ensure_installed = {
--         "yaml",
--         "markdown",
--         "markdown_inline",
--       },
--       auto_install = true,
--       sync_install = false,
--       ignore_install = { "ipkg" },
--       highlight = { enable = true },
--       indent = { enable = true },
--     })
--   end
-- }
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup()
    require("nvim-treesitter").install({
      "yaml",
      "markdown",
      "markdown_inline",
    })
  end
}

return {
  {
    "vhyrro/luarocks.nvim",
    config = true
  },
  {
    "nvim-neorg/neorg",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-neorg/lua-utils.nvim",
      "pysan3/pathlib.nvim",
      "nvim-neotest/nvim-nio",
    },
    version = "*",
    config = function()
      require("neorg").setup {
        load = {
          ["core.defaults"] = {},
          ["core.concealer"] = {},
          ["core.dirman"] = {
            config = {
              workspaces = {
                notes = "~/Documents/Notes",
              },
              default_workspace = "notes",
            },
          },
        },
      }
      vim.wo.foldlevel = 99
      vim.wo.conceallevel = 2
    end,
  }
}

return {
  {
    "olimorris/codecompanion.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "hrsh7th/nvim-cmp",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("codecompanion").setup({
        adapters = {
          gemma2 = function()
            return require("codecompanion.adapters").extend("ollama", {
              name = "gemma2",
              schema = {
                model = { default = "gemma2:27b" },
                num_ctx = { default = 4096 },
                num_predict = { default = -1 },
              },
            })
          end,
        },
        strategies = {
          chat = { adapter = "gemma2" },
          inline = { adapter = "gemma2" },
          agent = { adapter = "gemma2" },
        },
        display = {
          chat = {
            window = {
              layout = "vertical",
              position = "right"
            }
          },
        },
      })
    end,
    init = function() end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "codecompanion" }
  },
}

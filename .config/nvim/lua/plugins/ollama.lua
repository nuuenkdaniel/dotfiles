return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      language = "English",
      interactions = {
        chat = { adapter = "deepseek_r1" },
        inline = { adapter = "qwen3_coder" },
        cmd = { adapter = "qwen3_coder" },
        background = { adapter = "gemma3" },
      },
      adapters = {
        http = {
          deepseek_r1 = function()
            return require("codecompanion.adapters").extend("ollama", {
              env = { url = "http://100.121.133.88:11434" },
              name = "deepseek_r1",
              schema = {
                model = { default = "deepseek-r1:32b" },
                num_ctx = { default = 16384 },
                num_predict = { default = -1 },
              },
              parameters = { sync = true },
            })
          end,

          qwen3_coder = function()
            return require("codecompanion.adapters").extend("ollama", {
              env = { url = "http://100.121.133.88:11434" },
              name = "qwen3_coder",
              schema = {
                model = { default = "qwen3-coder:latest" },
                num_ctx = { default = 16384 },
                num_predict = { default = -1 },
              },
              parameters = { sync = true },
            })
          end,

          gemma3 = function()
            return require("codecompanion.adapters").extend("ollama", {
              env = { url = "http://100.121.133.88:11434" },
              name = "gemma3",
              schema = {
                model = { default = "gemma3:27b" },
                num_ctx = { default = 16384 },
                num_predict = { default = -1 },
              },
              parameters = { sync = true },
            })
          end,
        },
      },
    }
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "codecompanion" }
  },
  {
    "HakonHarnes/img-clip.nvim",
    opts = {
      filetypes = {
        codecompanion = {
          prompt_for_file_name = false,
          template = "[Image]($FILE_PATH)",
          use_absolute_path = true,
        },
      },
    },
  },
}

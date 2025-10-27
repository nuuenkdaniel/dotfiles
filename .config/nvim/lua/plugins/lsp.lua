return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        auto_install = true,
        automatic_enable = false,
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true
      })

      local lspconfig = require("lspconfig")
      lspconfig.pyright.setup({
        capabilities = capabilities
      })
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
      })
      lspconfig.html.setup({
        capabilities = capabilities,
      })
      lspconfig.clangd.setup({
        capabilities = capabilities,
      })
      lspconfig.bashls.setup({
        capabilities = capabilities,
      })
      lspconfig.texlab.setup({
        capabilities = capabilities,
      })
      lspconfig.rust_analyzer.setup({
        settings = {
          ["rust-analyzer"] = {
            cargo = {
              features = "all",
              buildScripts = {
                enable = true,
              },
            },
            inlayHints = {
              typeHints = true,
              parameterHints = true,
              chainingHints = true,
            },
            checkOnSave = false,
            -- checkOnSave = {
            --     features = "all",
              -- command = "clippy",
            --     extraArgs = { "--no-deps" },
            -- },
            procMacro = {
              enable = true
            },
            rustfmt = {
              rangeFormatting = { enable = true },
            },
          }
        }
      })
    end,
  },
}

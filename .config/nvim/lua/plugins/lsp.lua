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
        ensure_installed = {
          "ts_ls",
          "pyright",
          "html",
          "clangd",
          "bashls",
          "texlab",
          "rust_analyzer",
          "tailwindcss",
        },
        automatic_enable = true,
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

      -- local lspconfig = require("lspconfig")
      vim.lsp.config("ts_ls", {
        capabilities = capabilities
      })
      vim.lsp.config("pyright", {
        capabilities = capabilities
      })
      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
      })
      vim.lsp.config("html", {
        capabilities = capabilities,
      })
      vim.lsp.config("clangd", {
        capabilities = capabilities,
      })
      vim.lsp.config("bashls", {
        capabilities = capabilities,
      })
      vim.lsp.config("texlab", {
        capabilities = capabilities,
      })
      vim.lsp.config("rust_analyzer", {
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
      vim.lsp.config("tailwindcss", {
        capabilities = capabilities,
        settings = {
          tailwindCSS = {
            experimental = {
              classRegex = {
                { "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
                { "cn\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
              },
            },
          },
        },
      })
      vim.lsp.enable("lua_ls")
    end,
  },
}


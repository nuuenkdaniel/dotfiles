return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "jdtls", "quick_lint_js", "jedi_language_server", "rust_analyzer" }
      })
    end
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      lspconfig.lua_ls.setup({})
      lspconfig.jdtls.setup({})
      lspconfig.quick_lint_js.setup({})
      lspconfig.jedi_language_server.setup({})
      lspconfig.html.setup({})
      lspconfig.rust_analyzer.setup({})
    end
  }
}

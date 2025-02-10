-- Telescope keybinds
vim.keymap.set('n', '<C-h>', ':Telescope help_tags<CR>', {})

-- Neotree keybinds
vim.keymap.set('n', '<C-p>', ':Neotree toggle right<CR>', {})

-- LSP keybinds
vim.keymap.set('n', '<C-k>', vim.lsp.buf.hover, {})
vim.keymap.set({ 'n', 'v' }, '<C-a>', vim.lsp.buf.code_action, {})

-- Ollama keybinds
vim.keymap.set({ 'n', 'v' }, '<leader>oo', ":<c-u>lua require('ollama').prompt()<cr>", {})
vim.keymap.set({ 'n', 'v' }, "<leader>og", ":<c-u>lua require('ollama').prompt('Generate_Code')<cr>", {})

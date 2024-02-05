-- Telescope keybinds
vim.keymap.set('n', '<C-p>', ':Neotree toggle right<CR>', {})

-- LSP keybinds
vim.keymap.set('n', '<C-k>', vim.lsp.buf.hover, {})
vim.keymap.set({ 'n', 'v' }, '<C-a>', vim.lsp.buf.code_action, {})

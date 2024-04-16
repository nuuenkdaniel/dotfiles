return {
  'nvimdev/dashboard-nvim',
  event = 'VimEnter',
  config = function()
    require('dashboard').setup {
	
    }
  end,
  dependencies = { {'nvim-tree/nvim-web-devicons'} }
}
--[[
return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    local dashboard = require("alpha.themes.dashboard")
    dashboard.section.buttons.val = {
                dashboard.button("0", "  New file", ":ene <BAR> startinsert <CR>"),
                dashboard.button("1", "  Notes", ":Neorg workspace notes <CR>"),
                dashboard.button("2", "  To do", ":Neorg workspace personal <CR>"),
                dashboard.button("3", "  Config", ":Explore $XDG_CONFIG_HOME/nvim <CR>"),
                dashboard.button("4", "  Restore Session", ":lua require('persistence').load() <CR>"),
                dashboard.button("5", "  Previous Session", ":lua require('persistence').load({ last = true }) <CR>"),
                dashboard.button("6", "  Quit", ":qa <CR>"),
    }
    require("alpha").setup(dashboard.config)
  end
}
]]

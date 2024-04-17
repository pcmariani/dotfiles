-- [[ lualine ]] --
-- See `:help lualine.txt`
require('lualine').setup {
  options = {
    icons_enabled = false,
    theme = 'auto',
    component_separators = '|',
    section_separators = '',
  },
}

-- [[ Comment ]] --
require('Comment').setup()

-- [[ indent-blankline ]] --
-- See `:help indent_blankline.txt`
require('indent_blankline').setup {
  char = '┊',
  show_current_context = true,
  show_trailing_blankline_indent = false,
}
-- vim.api.nvim_set_hl(0, "IndentBlankLineChar", { cterm='none', guifg='#5c6370' })
vim.cmd([[highlight IndentBlankLineChar cterm=nocombine gui=nocombine guifg=#444455]])

-- [[ Gitsigns ]] --
-- See `:help gitsigns.txt`
require('gitsigns').setup {
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },
}

-- [[ Telescope ]] --
-- See `:help telescope` and `:help telescope.setup()`
require('telescope').setup {
  defaults = {
    mappings = {
      i = {
        ['<C-u>'] = false,
        ['<C-d>'] = false,
      },
    },
  },
}

-- Enable telescope fzf native, if installed
pcall(require('telescope').load_extension, 'fzf')

-- See `:help telescope.builtin`
vim.keymap.set('n', '<leader>?', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
vim.keymap.set('n', '<leader>b', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
-- vim.keymap.set('n', '<leader>/', function()
--   -- You can pass additional configuration to telescope to change theme, layout, etc.
--   require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
--     winblend = 10,
--     previewer = false,
--   })
-- end, { desc = '[/] Fuzzily search in current buffer]' })

vim.keymap.set('n', '<leader>sf', require('telescope.builtin').find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })

-- [[ neodev ]] --
-- TODO: turn on neodev for nvim config files only ??
-- Setup neovim lua configuration
-- require('neodev').setup()

-- [[ fidget ]] --
-- Turn on lsp status information
-- require('fidget').setup()

-- [[ nvim-tree ]] --
require("nvim-tree").setup()

-- [[ impatient ]] --
local status_ok, impatient = pcall(require, "impatient")
if not status_ok then
  return
end
impatient.enable_profile()

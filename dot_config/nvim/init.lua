-- Install packer
local install_path = vim.fn.stdpath 'data' .. '/site/pack/packer/start/packer.nvim'
local is_bootstrap = false
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
  is_bootstrap = true
  vim.fn.system { 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path }
  vim.cmd [[packadd packer.nvim]]
end

require('packer').startup(function(use)
  -- Package manager
  use 'wbthomason/packer.nvim'

  use { -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    requires = {
      -- Automatically install LSPs to stdpath for neovim
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      -- Useful status updates for LSP
      -- 'j-hui/fidget.nvim',
      -- Additional lua configuration, makes nvim stuff amazing
      -- 'folke/neodev.nvim',
    },
  }

  use { -- Autocompletion
    'hrsh7th/nvim-cmp',
    requires = {
      'hrsh7th/cmp-nvim-lsp',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline"
    },
  }

  use { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    run = function()
      pcall(require('nvim-treesitter.install').update { with_sync = true })
    end,
  }

  use { -- Additional text objects via treesitter
    'nvim-treesitter/nvim-treesitter-textobjects',
    after = 'nvim-treesitter',
  }

  -- Git related plugins
  -- use 'tpope/vim-fugitive'
  -- use 'tpope/vim-rhubarb'
  use 'lewis6991/gitsigns.nvim'

  use 'navarasu/onedark.nvim' -- Theme inspired by Atom
  use 'nvim-lualine/lualine.nvim' -- Fancier statusline
  use 'lukas-reineke/indent-blankline.nvim' -- Add indentation guides even on blank lines
  use 'numToStr/Comment.nvim' -- "gc" to comment visual regions/lines
  use 'tpope/vim-sleuth' -- Detect tabstop and shiftwidth automatically

  -- Fuzzy Finder (files, lsp, etc)
  use { 'nvim-telescope/telescope.nvim', branch = '0.1.x', requires = { 'nvim-lua/plenary.nvim' } }

  -- Fuzzy Finder Algorithm which requires local dependencies to be built. Only load if `make` is available
  use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make', cond = vim.fn.executable 'make' == 1 }




  -- --- MY PLUGINS ---
  use {'mechatroner/rainbow_csv', config = function()
    vim.cmd "let g:disable_rainbow_hover = 1"
  end }
  use 'nvim-treesitter/playground'
  use 'christoomey/vim-tmux-navigator'
  use "akinsho/toggleterm.nvim"
  use "lewis6991/impatient.nvim"
  use "folke/which-key.nvim"
  use "adisen99/codeschool.nvim"
  use "lunarvim/colorschemes" -- A bunch of colorschemes
  use "kyazdani42/nvim-tree.lua"
  use "moll/vim-bbye"
  use "preservim/vimux"
  -- --- END MY PLUGINS ---




  -- Add custom plugins to packer from ~/.config/nvim/lua/custom/plugins.lua
  local has_plugins, plugins = pcall(require, 'custom.plugins')
  if has_plugins then
    plugins(use)
  end

  if is_bootstrap then
    require('packer').sync()
  end
end)

-- When we are bootstrapping a configuration, it doesn't
-- make sense to execute the rest of the init.lua.
--
-- You'll need to restart nvim, and then it will work.
if is_bootstrap then
  print '=================================='
  print '    Plugins are being installed'
  print '    Wait until Packer completes,'
  print '       then restart nvim'
  print '=================================='
  return
end

-- Automatically source and re-compile packer whenever you save this init.lua
local packer_group = vim.api.nvim_create_augroup('Packer', { clear = true })
vim.api.nvim_create_autocmd('BufWritePost', {
  command = 'source <afile> | PackerCompile',
  group = packer_group,
  pattern = vim.fn.expand '$MYVIMRC',
})




-- [[ Setting options ]] -- `:help vim.o`


-- --- MY OPTS ---
vim.o.clipboard = "unnamedplus"               -- allows neovim to access the system clipboard
vim.o.hlsearch = true                         -- highlight all matches on previous search pattern
vim.o.pumheight = 15                          -- pop up menu height
vim.o.showmode = false                        -- we don't need to see things like -- INSERT -- anymore
vim.o.splitbelow = true                       -- force all horizontal splits to go below current window
vim.o.splitright = true                       -- force all vertical splits to go to the right of current window
-- vim.o.showtabline = 2                         -- always show tabs ???
-- vim.o.smartindent = true                      -- make indenting smarter again ???
-- vim.o.expandtab = true                        -- convert tabs to spaces ???
vim.wo.signcolumn = "number"                      -- always show the sign column, otherwise it would shift the text each time
vim.wo.wrap = false                            -- display lines as one long line
vim.o.equalalways = false                     -- all windows not same size after split or close
vim.wo.scrolloff = 4                           -- is one of my fav
vim.wo.sidescrolloff = 4
vim.o.grepprg = "rg --vimgrep --no-heading"
vim.o.grepformat="%f:%l:%c:%m"
vim.opt.shortmess:append({ c = true })
-- vim.cmd "let g:markdown_fenced_languages = ['json', 'xml', 'groovy', 'sh']"
-- vim.cmd "set whichwrap+=<,>,[,],h,l"
-- vim.cmd [[set iskeyword+=-]]
-- vim.cmd [[set formatoptions-=cro]] -- TODO: this doesn't seem to work
-- --- END MY OPTS ---


-- vim.o.hlsearch = false -- Set highlight on search
vim.wo.number = true -- Make line numbers default
vim.o.mouse = 'a' -- Enable mouse mode
vim.o.breakindent = true -- Enable break indent
vim.o.undofile = true -- Save undo history

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Decrease update time
vim.o.updatetime = 250
-- vim.wo.signcolumn = 'yes'

-- Set colorscheme
vim.o.termguicolors = true
vim.cmd [[colorscheme onedark]]

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'




-- [[ Basic Keymaps ]]
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`

-- --- MY MAPS ---

-- easy to command mode
vim.keymap.set('n',';',':', { noremap = true })
vim.keymap.set('n',':',';', { noremap = true })
vim.keymap.set('x',';',':', { noremap = true })
vim.keymap.set('x',':',';', { noremap = true })

-- easy to normal mode
vim.keymap.set('i','jjj','<Esc>', { noremap = true, silent = true })
vim.keymap.set('i','kkk','<Esc>', { noremap = true, silent = true })
vim.keymap.set('i','hhh','<Esc>', { noremap = true, silent = true })
vim.keymap.set('i','lll','<Esc>', { noremap = true, silent = true })

-- toggle nvim-tree
vim.keymap.set('n','<leader>e',':NvimTreeToggle<CR>', { noremap = true, silent = true })

-- tmux send last command
vim.keymap.set('n','<leader>v',':w<BAR>:silent !tmux send-keys -t\\! "\\!\\!" Enter Enter<CR>', { noremap = true, silent = true })

-- Cycle visual > visual block mode
vim.keymap.set('x','v', [[mode() ==# 'v' ? 'V' : mode() ==# '<C-v>' ? 'v' : '<C-q>']], { noremap = true, silent = true, expr = true })

-- Move text up and down
vim.keymap.set('n','<A-j>',':m .+1<CR>==', { noremap = true, silent = true })
vim.keymap.set('n','<A-k>',':m .-2<CR>==', { noremap = true, silent = true })
vim.keymap.set('i','<A-j>','<Esc>:m .+1<CR>==gi', { noremap = true, silent = true })
vim.keymap.set('i','<A-k>','<Esc>:m .-2<CR>==gi', { noremap = true, silent = true })
vim.keymap.set('v','<A-j>',':m \'>+1<CR>gv=gv', { noremap = true, silent = true })
vim.keymap.set('v','<A-k>',':m \'<-2<CR>gv=gv', { noremap = true, silent = true })

-- Better window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

-- vim-tmux-navigator navigation
-- vim.keymap.set("n", "<C-w>h", ":<C-U>TmuxNavigateLeft<cr>", { noremap = true, silent = true })
-- vim.keymap.set("n", "<C-w>j", ":<C-U>TmuxNavigateDown<cr>", { noremap = true, silent = true })
-- vim.keymap.set("n", "<C-w>k", ":<C-U>TmuxNavigateUp<cr>", { noremap = true, silent = true })
-- vim.keymap.set("n", "<C-w>l", ":<C-U>TmuxNavigateRight<cr>", { noremap = true, silent = true })

-- Buffers
vim.keymap.set('n','<Tab>',':bnext<CR>', { noremap = true, silent = true })
vim.keymap.set('n','<leader><S-c>',':Bdelete!<CR>', { noremap = true, silent = true })
vim.keymap.set("n", "<S-l>", ":bnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<S-h>", ":bprevious<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>c", ":Bdelete<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader><S-c>", ":Bdelete!<CR>", { noremap = true, silent = true })

-- Swap mark keys
vim.keymap.set('n','`','\'', { noremap = true, silent = true })
vim.keymap.set('n','\'','`', { noremap = true, silent = true })

-- Terminal --
-- vim.keymap.set("n", "<C-\\>", ":ToggleTerm size=80 direction=vertical<CR>", { noremap = true, silent = true })
-- vim.keymap.set("n", "<leader>v", "mt:w<BAR>:TermExec cmd=\"!!\"<CR><BAR>i<CR><C-\\><C-n><c-w><c-p>`t", { noremap = true, silent = true })

-- Copy paste
vim.keymap.set('v','p','"_dP', { noremap = true, silent = true })
vim.keymap.set('','x','"_x', { noremap = true, silent = true })

-- Clear highlight
vim.keymap.set('n','<ESC>',':nohlsearch<CR>', { noremap = true, silent = true })

-- Select all
vim.keymap.set('n','<C-a>','gg0vG$', { noremap = true, silent = true }) -- TODO:don't add gg to jump list
vim.keymap.set('i','<C-a>','<Esc>gg0vG$', { noremap = true, silent = true })
--
-- Stay in indent mode
vim.keymap.set("n", "<", "<<", { noremap = true, silent = true })
vim.keymap.set("n", ">", ">>", { noremap = true, silent = true })
vim.keymap.set("v", "<", "<gv", { noremap = true, silent = true })
vim.keymap.set("v", ">", ">gv", { noremap = true, silent = true })

-- New blank file
vim.keymap.set('n','<Leader>n',':enew<CR>', { noremap = true, silent = true })

-- QuickFix list
vim.keymap.set('n','<F4>', ':call ToggleQuickFix()<cr>', { noremap = true, silent = true })
vim.keymap.set('n','<C-p>', [[empty(filter(getwininfo(), 'v:val.quickfix')) ? "<C-p>" : ":cprevious<CR>"]], { noremap = true, silent = true, expr = true})
vim.keymap.set('n','<C-n>', [[empty(filter(getwininfo(), 'v:val.quickfix')) ? "<C-n>" : ":cnext<CR>"]], { noremap = true, silent = true, expr = true})
vim.keymap.set('n','<CR>', [[&buftype ==# 'quickfix' ? "\<CR>" : ':silent! norm!za<CR>']], { noremap = true, silent = true, expr = true})
vim.keymap.set('n','<C-o>', [[&buftype ==# 'quickfix' ? ":echo 'o'<CR>" : "<C-o>"]], { noremap = true, silent = true, expr = true})
vim.keymap.set('n','<C-i>', [[&buftype ==# 'quickfix' ? ":echo 'i'<CR>" : "<C-i>"]], { noremap = true, silent = true, expr = true})

-- Location list
vim.keymap.set('n','<F5>', ':silent! call ToggleLocationList()<cr>', { noremap = true, silent = true })
vim.keymap.set('n','<C-M-p>', [[empty(filter(getwininfo(), 'v:val.loclist')) ? "<C-M-p>" : ":lprevious<CR>"]], { noremap = true, silent = true, expr = true})
vim.keymap.set('n','<C-M-n>', [[empty(filter(getwininfo(), 'v:val.loclist')) ? "<C-M-n>" : ":lnext<CR>"]], { noremap = true, silent = true, expr = true})

-- Search ---
-- send // to quickfix locally
vim.keymap.set('n','<C-q>', [[:silent vimgrep //j %<CR>]], { noremap = true, silent = true })
-- send // to quickfix globally
vim.keymap.set('n','<leader><C-q>', [[:silent exe "grep "substitute(@/,'^\\V','','')<CR>]], { noremap = true, silent = true })
-- local search for word under cursor and send to quickfix
vim.keymap.set('n','<leader>/', [[/\V<C-r>=expand("<cword>")<CR><CR>]], { noremap = true, silent = true })
-- global search for word under cursor and send to quickfix
vim.keymap.set('n','<leader><leader>/', [[/\V<C-r>=expand("<cword>")<CR><CR>:silent exe "grep "substitute(@/,'^\\V','','')<CR>]], { noremap = true, silent = true })
-- global search for functions
vim.keymap.set('n','<leader>sf', [[/<CR>:silent exe "grep "substitute(@/,'^\\V','','')<CR>]], { noremap = true, silent = true })

-- local search for visual selection
vim.keymap.set('v','/','"hy/\\V<C-r>h<CR><S-n>', { noremap = true, silent = true })
-- local search for visual selection and send to quickfix
vim.keymap.set('v','<leader>/', [["hy/<C-r>h<CR>:silent vimgrep //j %<CR>]], { noremap = true, silent = true })
-- global search for visual selection and send to quickfix
vim.keymap.set('v','<leader><leader>/', [["hy/<C-r>h<CR>:silent exe "grep "shellescape(substitute(@/,'[()\]\[]','\\&','g'))<CR>]], { noremap = true, silent = true })

-- Search/Replace ---
-- start local whole file substitution
vim.keymap.set('n','<leader>;', [[:%s///gc<Left><Left><Left><Left>]], { noremap = true })
-- start local substitution within visual selection
vim.keymap.set('v','<leader>;', [[:s///gc<Left><Left><Left><Left>]], { noremap = true })
-- local search/replace word under cursor
vim.keymap.set('n','<leader>h', [[/\V<C-r>=expand("<cword>")<CR><CR>:%s/\<<C-r>=expand("<cword>")<CR>\>/<C-r>=expand("<cword>")<CR>/gc<Left><Left><Left>]], { noremap = true })
-- local search/replace visual selection
vim.keymap.set('v','<leader>h', [["hy/\V<C-r>h<CR>:%s/<C-r>h//gc<Left><Left><Left>]], { noremap = true })
-- global search/replace word under cursor
vim.keymap.set('v','<leader><leader>h', [["hy/<C-r>h<CR>:silent exe "grep "shellescape(substitute(@/,'[()\]\[{}]','\\&','g'))<CR>:cdo s/<C-r>h//gc<Left><Left><Left>]], { noremap = true })

--- Formatting ---
-- format all
vim.keymap.set('n','=a','gg0vG$==', { noremap = true, silent = true })

-- set indent
vim.keymap.set('n','=2',':set tabstop=2 shiftwidth=2<CR>', { noremap = true, silent = true })
vim.keymap.set('n','=4',':set tabstop=4 shiftwidth=4<CR>', { noremap = true, silent = true })

-- csv
vim.keymap.set('n','=ra',':RainbowAlign<CR>', { noremap = true, silent = true })
vim.keymap.set('n','=rs',':RainbowShrink<CR>', { noremap = true, silent = true })
vim.keymap.set('n','=rd',':RainbowDelim<CR>', { noremap = true, silent = true })
vim.keymap.set('n','=rn',':RainbowNoDelim<CR>', { noremap = true, silent = true })

-- json
vim.keymap.set('n','=j',':set filetype=json<CR>:%!jq .<CR>:set foldmethod=syntax<CR>zR', { noremap = true, silent = true })

-- xml
-- vim.keymap.set('n','=x', ':set filetype=xml<CR>:1s/<?xml .*?>//e<CR>:silent %!xmllint --encode UTF-8 --format -<CR>:1d<CR><ESC>', { noremap = true, silent = true })
vim.keymap.set('n','=x', ':set filetype=xml<CR>:%s/></>\r</g<CR>==', { noremap = true, silent = true })

-- allow space leader
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

-- Set lualine as statusline
-- See `:help lualine.txt`
require('lualine').setup {
  options = {
    icons_enabled = false,
    theme = 'auto',
    component_separators = '|',
    section_separators = '',
  },
}

-- Enable Comment.nvim
require('Comment').setup()

-- Enable `lukas-reineke/indent-blankline.nvim`
-- See `:help indent_blankline.txt`
require('indent_blankline').setup {
  char = '┊',
  show_current_context = true,
  show_trailing_blankline_indent = false,
}
-- vim.api.nvim_set_hl(0, "IndentBlankLineChar", { cterm='none', guifg='#5c6370' })
vim.cmd([[highlight IndentBlankLineChar cterm=nocombine gui=nocombine guifg=#444455]])

-- Gitsigns
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

-- [[ Configure Telescope ]]
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

-- [[ Configure Treesitter ]]
-- See `:help nvim-treesitter`
require('nvim-treesitter.configs').setup {
  -- Add languages to be installed here that you want installed for treesitter
  ensure_installed = { 'c', 'cpp', 'go', 'lua', 'python', 'rust', 'typescript', 'help' },

  highlight = { enable = true },
  indent = { enable = true, disable = { 'python' } },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = '<c-space>',
      node_incremental = '<c-space>',
      scope_incremental = '<c-s>',
      node_decremental = '<c-backspace>',
    },
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ['aa'] = '@parameter.outer',
        ['ia'] = '@parameter.inner',
        ['af'] = '@function.outer',
        ['if'] = '@function.inner',
        ['ac'] = '@class.outer',
        ['ic'] = '@class.inner',
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        [']m'] = '@function.outer',
        [']]'] = '@class.outer',
      },
      goto_next_end = {
        [']M'] = '@function.outer',
        [']['] = '@class.outer',
      },
      goto_previous_start = {
        ['[m'] = '@function.outer',
        ['[['] = '@class.outer',
      },
      goto_previous_end = {
        ['[M'] = '@function.outer',
        ['[]'] = '@class.outer',
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ['<leader>a'] = '@parameter.inner',
      },
      swap_previous = {
        ['<leader>A'] = '@parameter.inner',
      },
    },
  },
}

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
-- vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
-- vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)

-- LSP settings.
--  This function gets run when an LSP connects to a particular buffer.
local on_attach = function(_, bufnr)
  -- NOTE: Remember that lua is a real programming language, and as such it is possible
  -- to define small helper and utility functions so you don't have to repeat yourself
  -- many times.
  --
  -- In this case, we create a function that lets us more easily define mappings specific
  -- for LSP related items. It sets the mode, buffer and description for us each time.
  local nmap = function(keys, func, desc)
    if desc then
      desc = 'LSP: ' .. desc
    end

    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
  end

  nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
  nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

  nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
  nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
  nmap('gI', vim.lsp.buf.implementation, '[G]oto [I]mplementation')
  nmap('<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition')
  nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
  nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

  -- See `:help K` for why this keymap
  nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
  -- nmap('<S-C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

  -- Lesser used LSP functionality
  nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
  nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
  nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
  nmap('<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, '[W]orkspace [L]ist Folders')

  -- Create a command `:Format` local to the LSP buffer
  vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
    vim.lsp.buf.format()
  end, { desc = 'Format current buffer with LSP' })
end

-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
local servers = {
  -- clangd = {},
  -- gopls = {},
  -- pyright = {},
  -- rust_analyzer = {},
  -- tsserver = {},

  sumneko_lua = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
}

-- Setup neovim lua configuration
require('neodev').setup()
--
-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Setup mason so it can manage external tooling
require('mason').setup()

-- Ensure the servers above are installed
local mason_lspconfig = require 'mason-lspconfig'

mason_lspconfig.setup {
  ensure_installed = vim.tbl_keys(servers),
}

mason_lspconfig.setup_handlers {
  function(server_name)
    require('lspconfig')[server_name].setup {
      capabilities = capabilities,
      on_attach = on_attach,
      settings = servers[server_name],
    }
  end,
}

-- Turn on lsp status information
-- require('fidget').setup()

-- nvim-cmp setup
local cmp = require 'cmp'
local luasnip = require 'luasnip'

cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert {
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = "buffer" },
    { name = "path" },
  },
}

cmp.setup.cmdline(':', {
  sources = {
    { name = "luasnip" },
    { name = 'cmdline', keyword_pattern=[=[[^[:blank:]\!]*]=]},
  }
})

cmp.setup.cmdline('/', {
  sources = {
    { name = 'buffer' }
  }
})

require("nvim-tree").setup()

local status_ok, impatient = pcall(require, "impatient")
if not status_ok then
  return
end

impatient.enable_profile()
-- vim: ts=2 sts=2 sw=2 et

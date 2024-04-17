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



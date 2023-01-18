-- See `:help vim.keymap.set()`

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

-- Buffers
vim.keymap.set('n','<Tab>',':bnext<CR>', { noremap = true, silent = true })
vim.keymap.set('n','<leader><S-c>',':Bdelete!<CR>', { noremap = true, silent = true })
vim.keymap.set("n", "<S-l>", ":bnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<S-h>", ":bprevious<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>c", ":Bdelete<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader><S-c>", ":Bdelete!<CR>", { noremap = true, silent = true })

-- Swap mark keys
-- vim.keymap.set('n','`','\'', { noremap = true, silent = true })
-- vim.keymap.set('n','\'','`', { noremap = true, silent = true })

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

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
-- vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
-- vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)

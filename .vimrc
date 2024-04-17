set nocompatible
set clipboard=unnamed
set encoding=utf-8
set autoread " Read file when modified outside Vim
set visualbell
set t_vb=
set mouse=a
set ttimeoutlen=2
set noswapfile
set backupdir=/tmp//
set undodir=/tmp//
set backup
set undofile

set backspace=indent,eol,start " Allow backspacing over everything in INSERT mode
set ruler
set showcmd
set incsearch
set hlsearch
set ignorecase
set smartcase
set showmatch
set cursorline
set splitright splitbelow
set hidden
set laststatus=1

set nowrap
set textwidth=0
set wrapmargin=0
set autoindent
set smartindent
set tabstop=2
set shiftwidth=0 " zero will always match tabstop
set expandtab
" set smarttab

" set completeopt=longest,menuone
set omnifunc=syntaxcomplete#Complete
set wildmenu
set wildmode=list:full
" set wildmode=longest,list,full
set wildcharm=<Tab>	" Needed to open the wildmenu from shortcuts
set wildignore=*.swp,*.bak,*.pyc,*.class,*.o

set termguicolors
set guifont=Monaco:h14
set guioptions-=T
set guioptions-=r
set guioptions-=L
" Disable 'command' and 'option' navigation bindings
if has("gui_macvim")
    let macvim_skip_cmd_opt_movement = 1
endif

let g:netrw_liststyle=3		" 0=thin; 1=long; 2=wide; 3=tree
let g:netrw_banner=0

au! filetype netrw nnoremap <buffer> <C-l> <C-W>l

noremap ; :
noremap : ;
nnoremap <silent> <ESC> :noh<CR>
vnoremap p "0p
vnoremap P "0P "
nnoremap <silent> <TAB> :bnext<CR>
nnoremap <silent> <S-TAB> :bprev<CR>
nnoremap <expr> j v:count == 0 ? 'gj' : 'j' " Remap for dealing with word wrap
nnoremap <expr> k v:count == 0 ? 'gk' : 'k' "

inoremap jj <ESC>
inoremap kk <ESC>
inoremap hhh <ESC>
inoremap lll <ESC>
nmap Y y$

" xnoremap <expr> v (mode() ==# 'v' ? 'V' : mode() ==# 'V' ? "\<C-V>" : 'v')

" Comments
au! bufenter * 
            \   if &commentstring != ""
            \ |   let @c=substitute(split(&commentstring, '%s')[0], '\s*', '', 'g')
            \ |   nnoremap <buffer> <silent> gcc mm:keeppattern s/\(^\s*\)/\1<c-r>c /<cr>`m<RIGHT>
            \ |   nnoremap <buffer> <silent> gu mm:silent! keeppattern s/\(^\s*\)<c-r>c\s*/\1/<cr>`m<LEFT><LEFT><LEFT>
            \ |   vnoremap <buffer> <silent> gc mm:keeppattern s/\(^\s*\)/\1<c-r>c /<cr>`m<RIGHT>
            \ |   vnoremap <buffer> <silent> gu mm:silent! keeppattern s/\(^\s*\)<C-R>c\s*/\1/<CR>`m<LEFT><LEFT><LEFT>
            \ | else 
            \ |   let @c="" 
            \ | endif


nnoremap <silent> ∆ mm:m .+1<CR>==`m
nnoremap <silent> ˚ mm:m .-2<CR>==`m
inoremap <silent> ∆ <Esc>:m .+1<CR>==gi
inoremap <silent> ˚ <Esc>:m .-2<CR>==gi
vnoremap <silent> ∆ :m '>+1<CR>gv=gv
vnoremap <silent> ˚ :m '<-2<CR>gv=gv

nnoremap <silent> <C-h> :wincmd h<CR>
nnoremap <silent> <C-j> :wincmd j<CR>
nnoremap <silent> <C-k> :wincmd k<CR>
nnoremap <silent> <C-l> :wincmd l<CR>

nnoremap =2 mm:set tabstop=2<CR>ggvG==<Esc>`m
nnoremap =4 mm:set tabstop=4<CR>ggvG==<Esc>`m

tnoremap <Esc> <C-\><C-n>

nnoremap <silent> < <<
nnoremap <silent> > >>
vnoremap <silent> < <gv
vnoremap <silent> > >gv

nnoremap <silent> <S-q> :call ToggleQuickFix()<CR><C-w><C-p>
nnoremap <silent> <expr> <C-p> empty(filter(getwininfo(), 'v:val.quickfix')) ? "<C-p>" : ":cprevious<CR>"
nnoremap <silent> <expr> <C-n> empty(filter(getwininfo(), 'v:val.quickfix')) ? "<C-n>" : ":cnext<CR>"
nnoremap <expr> <CR> &buftype ==# 'quickfix' ? "\<CR>" : ':silent! norm!za<CR>'
nnoremap <silent> <C-q> :silent vimgrep //j %<CR>

" local search/replace word under cursor
nnoremap <S-r> /\V<C-r>=expand("<cword>")<CR><CR>:%s/\<<C-r>=expand("<cword>")<CR>\>/<C-r>=expand("<cword>")<CR>/gc<Left><Left><Left>
" local search/replace visual selection
vnoremap <S-r> "hy/\V<C-r>h<CR>:%s/<C-r>h//gc<Left><Left><Left>

let mapleader = " "
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
" nnoremap <leader>b :buffers<CR>
nnoremap <leader>bb :buffer <TAB>
nnoremap <leader>bs :w<CR>
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprev<CR>
nnoremap <leader>bN :new<CR>
nnoremap <leader>bk :bdelete<CR>
nnoremap <leader><TAB> :b#<CR>
nnoremap <leader>d :bprevious<CR>:bdelete #<CR> " Close buffer without affecting splits
nnoremap <leader>e :Lexplore<CR>:vertical resize 40<CR>
nnoremap <expr> <leader>n (&number == 1 ? ':set nonumber<CR>' : ':set number<CR>')
nnoremap <leader>r mm:w<CR><BAR>:so $MYVIMRC<CR>:nohl<CR>:echo $MYVIMRC "sourced"<CR>`m
nnoremap <leader>v :e ~/.vimrc<CR>
nnoremap <leader>sc :colorscheme <TAB>
nnoremap <leader>J ddpkJ
nnoremap <leader>sk :%y \| :call term_sendkeys(6, @")<CR>

filetype plugin on
filetype indent plugin on
syntax enable
set highlight=M-
set fillchars+=vert:\ 
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"

colorscheme habamax
if g:colors_name=="habamax"
    hi CursorLine ctermbg=235 guibg=#272727
    hi StatusLineNC ctermbg=0 ctermfg=8 guibg=black guifg=#777777
    hi StatusLine ctermbg=0 ctermfg=247 guibg=black guifg=#999999
    hi VertSplit ctermbg=0 guibg=black
    hi CursorLineNr term=bold cterm=bold ctermfg=130 gui=bold guifg=#bb7911
endif

function! ToggleQuickFix()
    if empty(filter(getwininfo(), 'v:val.quickfix'))
        copen
    else
        cclose
    endif
endfunction


"  __ _(_)_ __  _ _ __ 
"  \ V / | '  \| '_/ _|
" (_)_/|_|_|_|_|_| \__|

" --- plugins --- {{{

" let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
" if empty(glob(data_dir . '/autoload/plug.vim'))
" silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
" autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
" endif

call plug#begin()

Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/goyo.vim'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-commentary'
Plug 'romainl/vim-cool'
Plug 'scrooloose/nerdtree'
Plug 'LunarWatcher/auto-pairs'
Plug 'xolox/vim-session'
Plug 'xolox/vim-misc'
" Plug 'Raimondi/delimitMate'
Plug 'airblade/vim-gitgutter'
Plug 'mechatroner/rainbow_csv'
Plug 'machakann/vim-highlightedyank'
Plug 'w0rp/ale'
" Dark Themes
Plug 'twerth/ir_black'
Plug 'romainl/Apprentice'
Plug 'joshdick/onedark.vim'
Plug 'ghifarit53/tokyonight-vim'
"Light Themes
Plug 'altercation/vim-colors-solarized'
Plug 'freeo/vim-kalisi'
Plug 'NLKNguyen/papercolor-theme'

call plug#end()

" }}}

" --- plugin options --- {{{

let g:highlightedyank_highlight_duration = 120
let g:highlightedyank_highlight_in_visual = 1

" let delimitMate_expand_cr = 1
" let delimitMate_jump_expansion = 1
" let delimitMate_expand_space = 1
" let delimitMate_balance_matchpairs = 1

let g:AutoPairsCompatibleMaps = 0
let g:AutoPairsCarefulStringExpansion = 1
" let g:AutoPairsCompleteOnlyOnSpace = 1

" augroup NERDTree
"   au!
"   au BufWinEnter * if bufname(bufnr()) =~ 'NERD' | hi Normal guibg=black | endif
" augroup END


" }}}

" --- options --- {{{

filetype plugin on
filetype indent plugin on
syntax enable

set modelines=5
set nocompatible
set clipboard=unnamed
set encoding=utf-8
set autoread " Read file when modified outside Vim
set visualbell
set t_vb=
set mouse=a
set ttimeout
set ttimeoutlen=2
set timeoutlen=1000
set noswapfile
set backupdir=/tmp//
set undodir=/tmp//
set viminfo+=n~/.vim/viminfo
set backup
set undofile
set backspace=indent,eol,start " Allow backspacing over everything in INSERT mode
set noruler
set noshowmode
set showcmd
set incsearch
set hlsearch
set ignorecase
set smartcase
" set showmatch
set cursorline
set splitright splitbelow
set hidden
set nowrap
set textwidth=0
set wrapmargin=0
set scrolloff=3
set autoindent
set smartindent
set tabstop=2
set shiftwidth=0 " zero will always match tabstop
set expandtab "need toggle
" set smarttab
set termguicolors
set formatoptions-=cr
set showtabline=1
set linebreak
"https://stackoverflow.com/questions/36950231/auto-wrap-lines-in-vim-without-inserting-newlines

set shortmess-=S

set wildmenu
set wildoptions=pum
set wildcharm=<Tab>	" Needed to open the wildmenu from shortcuts
set wildignore=*.swp,*.bak,*.pyc,*.class,*.o

set sessionoptions=folds,globals,localoptions,resize,terminal

if has("gui_running")

    " set guifont=MonacoNerdFontCompleteM-:h13
    set guifont=IosevkaNFM:h15
    if (&guifont =~ 'Iosevka')
        set columnspace=-1
    else
        set columnspace=0
    endif
    set guioptions-=T
    set guioptions-=r
    set guioptions-=L
    set guioptions+=k
    set guioptions-=e

endif

" Disable 'command' and 'option' navigation bindings
if has("gui_macvim")
    let macvim_skip_cmd_opt_movement = 1
endif

set highlight=M-
" set fillchars=vert:\ ,eob:~,lastline:@,fold:\ ,foldopen:⌵,foldclose:›,foldsep:\ 
set fillchars=vert:│,eob:~,lastline:@,fold:\ ,foldopen:⌵,foldclose:›,foldsep:\ 
" vert:│


let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"

" }}}

" --- keymaps --- {{{

let mapleader = " "

" t - toggle
nnoremap <expr> <Leader>tl (&number == 1 ? ':set nonumber<cr>' : ':set number<cr>')| " toggle linenumbers
" nnoremap <Leader>tt :call NextColor()<cr>| "toggle theme
nnoremap <Leader>tw :set wrap!<cr>| "toggle wrap
nnoremap <Leader>tf :set foldcolumn=2<cr>| " toggle spell
nnoremap <expr> <Leader>tf (&foldcolumn == 0 ? ':set foldcolumn=2' : ':set foldcolumn=0') . '<cr>'| " toggle tabs (2/4)
nnoremap <Leader>ts :set spell!<cr>| " toggle spell
nnoremap <Leader>tz :call ToggleMaximize()<cr>| "toggle maximize
nnoremap <expr> <Leader>tt 'mm' . (&tabstop == 2 ? ':set tabstop=4' : ':set tabstop=2') . '<cr>ggvG==<Esc>`mzz'| " toggle tabs (2/4)
" show invisible chars
" zen mode or something
" toggle tabs vs spaces
" toggle tabstop/shiftwidth 2,4

function! ToggleMaximize()
    let zoomedTab = get(g:, 'zoomedTab', 0)
    let sourceTab = get(g:, 'sourceTab', 0)
    if !zoomedTab
        let sourceTab = tabpagenr()
        exe 'tab split'
        let zoomedTab = tabpagenr()
    else
        exe 'tabnext ' . sourceTab
        exe 'tabclose ' . zoomedTab
        let zoomedTab = 0
    endif
    let g:zoomedTab = zoomedTab
    let g:sourceTab = sourceTab
endfunction

" g - git
" nnoremap <expr> <leader>gg (IsTrackedByYadm() ? ':tabedit<bar>lcd $HOME<bar>term ++curwin ++close yadm enter lazygit<CR>' : ':tab term ++close lazygit<CR>')
" nnoremap <leader>gg :call Lazygit()<cr>

" function! Lazygit()
"   tabedit

"   " if IsTrackedByYadm()
"     lcd $HOME
"     call termopen('lazygit', {'on_exit': {job_id, exit_status -> execute('tabclose')}})
"     " exe 'term ++curwin ++close yadm enter lazygit'
"   " else
"   "   exe 'term ++curwin ++close lazygit'
"   " endif
" endfunction

" " augroup lazygit
" "   au!
" "   au Bufdelete * if &buftype == 'terminal' && bufname(bufnr()) =~ 'lazygit' | echom "Lazygit" | endif
" " augroup END

" augroup lazygit
"     au!
"     au FileType * if bufname(bufnr()) =~ 'lazygit' | au BufEnter <buffer> tabclose | endif
" augroup END

" function! OpenLazyGit()
"   if IsTrackedByYadm()
"     tabedit
"     lcd $HOME
"     call term_start('yadm enter lazygit', {'curwin': 1, 'exit_cb': 'CloseTabOnExit'})
"   else
"     let curDir = getcwd()
"     tabedit
"     execute 'lcd'..curDir
"     call term_start('lazygit', {'curwin': 1, 'exit_cb': 'CloseTabOnExit'})
"   endif
" endfunction

" function! CloseTabOnExit(...)
"   execute 'tabclose'
" endfunction

" nnoremap <leader>gg :call OpenLazyGit()<CR>



" function! IsTrackedByYadm()
"     " Get the list of files from yadm
"     let l:cmd_output = system('yadm list -a')
"     if v:shell_error
"         echo "Failed to execute 'yadm list -a'"
"         return 0
"     endif
"     " Split the output into a list, removing empty lines
"     let l:dotfiles = filter(split(l:cmd_output, '\n'), '!empty(v:val)')
"     " Get the current buffer's file path relative to home directory
"     let l:current_file = expand('%:p')
"     let l:home_dir = expand('$HOME')
"     " Convert file path to be relative to home directory
"     if l:current_file =~ '^' . l:home_dir
"         let l:relative_path = strpart(l:current_file, len(l:home_dir) + 1)
"     else
"         return 0
"     endif
"     " Check if the relative path matches any file in the list
"     return index(l:dotfiles, l:relative_path) != -1 
" endfunction

" " Function to close the tab after lazygit exits
" function! OnLazygitExit(job_id, code, event)
"     " Close the buffer AND the tab
"     bdelete!
"     tabclose
" endfunction

" o - open
nnoremap <Leader>ot :vertical terminal ++kill=term ++close<cr><C-\><C-n>:setlocal nobuflisted winfixwidth<cr>i| " open terminal
nnoremap <Leader>oT :terminal ++kill=term ++close<cr><C-\><C-n>:resize 12<bar>setlocal nobuflisted winfixheight<cr>i| " open terminal

" b - buffer
nnoremap <leader>bs :w<cr>| " save buffer
nnoremap <leader>bn :bnext<cr>| " next buffer
nnoremap <leader>bp :bprev<cr>| " prev buffer
nnoremap <leader>bN :new<cr>| " new buffer
nnoremap <leader>bk :Bclose<cr>| " delete buffer
nnoremap <leader>bK :Bclose!<cr>| " wipeout buffer
nnoremap <leader>bd :bdelete<cr>| " close buffer
nnoremap <silent> <Leader>by mtgg0vG$y`t:delmarks t<cr>| "yank buffer
nnoremap <leader>bb :buffer <TAB>| " list buffers
" nnoremap <leader>bb :ls t<cr>:b
" bx popup buffer scratch
" see fzf

" c - code
nnoremap <silent> <Leader>b= mmggVG=`mzz:delmarks m<cr>| " format buffer
" jump to definition
" compile
" Recompile
" send to repl

" f - files
" see fzf

" s - search
" see fzf

" Misc
noremap ; :
noremap : ;
noremap , `
nnoremap <silent> <ESC> :call EscapeKey()<cr>
nnoremap <C-o> <C-o>zz
"nnoremap <C-p> " see quickfix mapping
nnoremap n nzz
nnoremap N Nzz
nnoremap -- :vsplit<cr>
nnoremap -_ :split<cr>
nnoremap -<BS> :close<cr>
nnoremap -= <C-w>=

" clipboard
" Prevent x and the delete key from overriding what's in the clipboard.
noremap x "_x
noremap X "_x
noremap <Del> "_x
" Prevent selecting and pasting from overwriting what you originally copied.
" xnoremap p pgvy
vnoremap p "0p
vnoremap P "0P "
" Keep cursor at the bottom of the visual selection after you yank it.
vmap y ygv<Esc>
nnoremap Y y$

noremap <silent> <TAB> %
noremap <silent> ` :bnext<cr>| " next buffer
noremap <silent> <Leader>` <C-^>| " jump last buffer

noremap <silent> \ :tabnext<cr>| " next tab
noremap <silent> \| :tabprev<cr>| " next tab
noremap <silent> <expr> <leader>\ exists('g:altTab') ? ':'..g:altTab..'tabnext<cr>' : ''| " next buffer
" noremap <silent> ~ :bprev<cr>| " next buffer
" noremap <silent> ` :tabnext<cr>| " next buffer
" nnoremap <silent> \ :bnext<cr>| " next buffer
" nnoremap <silent> \| :bprev<cr>| " prev buffer

nnoremap <leader><tab>1 :1tabnext<cr>
nnoremap <leader><tab>2 :2tabnext<cr>
nnoremap <leader><tab>3 :3tabnext<cr>
nnoremap <leader><tab>4 :4tabnext<cr>
nnoremap <leader><tab>5 :5tabnext<cr>
nnoremap <leader><tab>6 :6tabnext<cr>


" Remap for dealing with word wrap
nnoremap <expr> j v:count == 0 ? 'gj' : 'j'
nnoremap <expr> k v:count == 0 ? 'gk' : 'k'

inoremap jj <ESC>
inoremap kk <ESC>
inoremap hhh <ESC>
inoremap lll <ESC>

" Automatically fix the last misspelled word and jump back to where you were.
"   Taken from this talk: https://www.youtube.com/watch?v=lwD8G1P52Sk
" nnoremap <C-CR> sp :normal! mz[s1z=`z<cr>

xnoremap <expr> v (mode() ==# 'v' ? 'V' : mode() ==# 'V' ? "\<C-V>" : 'v')

" invert numbers and symbols, but move some around
noremap 1 0
noremap 2 ^
noremap 3 $
noremap 4 !
noremap 5 %
noremap 6 @
noremap 7 (
noremap 8 )
noremap 9 #
noremap 0 *

noremap ! 1
noremap @ 2
noremap # 3
noremap $ 4
noremap % 5
noremap ^ 6
noremap & 7
noremap * 8
noremap ( 9
noremap ) 0

nnoremap <silent> ∆ mm:m .+1<cr>==`m
nnoremap <silent> ˚ mm:m .-2<cr>==`m
inoremap <silent> ∆ <Esc>:m .+1<cr>==gi
inoremap <silent> ˚ <Esc>:m .-2<cr>==gi
vnoremap <silent> ∆ :m '>+1<cr>gv=gv
vnoremap <silent> ˚ :m '<-2<cr>gv=gv

nnoremap <silent> <C-h> <C-w>h
nnoremap <silent> <C-j> <C-w>j
nnoremap <silent> <C-k> <C-w>k
nnoremap <silent> <C-l> <C-w>l

" nnoremap <silent> <C--> "15<C-w><"| "Resize window left
" nnoremap <silent> <C-=> "15<C-w>>"| "Resize window right
" nnoremap <silent> <C-w>k "15<C-w>-"| "Resize window up
" nnoremap <silent> <C-w>l "15<C-w>+"| "Resize window down

nnoremap <silent> < <<
nnoremap <silent> > >>
vnoremap <silent> < <gv
vnoremap <silent> > >gv

nnoremap <leader>w :w<cr>| " save buffer
nnoremap <leader>qq :qa!<cr>| " quit vim!
" nnoremap <leader>e :Lexplore<cr>
nnoremap <leader>e :NERDTreeToggle<cr>| " toggle filetree
nnoremap <leader>r mm:w<cr>:source $MYVIMRC<cr>:nohl<cr>:echo ".vimrc reloaded"<cr>`m| " reload vim
nnoremap <leader>ov :tabnew ~/.vimrc<cr>tcd ~<cr>| " open vimrc
" nnoremap <leader>sc :colorscheme <TAB>
nnoremap <leader>J ddpkJ| " reverse J

" }}}

" --- tabline {{{

set tabline=%!MyTabLine()

function MyTabLine()
  let s = ''
  for i in range(tabpagenr('$'))
    " select the highlighting
    if i + 1 == tabpagenr()
      let s ..= '%#TabLineSel#'
    else
      let s ..= '%#TabLine#'
    endif
    " set the tab page number (for mouse clicks)
    let s ..= '%' .. (i + 1) .. 'T'
    " the label is made by MyTabLabel()
    let s ..= '   %{MyTabLabel(' .. (i + 1) .. ')}   '
  endfor
  " after the last tab fill with TabLineFill and reset tab page nr
  let s ..= '%#TabLineFill#%T'
  " right-align the label to close the current tab page
  if tabpagenr('$') > 1
    let s ..= '%=%#TabLine#%999X[ X ]'
  endif
  return s
endfunction

function MyTabLabel(n)
  " Check for a custom label in the tab-scoped variable
  let custom_label = gettabvar(a:n, 'custom_tab_label', '')
  if custom_label != ''
    return custom_label
  endif
  " Default label if no custom label is set
  let buflist = tabpagebuflist(a:n)
  let winnr = tabpagewinnr(a:n)
  let bufname = bufname(buflist[winnr - 1])
  " Abbreviate folder names and truncate filename in the middle
  if bufname != ''
    let parts = split(bufname, '/')
    let abbrev_parts = map(parts[:-2], 'v:val[0]')
    let filename = parts[-1]
    if strlen(filename) > 40 
      let mid = len(filename) / 2
      let filename = filename[:4] .. '...' .. filename[-24:]
    endif
    return join(abbrev_parts, '') ? join(abbrev_parts, '/') .. '/' .. filename : filename
  endif
  return '[No Name]'
endfunction

" }}}

" --- abbreviations --- {{{

cnoreabbrev cd tcd
cnoreabbrev pwd verbose pwd

" }}}

" --- session management --- {{{

let g:session_autosave = 'no'
let g:session_autosave_periodic = 2
let g:session_autosave_silent = 1

function! NewSession(session_name)
  if a:session_name != ''
    for t in range(1,tabpagenr('$'))
      if gettabvar(t, 'session_name') == a:session_name
        execute t .. 'tabnext'
        return
      endif
    endfor
    if bufname(bufnr()) != ""
      tabnew
    endif
    execute "OpenTabSession " .. a:session_name
    let session_name = a:session_name
  else
    if bufname(bufnr()) != ""
      tabnew
    endif
    execute "OpenTabSession"
    let session_full_path = gettabvar(0, 'this_session')
    let session_file_name = split(session_full_path, '/')[-1]
    let session_name = fnamemodify(session_file_name, ":r")
  endif
  execute 'tcd' fnameescape(expand('%:p:h'))
  call SetTitleStringToPwd()
  call settabvar(tabpagenr(), 'session_name', session_name)
  call SetTabLabel("~ "..session_name.." ~")
endfunction

nnoremap gso :Sessions<cr>

function! CloseThisSession()
  execute "CloseTabSession"
  tabclose
endfunction

nnoremap gsc :call CloseThisSession()<cr>

nnoremap gss :SaveTabSession<cr>

command! Sessions call fzf#run(fzf#wrap({
    \ 'source': 'find ~/.vim/sessions -type f -name "*.vim" | sed -e "s|^.*\/\(.*\)\.vim|\1|"',
    \ 'sink': {session_name -> NewSession(session_name)}
    \ }))

" augroup Sessions
"   au!
"   " au SessionLoadPost * let t:this_session = getcwd()
"   au SessionLoadPost * let t:session_name = getcwd()
" augroup END

" function! CloseSesh()
"   if gettabvar(0,'this_session') != ''
"     if exists('t:buffers')
"       let tabBuffers = tabpagebuflist()
"       let allTabBuffers = copy(t:buffers)
"       call extend(allTabBuffers, t:terminals)
"       call extend(allTabBuffers, tabBuffers)
"       let wipedOut = [] " to prevent dups
"       for b in allTabBuffers
"         if index(wipedOut, b) == -1
"           mksession!
"           execute("bdelete! ".. b)
"           call add(wipedOut, b)
"         endif
"       endfor
"     endif
"   endif
" endfunction

" function! AmInSessionTab()
  
" endfunction

" }}}

" --- tab management --- {{{

nnoremap <leader><tab>n :tabnew<cr>tcd ~<cr>
nnoremap <leader><tab>r :call SetTabLabel(input('Set Tab Label: ', gettabvar(tabpagenr(), 'custom_tab_label')))<cr>
nnoremap <leader><tab>k :tabclose<cr>

augroup TabJump
  au!
  au TabLeave * let g:altTab = tabpagenr()
augroup END

function! SetTabLabel(label)
  call settabvar(tabpagenr(), 'custom_tab_label', a:label)
  redrawtabline
endfunction

augroup TabBufferList
    autocmd!
    autocmd TerminalOpen,BufEnter,BufWinEnter * call AddBufferToTabBuffersList_SetBufferListed()
    autocmd bufdelete * call RemoveBufferFromTabBuffersList()
    " autocmd! TabEnter * if exists('t:buffers') | echo t:buffers | endif
augroup END

function! AddBufferToTabBuffersList_SetBufferListed()
  " This could be broken up into two functions
  " 1. add/remove bufnr to/from t:buffers
  " 2. set buffer as listed/unlisted
  if !exists('t:buffers')
    let t:buffers = []
  endif
  if index(t:buffers, bufnr('%')) == -1
    let t:buffers += [bufnr('%')]
  endif
  if &buftype != "" "remove special buffers
    let bufnr_to_remove = bufnr('%')
    let t:buffers = filter(t:buffers, 'v:val != bufnr_to_remove')
  endif
  for buf in range(1, bufnr('$'))
    if bufexists(buf)
      if index(t:buffers, buf) == -1
        call setbufvar(buf, '&buflisted', 0)
      else
        call setbufvar(buf, '&buflisted', 1)
      endif
    endif
  endfor
endfunction

function! RemoveBufferFromTabBuffersList()
  if exists('t:buffers')
    let l:currentBufNum = bufnr("%")
    let t:buffers = filter(t:buffers, 'v:val != l:currentBufNum')
  endif
endfunction

augroup Tabs
  autocmd!
  autocmd VimEnter * execute 'tcd' getcwd() | call SetTitleStringToPwd()
  autocmd TabNew,VimEnter * let t:isNewTab = 1
  autocmd TabEnter * call SetTitleStringToPwd()
  autocmd BufReadPost * if t:isNewTab == 1 | call SetIsNewTabFalseIfFirstBuffer() | endif
  " autocmd BufEnter * if exists('t:isNewTab') && t:isNewTab == 1 && expand('%:p') == '' | execute 'tcd' $HOME | call SetTitleStringToPwd() | endif
  autocmd BufNew * if t:isNewTab == 1 | clearjumps | endif
  " autocmd TabEnter * execute 'verbose pwd'
augroup END

function! SetIsNewTabFalseIfFirstBuffer()
  if expand('%:p') == ''
    execute 'tcd' $HOME
  else
    execute 'tcd' fnameescape(expand('%:p:h'))
  endif
  let t:isNewTab = 0
  redrawtabline
  call SetTitleStringToPwd()
endfunction

augroup TabTerminals
  autocmd!
  autocmd BufRead,BufWinLeave * call RemoveTermFromTabTermList()
  autocmd TerminalOpen * call AddTermToTabTermList()
augroup END

function! AddTermToTabTermList()
  if !exists('t:terminals')
    let t:terminals = []
  endif
  if index(t:terminals, bufnr('%')) == -1
    let t:terminals += [bufnr('%')]
  endif
endfunction

function! RemoveTermFromTabTermList()
    if &buftype == "terminal"
      let bufnr_to_remove = bufnr('%')
      let t:terminals = filter(t:terminals, 'v:val != bufnr_to_remove')
    endif
endfunction

function! SetTitleStringToPwd()
  let &titlestring = substitute(getcwd(),$HOME,'~','')
endfunction

" }}}

" --- functions --- {{{

function! Get_visual_selection()
    " Why is this not a built-in Vim script function?!
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction

function! EscapeKey()
    if v:hlsearch
        call feedkeys( ":nohlsearch\<cr>", "n")
        return
    endif
    for i in range(1, winnr('$'))
        let l:bnum = winbufnr(i)
        " if getbufvar(l:bnum, '&buftype') == 'help'
        " execute("bdelete " . l:bnum)
        " return
        " endif
        if getbufvar(l:bnum, '&buftype') == 'quickfix'
            cclose
            " execute ":normal! 10<C-e>"
            return
        endif
    endfor
endfunction


" function ToggleAllFolds()
" let position=line(".")
" normal! G
" execute "normal! " . (line("$")-2) . "k"
" execute "normal! " . ((line(".") == 1) ? "zR" : "zM")
" execute "normal! " . l:position . "gg"
" endfunction
" 

" function! SearchRoot()
" let l:scm_list = ['.root', '.svn', '.git']
" for l:item in l:scm_list
" let l:dirs = finddir(l:item, '.;', -1)
" if !empty(l:dirs)
" return fnamemodify(l:dirs[-1].'/../', ':p:h')
" endif
" endfor
" return getcwd()
" endfunction
" let g:root_dir = SearchRoot()
" au BufEnter * exe ':lcd '.g:root_dir


" Don't close window, when deleting a buffer
command! -bang Bclose call BufcloseCloseIt(<bang>0)
" command! Bclose call BufcloseCloseIt()
function! BufcloseCloseIt(wipeout)
    let l:currentBufNum = bufnr("%")
    let l:alternateBufNum = bufnr("#")
    if buflisted(l:alternateBufNum)
        buffer #
        echo "buffer #: switched to alternate buffer"
    else
        bnext
        echo "bnext: switched to next buffer"
    endif
    if bufnr("%") == l:currentBufNum
      if len(tabpagebuflist(0)) == 1 && tabpagenr('$') > 1
        tabclose
      else
        new
        echo "new: new buffer"
      endif
    endif
    if buflisted(l:currentBufNum)
      if a:wipeout
        execute("bwipeout ".l:currentBufNum)
        echo "bwipeout: buffer wiped out"
      else
        exCute("bdelete ".l:currentBufNum)
        echo "bdelete: buffer deleted"
      endif
    endif
endfunction

" function! CheckIfLastBufferInTab()

"   " let buflist = tabpagebuflist(a:n)
"   if len(tabpagebuflist(0)) == 1 && tabpagenr('$') > 1
"     echo "IS LAST BUFFER"
"   endif
" endfunction

"
" https://www.reddit.com/r/vim/comments/ohfulq/no_plugin_vim_setups/
"
" How to convert VIM into an IDE
" https://www.youtube.com/watch?v=Gs1VDYnS-Ac
"
" How to Do 90% of What Plugins Do (With Just Vim)
" https://www.youtube.com/watch?v=XA2WjJbmmoM
"
" " Recent files (MRU)
" nnoremap <leader>m :browse old<cr>
" " Search files by name
" nnoremap <leader>p :find **/**<left>
" " browse files from same dir as current file
" nnoremap <leader>e :e %:p:h<cr>
" " Faster vimgrep/grep via ripgrep
"
" Folder structure for vanilla vim
" .vim
" ├── after
" │   └── ftplugin
" │       ├── bash.vim
" │       ├── markdown.vim
" │       └── python.vim
" ├── syntax
" │   └── coffee.vim
" └── vimrc
"
" really nice minial vimrc with nice to haves
" https://github.com/romainl/minivimrc/blob/master/vimrc



" }}}

" --- autocommands --- {{{

" augroup vimrc-incsearch-highlight
" autocmd!
" autocmd CmdlineEnter /,\? :set hlsearch
" autocmd CmdlineLeave /,\? :set nohlsearch
" augroup END

" augroup autocd
"     " au VimEnter,BufEnter,BufRead * if &buftype ==# '' && expand('%:h') != '' | execute 'cd ' . expand('%:h') | endif
"     au VimEnter * if expand('%:h') != '' | execute 'cd ' . expand('%:h') | endif
" augroup END  

augroup filetypes
    au!
    au BufWinEnter * if &l:buftype ==# 'help' | nnoremap <buffer> q :bwipeout<cr> | endif
    " Make sure .aliases, .bash_aliases and similar files get syntax highlighting.
    au BufNewFile,BufRead *aliases* set ft=sh
    " Update a buffer's contents on focus if it changed outside of Vim.
    au FocusGained,BufEnter * :checktime
    " Ensure tabs don't get converted to spaces in Makefiles.
    " au FileType make setlocal noexpandtab
    " Automatically cd into dir of buffer
    " au BufEnter * if expand("%:p:h") !~ '^/tmp' | silent! lcd %:p:h | endif
    au FileType vim :iabbrev fun function ()<CR>endfunction<UP><LEFT><LEFT><LEFT>
    au BufNewFile,BufRead *.yaml setlocal winfixwidth
augroup END

" Only show the cursor line in the active buffer.
augroup CursorLine
    au!
    au VimEnter,WinEnter,BufWinEnter * setlocal cursorline
    au WinLeave * setlocal nocursorline
augroup END

augroup FastEscape
    au!
    au InsertEnter * set timeoutlen=150
    au InsertLeave * set timeoutlen=1000
augroup END

" }}}

" --- terminal --- {{{

" augroup term
" au!
" au BufWinEnter * if &l:buftype ==# 'terminal' | call SetQFMaps() | endif
" augroup END

" tnoremap <Esc> <C-\><C-n>
tnoremap <silent> <C-h> <C-w>h
tnoremap <silent> <C-j> <C-w>j
tnoremap <silent> <C-k> <C-w>k
tnoremap <silent> <C-l> <C-w>l
nnoremap <leader>x :SendToTerm<CR>| " SendToTerm
nnoremap <leader>X :SendToTerm| " SendToTerm new command

command! -complete=file -nargs=* SendToTerm call SendToTerm(<f-args>)
function! SendToTerm(...)
    write "save buffer 
    if a:0 > 0
        let t:termCommand = join(a:000, " ")
    endif
    if exists("t:termCommand")
        if !len(t:terminals)
            " execute "vertical terminal"
            execute "vertical terminal ++close ++kill=term"
            execute "setlocal nobuflisted winfixwidth"
        endif
        call term_sendkeys(t:terminals[0], t:termCommand )
        call term_sendkeys(t:terminals[0], "\<CR>" )
    else
        call feedkeys(":SendToTerm ", "nt")
    endif
endfunction

" }}}

" --- search/replace --- {{{

" function! ReplaceAcrossAllFiles(search, replace)
" `git ls-files`
" silent! execute "vimgrep /" . a:search . "/gj **/* | copen"
" silent! execute  "cfdo %s/" . a:search . "/" . a:replace . "/gc"
" silent! cfdo update
" endfunction

if executable("rg")
    set grepprg=rg\ --vimgrep\ --no-heading
    set grepformat=%f:%l:%c:%m,%f:%l:%m
endif

" better grep
" https://gist.github.com/romainl/56f0c28ef953ffc157f36cc495947ab3
function! Grep(...)
    return system(join([&grepprg] + [expandcmd(join(a:000, ' '))], ' '))
endfunction
command! -nargs=+ -complete=file_in_path -bar Grep  cgetexpr Grep(<f-args>)
command! -nargs=+ -complete=file_in_path -bar LGrep lgetexpr Grep(<f-args>)
augroup quickfix
    au!
    au QuickFixCmdPost cgetexpr cwindow
    au QuickFixCmdPost lgetexpr lwindow
augroup END
" cnoreabbrev <expr> grep (getcmdtype() ==# ':' && getcmdline() ==# 'grep') ? 'Grep' : 'grep'

" }}}

" --- colorscheme --- {{{

" colorscheme habamax

augroup highlights
    au!
    au Colorscheme * call CustomHighlights()
augroup END

function! CustomHighlights()

    " Spelling mistakes will be colored up red.
    hi SpellBad cterm=underline ctermfg=203 guifg=#ff5f5f
    hi SpellLocal cterm=underline ctermfg=203 guifg=#ff5f5f
    hi SpellRare cterm=underline ctermfg=203 guifg=#ff5f5f
    hi SpellCap cterm=underline ctermfg=203 guifg=#ff5f5f
    hi Folded guifg=darkyellow

    hi User1 guifg=green guibg=black
    " hi User2 ctermbg=0 ctermfg=247 guibg=black guifg=#999999

    let dark_themes = [ 'ayu', 'habamax', 'apprentice', 'onedark', 'ir_black', 'ir_dark', 'ir_blue', 'codedark', 'tokyonight', 'sorbet' ]
    " let dark_themes = [ 'habamax', 'apprentice', 'onedark', 'codedark', 'tokyonight', 'sorbet' ]
    let light_themes = [ 'pyte', 'solarized', 'solarized8_high', 'papercolor' ]

    if index(dark_themes, g:colors_name) != -1
        set background=dark

        " hi StatusLineNC guibg=#090914 guifg=#555555
        " hi StatusLine   guibg=#090914 guifg=#999999

        " Black and Yellow
        hi StatusLine       guibg=#1d1d12 guifg=#bbbbbb
        hi StatusLineNC     guibg=#15152f guifg=#555555
        hi StatusLineTerm   guibg=#0a0a08 guifg=#0a0a08
        hi StatusLineTermNC guibg=#0a0a08 guifg=#0a0a08
        hi VertSplit        guifg=#3a3a2a guibg=NONE gui=NONE
        hi Normal           guibg=#0a0a00
        hi Terminal         guibg=#000a0a
        hi Comment          guifg=#505060
        hi LineNr           guifg=#404050
        hi CursorLineNr     guifg=#8a8a5a gui=bold
        " hi CursorLine       guibg=#15152f
        " hi CursorLine       guibg=#230808
        hi CursorLine       guibg=#191919

        " hi TabLineFill      guibg=#080808 gui=none
        hi TabLineFill      guibg=#15152f gui=none

        " hi TabLine          guibg=#1d1d12 guifg=#888888
        hi TabLine          guibg=#15152f guifg=#888888
        " hi TabLineSel       guibg=#303020 guifg=#98c379
        hi TabLineSel       guibg=#35354f guifg=lightcyan

        " hi StatusLineNC guibg=#202030 guifg=#555555 "gui=underline
        " hi StatusLine   guibg=#202030 guifg=#bbbbbb "gui=underline
        " hi VertSplit    guifg=#202030 guibg=NONE gui=reverse
        " hi VertSplit    guifg=#303040 guibg=NONE gui=NONE
        " hi VertSplit guibg=bl1a1f30ack
        " hi CursorLineNr term=bold cterm=bold ctermfg=130 gui=bold guifg=#bb7911
        hi QuickFixLine guibg=#444444 guifg=NONE
        " hi Search guibg=#5f875f
        hi Search guibg=#aa88cc
        hi CurSearch guibg=#ffaf5f
        " hi Normal guibg=#030404 guifg=#cccccc
        " hi Normal guibg=#050508 guifg=#cccccc
        " hi Normal guibg=#0a0c17 guifg=#cccccc
        " hi Normal guibg=#0e0e0e guifg=#cccccc
        " hi Normal guibg=#000a12 guifg=#cccccc
        " hi Normal guibg=#131523 guifg=#cccccc
        " hi Normal guibg=#111424

        " hi TabLineFill guibg=#090914 gui=none
        " hi TabLine guibg=#090914 guifg=darkgreen
        " hi TabLineSel guibg=#212434 guifg=green
        " hi Terminal guibg=#0c0f17
        " hi Terminal guibg=#0a1020
        " hi Terminal guibg=#090914
        " hi StatusLineTerm guibg=#0c0f17
        " hi StatusLineTerm guibg=#090914
        " hi VertSplit guibg=#090914
    elseif index(light_themes, g:colors_name) != -1
        set background=light
        colorscheme=g:colors_name
        echo "light theme"
    endif

    " if g:colors_name=~"ir_"
    "     hi CursorLine ctermbg=235 guibg=#212434
    "     hi StatusLineNC ctermbg=0 ctermfg=8 guibg=black guifg=#555555
    "     hi StatusLine ctermbg=0 ctermfg=247 guibg=black guifg=#999999
    "     hi VertSplit ctermbg=0 guibg=black
    "     hi CursorLineNr term=bold cterm=bold ctermfg=130 gui=bold guifg=#bb7911
    "     hi QuickFixLine guibg=#444444 guifg=NONE
    "     " hi Search guibg=#5f875f
    "     hi Search guibg=#aa88cc
    "     hi CurSearch guibg=#ffaf5f
    "     " hi Normal guibg=#141928
    "     " hi Normal guibg=#131523
    "     " hi Normal guibg=#111424
    "     hi TabLineFill guibg=#010414 gui=none
    "     hi TabLine guibg=#010414 guifg=darkgreen
    "     hi TabLineSel guibg=#212434 guifg=green
    "     " hi Comment guifg=#555570
    " endif
endfunction

function! ViewHighlights()
  for id in synstack(line("."), col("."))
    echo synIDattr(id, "name")
  endfor
endfunction

function! NextColor()
    let l:mycolors = ['habamax', 'darkblue', 'delek', 'retrobox', 'sorbet' ]  " colorscheme names that we use to set color
    let current = 0
    if exists('g:colors_name')
        let current = index(l:mycolors, g:colors_name)
    endif
    if (current < len(l:mycolors) - 1)
        let current += 1
    else
        let current = 0
    endif
    execute 'colorscheme '.l:mycolors[current]
    redraw
    if g:colors_name=="habamax"
        hi CursorLine ctermbg=235 guibg=#272727
        hi StatusLineNC ctermbg=0 ctermfg=8 guibg=black guifg=#555555
        hi StatusLine ctermbg=0 ctermfg=247 guibg=black guifg=#999999
        hi VertSplit ctermbg=0 guibg=black
        hi CursorLineNr term=bold cterm=bold ctermfg=130 gui=bold guifg=#bb7911
    endif
    echo g:colors_name
endfunction

" magenta
" brown
" cyan
" yellow
" orange
" green

" colorscheme habamax
colorscheme onedark

" }}}

" --- search / replace / quickfix --- {{{

function! HighlightQuickfixEntry() abort
    " Get the current position (filename, line, column)
    let curfile = expand('%:p') " Full path of the current file
    let curline = line('.')
    let curcol = col('.')
    " Open the quickfix list in a split without moving the cursor
    let winview = winsaveview()
    " call feedkeys("11\<C-e>")
    silent copen
    " Find the matching entry in the quickfix list
    let qfl = getqflist()
    let match_idx = -1
    for idx in range(len(qfl))
        let entry = qfl[idx]
        let fname = bufname(entry.bufnr)
        if fnamemodify(fname, ':p') == curfile && entry.lnum == curline
            let match_idx = idx
            break
        endif
    endfor
    " Highlight the matching entry in the quickfix window
    if match_idx != -1
        call setpos('.', [bufnr(), match_idx+1, 0])
        execute "normal! \<cr>"
    endif
    " Restore cursor to original position
    call winrestview(winview)
endfunction

" https://vim.fandom.com/wiki/Search_and_replace_in_multiple_buffers
function! QuickFixSearch(isMultiFile, mode)
    let l:target = getcwd() == $HOME || !a:isMultiFile ? "%" : "**/*"
    if a:mode == "n"
      " call setreg("h", expand('<cword>'))
      let search = getreg("/")
    elseif a:mode == 'v'
      let search = getreg("h")
    endif
    silent execute "silent vimgrep! /\\C" . escape(search, '.*$^~[') . "/jg " . l:target
    call HighlightQuickfixEntry()
endfunction

nnoremap <silent> <C-q> :call QuickFixSearch(0, "n")<CR>
nnoremap <silent> <leader><C-q> :call QuickFixSearch(1, "n")<CR>
vnoremap <silent> <C-q> "hy:call QuickFixSearch(0, "v")<CR>
vnoremap <silent> <leader><C-q> "hy:call QuickFixSearch(1, "v")<CR>

function! QuickFixReplace(replacement)
    if empty(a:replacement)
        echo "--no replacement entered--"
    else
        let search = getreg("h")
        execute 'cdo s/' . escape(search, '.*$^~[') . '/' . a:replacement . '/cIge'
        cfdo update
        cclose
    endif
endfunction

nnoremap <Leader>cr :call QuickFixReplace(input('(QuickFix) Replace "'.getreg("h").'" : '))<CR>| " search & replace

function! QuickFixSearchReplace(isMultiFile, mode, replacement)
    call QuickFixSearch(a:isMultiFile, a:mode)
    call QuickFixReplace(a:replacement)
endfunction

nnoremap <Leader>sr    :call QuickFixSearchReplace(0, "n", input('Search & Replace "'.expand('<cword>').'" : '))<CR>|             " search & replace
nnoremap <Leader>sR    :call QuickFixSearchReplace(1, "n", input('Multi-file Search & Replace "'.expand('<cword>').'" : '))<CR>|  "multi-file search & replace
vnoremap <Leader>sr "hy:call QuickFixSearchReplace(0, "v", input('Search & Replace "'.getreg("h").'" : '))<CR>|                   " search & replace
vnoremap <Leader>sR "hy:call QuickFixSearchReplace(1, "v", input('Multi-file Search & Replace "'.getreg("h").'" : '))<CR>|        " multi-file search & replace

" local search for visual selection
vnoremap <silent> / "hy/<C-r>h<CR><S-n>

nnoremap <C-i> <C-i>
nnoremap [q :colder<cr>:copen<cr>
nnoremap ]q :cnewer<cr>:copen<cr>

" local search/replace word under cursor
" - set mark; from line to bottom do cWord substitution | repeat from top to line
" nnoremap <S-r> :%s/\<<C-r><C-w>\>/<C-r><C-w>/gc<Left><Left><Left>
nnoremap <S-r> mm:,$s/\V\<<c-r><c-w>\>/<C-r><C-w>/gIc \| 1,''-&&<c-left><left><left><left><left><left><left><left>
" local search/replace visual selection
" - set mark; yank visual selection into h register; from line to bottom do cWord substitution | repeat from top to line
vnoremap <S-r> mm"hy/\V<C-r>h<CR><S-n>:,$s/<C-r>h/<C-r>h/gIc \| 1,''-&&<c-left><left><left><left><left><left><left><left>

nnoremap <silent> <Leader>cc :call ToggleQuickFix()<CR><C-w><C-p>| " toggle quickfix
nnoremap <silent> <expr> <C-p> empty(filter(getwininfo(), 'v:val.quickfix')) ? "<C-i>" : ":keepjumps cprevious<CR>zz"
nnoremap <silent> <expr> <C-n> empty(filter(getwininfo(), 'v:val.quickfix')) ? "<C-n>" : ":keepjumps cnext<CR>zz"
nnoremap <silent> <expr> <Leader>cp empty(filter(getwininfo(), 'v:val.quickfix')) ? "<nop>" : ":colder<CR>"| " pref qf
nnoremap <silent> <expr> <Leader>cn empty(filter(getwininfo(), 'v:val.quickfix')) ? "<nop>" : ":cnewer<CR>"| " next qf
nnoremap <silent> <expr> <CR> &buftype ==# 'quickfix' ? "\<CR>" : ':norm!za<CR>'
nnoremap <silent> <expr> <C-CR> &buftype ==# 'quickfix' ? "\<C-CR>" : ':norm!zMgg<CR>'

" Toggle quickfix window.
function! ToggleQuickFix()
    for i in range(1, winnr('$'))
        let bnum = winbufnr(i)
        if getbufvar(bnum, '&buftype') == 'quickfix'
            cclose
            return
        endif
    endfor
    copen
endfunction

augroup qf
    au!
    au BufWinEnter * if &l:buftype ==# 'quickfix' | call SetQFMaps() | endif
    au FileType qf call SetQFOptions()
    " quit Vim if the last window is a quickfix window
    " au qf BufEnter    <buffer> nested if get(g:, 'qf_auto_quit', 1) | if winnr('$') < 2 | q | endif | endif
augroup END

function SetQFMaps()
    nnoremap <buffer> q :cclose<CR>
    nnoremap <buffer> <leader>bk :cclose<CR>| "---
    nnoremap <buffer> <leader>bd :bd<CR>| "---
    nnoremap <buffer> \ <nop>
    nnoremap <buffer> <leader>bs <nop>
    nnoremap <buffer> <leader>bn <nop>
    nnoremap <buffer> <leader>bN <nop>
    nnoremap <buffer> <leader>bp <nop>
    nnoremap <buffer> <Leader>` <nop>
endfunction

function SetQFOptions()
    " open quickfix full width on the bottom
    if (getwininfo(win_getid())[0].loclist != 1) | wincmd J | endif
    set nobuflisted
    setlocal norelativenumber
    setlocal number
    set laststatus=0
    au WinClosed <buffer> set laststatus=2
endfunction

command! UpdateQF call setqflist(map(getqflist(), 'extend(v:val, {"text":get(getbufline(v:val.bufnr, v:val.lnum),0)})'))

" }}}

" --- QuickFixTextFunc --- {{{
set qftf=QuickFixTextFunc nowrap
"""| syn on
fu QuickFixTextFunc(info) abort
    if a:info.quickfix
        let qfl = getqflist(#{id: a:info.id, items: 0}).items
    else
        let qfl = getloclist(a:info.winid, #{id: a:info.id, items: 0}).items
    endif
    let l = []
    let max_fname_len = 0
    for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
        let e = qfl[idx]
        let fname = bufname(e.bufnr)->fnamemodify(':t')
        let max_fname_len = max([max_fname_len, strchars(fname, 1)])
    endfor
    for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
        let e = qfl[idx]
        let fname = bufname(e.bufnr)->fnamemodify(':t')
        let max_allowed_fname_len = 30 
        if max_fname_len <= max_allowed_fname_len
            let fname = printf('%'..max_fname_len..'s', fname)
        else
            let fname = printf('%-'..(max_allowed_fname_len-1)..'s', fname)..'…'
            " let fname = printf('%s-'..(max_allowed_fname_len-1), fname)..'…'
        endif
        let lnum = printf('%5d', e.lnum)
        call add(l, fname..'|'..lnum..'| '..e.text)
    endfor
    return l
endfu
" }}}

" --- completion --- {{{

set completeopt=menu,menuone,preview,noinsert
set omnifunc=syntaxcomplete#Complete " basic completion for programming languages (C-x C-O)
set infercase            " infer case sensitivity when doing keyword completion

" inoremap <silent> <expr> <CR> pumvisible() ? "\<C-Y>" : "<Esc>:call Prep()<CR>a"
inoremap <silent> <expr> <CR> pumvisible() ? "\<C-Y>" : "\<CR>"
inoremap <silent> <expr> <Tab> pumvisible() ? "\<C-Y>" : "\<Tab>"
inoremap <silent> <expr> <C-V> pumvisible() ? "\<C-X>\<C-V>" : "\<C-V>"
inoremap <silent> <expr> <C-O> pumvisible() ? "\<C-X>\<C-O>" : "\<C-O>"
inoremap <silent> <expr> <C-L> pumvisible() ? "\<C-X>\<C-L>" : "\<C-L>"
inoremap <silent> <expr> <C-F> pumvisible() ? "\<C-X>\<C-F>" : "\<C-F>"
inoremap <silent> <expr> <C-I> pumvisible() ? "\<C-X>\<C-I>" : "\<C-I>"


" Minimalist-AutoCompletePop-Plugin
fun! AutoComplete()
    if v:char =~ '\K'
                \ && getline('.')[col('.') - 4] !~ '\K'
                \ && getline('.')[col('.') - 3] =~ '\K'
                \ && getline('.')[col('.') - 2] =~ '\K' " last char
                \ && getline('.')[col('.') - 1] !~ '\K'

        " call feedkeys("\<C-x>\<C-o>", 'n')
        call feedkeys("\<C-N>", 'n')
    end 
endfun

augroup AC
    au!
    au InsertCharPre * silent! call AutoComplete()
augroup END


" }}}

" --- netrw --- {{{

let g:netrw_liststyle=3		" 0=thin; 1=long; 2=wide; 3=tree
let g:netrw_banner=0
" make netrw work like nerdtree
" let g:netrw_banner = 0
" let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 25

au! filetype netrw nnoremap <buffer> <C-l> <C-W>l

" }}}

" --- statusline --- {{{
set laststatus=2

augroup gitstatusline
    au!
    au BufEnter,FocusGained,BufWritePost *
                \ let b:in_git_repo = 
                \ system(printf("git -C %s rev-parse 2>/dev/null; echo $?", expand('%:p:h:S'))) == 0 
    " au BufEnter,FocusGained,BufWritePost *
    " \ let b:git_status = b:in_git_repo && substitute(
    " \ system(printf("cd %s && git status -s", expand('%:p:h:S'))),
    " \ "\n", " ", "g")
    au BufEnter,FocusGained,BufWritePost *
                \ let b:git_clean = b:in_git_repo && 
                \ system(printf("cd %s && git status --porcelain 2>/dev/null", expand('%:p:h:S'))) is# ''
augroup end

" let &statusline = '%{get(b:, "git_status", "")}'

" Heavily inspired by: https://github.com/junegunn/dotfiles/blob/master/vimrc
function! s:statusline_expr()
    let mode = " %#User1#%{&buftype != 'terminal' ? toupper(' '..mode()..' ') : ''}%* "
    let mod = "%{&modified && &buftype != 'terminal' ? '+' : ''}"
    let mol = "%{!&modifiable ? '[x] ' : ''}"
    let ro  = "%{&readonly ? 'Read Only ' : ''}"
    " let fug = "%{exists('g:loaded_fugitive') ? fugitive#statusline() : ''}"
    let git =       '%{get(b:, "in_git_repo", "") ? "git" : ""}'
    let git_clean = '%{get(b:, "in_git_repo", "") ? get(b:, "git_clean", "") ? "✔︎" : "" : ""}'
    let git_dirty = '%#WarningMsg#%{get(b:, "in_git_repo", "") ? get(b:, "git_clean", "") ? "" : "+" : ""}%*'
    " let git_status = '%{get(b:, "in_git_repo", "") ? get(b:, "git_status", "") : ""}   '
    let sep = ' %= '
    let ft  = "%{len(&filetype) ? &filetype.'    ' : ''}"
    let pos = ' %-12(%L:%l:%c%) '
    let pct = ' %P'
    return mode.' %f %< %#WarningMsg#'.mod.'%* '.mol.ro.sep.git.git_clean.git_dirty.'     '.ft.pos.'%*'.pct
endfunction

function! s:statusline_nc_expr()
    let mode = " %{mode()}%* "
    let mod = "%{&modified && &buftype != 'terminal' ? '+' : ''}"
    let mol = "%{!&modifiable ? '[x] ' : ''}"
    let ro  = "%{&readonly ? 'Read Only ' : ''}"
    let sep = ' %= '
    let ft  = "%{len(&filetype) ? &filetype.'  ' : ''}"
    return '    %f  '.mod.'%* '.mol.ro.sep.ft
endfunction

let &statusline = s:statusline_expr()

augroup statusline
    au!
    au WinEnter,BufEnter * let &l:statusline = s:statusline_expr()
    au WinLeave,BufLeave * let &l:statusline = s:statusline_nc_expr()
augroup end


function! InsertStatuslineColor(mode)
    if a:mode == 'i'
        hi User1 guifg=orange guibg=#202013 gui=bold,reverse
    elseif a:mode == 'r'
        hi User1 guifg=magenta guibg=#202013 gui=bold,reverse
    else
        hi User1 guifg=darkgreen guibg=#202013 gui=bold,reverse
    endif
endfunction

augroup ModeEvents
    au!
    au InsertEnter  *            call InsertStatuslineColor(v:insertmode)
    au InsertChange *            call InsertStatuslineColor(v:insertmode)
    au InsertLeave  *            hi User1 guifg=darkyellow   guibg=#1a1a00 gui=bold,reverse
    au Modechanged  [vV\x16]*:*  hi User1 guifg=darkyellow   guibg=#1a1a00 gui=bold,reverse " leave visual
    au ModeChanged  *:[vV\x16]*  hi User1 guifg=magenta      guibg=#1a1a00 gui=bold,reverse " enter visual
    au Modechanged  *c:*         hi User1 guifg=darkyellow   guibg=#1a1a00 gui=bold,reverse " leave command
    au Modechanged  *:c*         hi User1 guifg=brown        guibg=#1a1a00 gui=bold,reverse " enter command
    " au TextChanged,TextChangedI  User2 guifg=#bb7911
    " au BufWritePost *            hi User2 guifg=#999999
augroup END

" }}}

" --- Rainbow CSV --- {{{

function! ToggleRainbow()
    let b:rainbow_aligned = get(b:, 'rainbow_aligned', 0)
    if b:rainbow_aligned == 0
        execute "RainbowAlign"
        let b:rainbow_aligned = 1
    else
        execute "RainbowShrink"
        let b:rainbow_aligned = 0
    endif
endfunction

augroup RainbowMapping
    autocmd!
    autocmd FileType csv,tsv nnoremap <buffer> =r :call ToggleRainbow()<CR>
augroup END

" }}}

" --- fzf --- {{{

" https://www.reddit.com/r/vim/comments/cas2ic/how_to_ripgrep_from_project_root_with_fzfvim/

" An action can be a reference to a function that processes selected lines
function! s:build_quickfix_list(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val, "lnum": 1 }'))
  copen
  cc
endfunction

let g:fzf_action = {
      \ 'ctrl-q': function('s:build_quickfix_list'),
      \ 'ctrl-t': 'tab split',
      \ 'ctrl-x': 'split',
      \ 'ctrl-v': 'vsplit' }


set rtp^=/opt/homebrew/opt/fzf " If installed using Homebrew on Apple Silicon
set rtp^=~/.vim/bundle/fzf.vim " git clone git@github.com:junegunn/fzf.vim.git ~/.vim/bundle/fzf.vim
let g:fzf_vim = {}
" let g:fzf_vim.preview_window = ['right,50%,<100(up,40%)', 'ctrl-/']
" let g:fzf_vim.preview_window = ['down,50%', 'ctrl-/']
let g:fzf_layout = { 'down': '40%' }
let g:fzf_vim.grep_multi_line = 1
let g:fzf_vim.commands_expect = 'alt-enter,ctrl-x' " [Commands] --expect expression for directly executing the command

let $FZF_DEFAULT_COMMAND="rg --files --hidden -g '!Library/' -g '!Applications' -g '!Desktop' -g '!.git'"
"let g:fzf_vim = {}
"" [Buffers] Jump to the existing window if possible
"let g:fzf_vim.buffers_jump = 1

augroup fzf
    au!
    au FileType fzf tnoremap <buffer> <silent> <esc> <c-c>
    au FileType fzf set laststatus=0
                \| au BufLeave <buffer> set laststatus=2
augroup END

" g - git
nnoremap <silent> <leader>gs :Commits<CR>| " FZF Git Commits
nnoremap <silent> <leader>gb :BCommits<CR>| " FZF Git Commits Buffer
" b - buffer
nnoremap <silent> <leader>bb :Buffers<CR>| " FZF Buffers
nnoremap <silent> <leader>, :Buffers<CR>| " FZF Buffers
nnoremap <silent> <leader>/ :RG<CR>| " FZF Buffers
nnoremap <silent> <Leader>bl :Filetypes<CR>| " FZF Filetypes
" f - files
nnoremap <silent> <leader><leader> :Files<CR>| " FZF Files
nnoremap <silent> <leader>fF :Files<CR>| " FZF Files
nnoremap <silent> <expr> <leader>ff b:in_git_repo ? ":GFiles<CR>" : ":Files<CR>"| " FZF Git Files
nnoremap <silent> <leader>fr :History<CR>| " FZF Recent Files
nnoremap <leader>fR :Rename | " Rename File
" s - search
nnoremap <silent> <leader>sb :BLines<CR>| " FZF Search Buffer
nnoremap <silent> <leader>st :Colors<CR>| " FZF Themes
nnoremap <silent> <leader>sc :Commands<CR>| " FZF Commands
nnoremap <silent> <Leader>sf :RG<CR>| " FZF RG
nnoremap <silent> <leader>sh :Helptags<CR>| " FZF Helptags
nnoremap <silent> <leader>s; :History:<CR>| " FZF Command History
nnoremap <silent> <leader>s/ :History/<CR>| " FZF Search History
nnoremap <silent> <leader>sk :Maps<CR>| " FZF Keymaps
" Meta
nnoremap <silent> ≈ :Commands<CR>

" }}}

" --- Goyo --- {{{

let g:goyo_width='80%'
let g:goyo_height='90%'
" let g:goyo_linenr=0

function! s:goyo_enter()
    set noshowmode
    set noshowcmd
    set scrolloff=999
    let &fillchars ..= ',eob: '
endfunction

function! s:goyo_leave()
    set showmode
    set showcmd
    set scrolloff=3
    let &fillchars ..= ',eob:~'
endfunction

autocmd! User GoyoEnter nested call <SID>goyo_enter()
autocmd! User GoyoLeave nested call <SID>goyo_leave()
nnoremap <leader>tg :Goyo<cr>

" }}}

" --- comments --- {{{

" function! Comet()
" "echo mode()
" let l:line=getline('.')
" let l:comment = substitute(split(&commentstring, '%s')[0], '\s*', '', 'g')
" "let l:save = winsaveview()
" let save_pos = getpos('.')
" if l:line =~ '^\s*' . l:comment
" let l:spacesBeforeText = match(strpart(l:line, match(l:line, l:comment) + 1), '\S') + 1
" call setline(line('.'), substitute(l:line, '\(^\s*\)' . l:comment . '\s*', '\1', ''))
" let save_pos[2] -= l:spacesBeforeText
" call setpos('.', save_pos)
" else
" call setline(line('.'), substitute(l:line, '\(^\s*\)', '\1' . l:comment . ' ', ''))
" let save_pos[2] += 2
" call setpos('.', save_pos)
" endif
" "call winrestview(l:save)
" endfunction

" au! bufenter * 
" \   if &commentstring != ""
" \ |   let @c=substitute(split(&commentstring, '%s')[0], '\s*', '', 'g')
" \ |   nnoremap <buffer> <silent> gcc mm:keeppattern s/\(^\s*\)/\1<c-r>c /<CR>`m<RIGHT>
" \ |   nnoremap <buffer> <silent> gu mm:silent! keeppattern s/\(^\s*\)<c-r>c\s*/\1/<CR>`m<LEFT><LEFT><LEFT>
" \ |   vnoremap <buffer> <silent> gc mm:keeppattern s/\(^\s*\)/\1<c-r>c /<CR>`m<RIGHT>
" \ |   vnoremap <buffer> <silent> gu mm:silent! keeppattern s/\(^\s*\)<C-R>c\s*/\1/<CR>`m<LEFT><LEFT><LEFT>
" \ | else 
" \ |   let @c="" 
" \ | endif

" nnoremap gcc :call Comet()<CR>
" vnoremap gc :call Comet()<CR>

" }}}

" --- formatting --- {{{

function! FormatJson()
    set filetype=json
    " Use system() to run jq and capture the result or error
    let l:formatted = system('jq .', join(getline(1, '$'), "\n"))
    " Check if jq returned an error
    if v:shell_error != 0
        echo "-Error-: Failed to format JSON"
        return
    endif
    " Replace buffer content with the formatted JSON
    call setline(1, split(l:formatted, "\n"))
    set foldmethod=syntax
    normal! zR
endfunction

nnoremap =j :call FormatJson()<CR>

function! FormatXml()
    set filetype=xml
    " Use system() to run xmllint and capture the result or error
    let l:formatted = system('xmllint --format -', join(getline(1, '$'), "\n"))
    " Check if xmllint returned an error
    if v:shell_error != 0
        echo "-Error-: Failed to format XML"
        return
    endif
    " Replace buffer content with the formatted XML
    call setline(1, split(l:formatted, "\n"))
    " Restore syntax-based folding and open all folds
    set foldmethod=syntax
    normal! zR
    execute("g/<?xml/d")
endfunction

" Keymapping to call the FormatXml function
nnoremap =x :call FormatXml()<CR>

" }}}

" --- scratch buffer --- {{{
function! ScratchBuffer()
    let scratchBufferName = "__scratch__"
    let scr_bufnum = bufnr(scratchBufferName)
    if scr_bufnum == -1 " it does'nt exist
        exe "botright 15new | setlocal buflisted buftype=nofile bufhidden=hide noswapfile winfixheight | file " . scratchBufferName
        exe "startinsert"
    else " it does exist
        let scr_winnum = bufwinnr(scr_bufnum)
        if scr_winnum == -1 " it's hidden
            exe "14split +buffer" . scr_bufnum
        " exe "startinsert"
        else " it's visible
            if winnr() != scr_winnum " we're not already in it
                exe scr_winnum . "wincmd w"
                exe "startinsert"
            endif
        endif
    endif
endfunction

nnoremap <leader>os :call ScratchBuffer()<cr>
augroup scratch
    au!
    au BufNew,BufAdd,BufEnter __scratch__ nnoremap <buffer> q :q<cr>
augroup END

" }}}

" --- foldtext --- {{{

set foldtext=MyFoldText()

function MyFoldText()
  let line = getline(v:foldstart)
  let sub = substitute(line, '/\*\|\*/\|{{{\d\=', '', 'g') "}}}
  let comment = substitute(&commentstring, '%s', "", 'g')
  let sub = substitute(sub, '^'..comment, repeat(' ', len(comment)), 'g')
  return sub .. " ~"
endfunction

" hi Folded guibg=NONE guifg=#767390
hi Folded guibg=NONE guifg=cyan
hi FoldColumn guibg=NONE guifg=darkyellow

" }}}

" --- BONEYARD --- {{{


" nnoremap <leader>v :call SendRepeatLastCommandToTerm()<CR>
" function! SendRepeatLastCommandToTerm()
" if !len(term_list())
" execute "vertical terminal ++close"
" call term_sendkeys(term_list()[0], "ls" )
" call term_sendkeys(term_list()[0], "\<CR>" )
" else
" call term_sendkeys(term_list()[0], "!!" )
" call term_sendkeys(term_list()[0], "\<CR>" )
" call term_sendkeys(term_list()[0], "\<CR>" )
" endif
" endfunction

" command! -complete=file -nargs=* Boomirun call SendTermCommand('boo run '.<f-args>)

" function! ChangeLineNumbering()
"   if &number == 0
"     " if &number == 0 && &relativenumber == 0
"     setlocal number!
"   " elseif &number == 1 && &relativenumber == 0
"   " setlocal relativenumber!
"   else
"     setlocal number!
"     " setlocal relativenumber!
"   endif
" endfunction
" nnoremap <Leader>tl :call ChangeLineNumbering()<CR>


" bracket autocompletion
" inoremap { {}<ESC>i
" inoremap {} {}
" inoremap {<Enter> {}<Left><CR><ESC><S-o><Tab>
" inoremap ( ()<ESC>i
" inoremap () ()
" inoremap (<Enter> ()<Left><CR><ESC><S-o><Tab>
" inoremap [ []<ESC>i
" inoremap [] []
" inoremap [<Enter> []<Left><CR><ESC><S-o><Tab>


"function! GetPreCursorChar()
"  if col('.') <= 1
"    " Cursor is on the first column.
"    return ''
"  endif
"  let before_cursor = getline('.')[:col('.')-2]
"  return strcharpart(before_cursor, strchars(before_cursor)-1)
"endfunction
"
"function! GetPostCursorChar()
"  if col('.') == col("$")-1 " Cursor is on the first column.
"    return ''
"  endif
"  let after_cursor = getline('.')[:col('.')]
"  return strcharpart(after_cursor, strchars(after_cursor)-1)
"endfunction
"
"nnoremap <Leader>x :call Prep()<CR>
"
"fun! Prep()
"  " echo GetPreCursorChar()
"  " echo GetPostCursorChar()
"    
"  call feedkeys("\<CR>", 'n')
"
"  if (&commentstring)
"    let l:comment = substitute(split(&commentstring, '%s')[0], '\s*', '', 'g')
"    if getline('.') =~ l:comment
"      return
"    endif
"  endif
"
"  if GetPreCursorChar() == '{' && GetPostCursorChar() == '}'
"    call feedkeys("\<TAB>", 'n')
"  endif
"  " if (GetPostCursorChar() == "{")
"    " call feedkeys("<CR>")
"    " echo "BRACKET"
"  " else
"    " echo "NOPE"
"  " endif
"endfun
" }}}


" vim: fdm=marker
" https://discourse.doomemacs.org/t/keybind-reference-sheet/49
" https://dev.to/braydentw/what-s-the-coolest-vim-plugin-40i5



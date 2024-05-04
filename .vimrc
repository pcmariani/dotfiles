" vimrc with no plugins (except fzf.vim)

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
" set showcmd
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
set autoindent
set smartindent
set tabstop=2
set shiftwidth=0 " zero will always match tabstop
set expandtab "need toggle
" set smarttab
set termguicolors
set formatoptions-=cr
set showtabline=0

set wildmenu
set wildoptions=pum
set wildcharm=<Tab>	" Needed to open the wildmenu from shortcuts
set wildignore=*.swp,*.bak,*.pyc,*.class,*.o

if has("gui_running")
  set guifont=MonacoNerdFontCompleteM-:h14
  " set guifont=IosevkaNFM:h15
  if (&guifont =~ 'Iosevka')
    set columnspace=-1
  else
    set columnspace=0
  endif
  set guioptions-=T
  set guioptions-=r
  set guioptions-=L
endif

" Disable 'command' and 'option' navigation bindings
if has("gui_macvim")
  let macvim_skip_cmd_opt_movement = 1
endif

set highlight=M-
set fillchars+=vert:\ 
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"






" }}}

" --- keymaps --- {{{

let mapleader = " "

" t - toggle
nnoremap <expr> <Leader>tl (&number == 1 ? ':set nonumber<CR>' : ':set number<CR>')
nnoremap <Leader>tt :call NextColor()<CR>
nnoremap <Leader>tw :set wrap!<CR>
nnoremap <Leader>ts :set spell!<CR>
nnoremap <Leader>tz :call ToggleMaximize()<CR>
nnoremap <expr> <Leader>ts 'mm' . (&tabstop == 2 ? ':set tabstop=4' : ':set tabstop=2') . '<CR>ggvG==<Esc>`mzz'
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
nnoremap <Leader>gg :tab term ++close lazygit<CR>
" see fzf

" o - open
nnoremap <Leader>oT :vertical terminal ++close<CR>
nnoremap <Leader>ot :vertical terminal ++close<CR>

" b - buffer
nnoremap <leader>bs :w<CR>
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprev<CR>
nnoremap <leader>bN :new<CR>
nnoremap <leader>bk :Bclose<CR>
nnoremap <leader>bd :Bclose<CR>
nnoremap <silent> <Leader>by mtgg0vG$y`t:delmarks t<cr>
nnoremap <leader>bb :buffer <TAB>
" nnoremap <leader>bb :ls t<cr>:b
" bx popup buffer scratch
" see fzf

" c - code
nnoremap <silent> <Leader>cf mmggVG=`mzz:delmarks m<cr>
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
nnoremap <silent> <ESC> :call EscapeKey()<CR>
nnoremap <C-o> <C-o>zz
"nnoremap <C-p> " see quickfix mapping
nnoremap n nzz
nnoremap N Nzz

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
nmap Y y$

noremap <silent> <TAB> %
nnoremap <silent> <Leader>` <C-^>
nnoremap <silent> \ :bnext<CR>
nnoremap <silent> \| :bprev<CR>

" Remap for dealing with word wrap
nnoremap <expr> j v:count == 0 ? 'gj' : 'j'
nnoremap <expr> k v:count == 0 ? 'gk' : 'k'

inoremap jj <ESC>
inoremap kk <ESC>
inoremap hhh <ESC>
inoremap lll <ESC>

" Automatically fix the last misspelled word and jump back to where you were.
"   Taken from this talk: https://www.youtube.com/watch?v=lwD8G1P52Sk
" nnoremap <C-CR> sp :normal! mz[s1z=`z<CR>

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

nnoremap <silent> ∆ mm:m .+1<CR>==`m
nnoremap <silent> ˚ mm:m .-2<CR>==`m
inoremap <silent> ∆ <Esc>:m .+1<CR>==gi
inoremap <silent> ˚ <Esc>:m .-2<CR>==gi
vnoremap <silent> ∆ :m '>+1<CR>gv=gv
vnoremap <silent> ˚ :m '<-2<CR>gv=gv

nnoremap <silent> <C-h> <C-w>h
nnoremap <silent> <C-j> <C-w>j
nnoremap <silent> <C-k> <C-w>k
nnoremap <silent> <C-l> <C-w>l

nnoremap <silent> < <<
nnoremap <silent> > >>
vnoremap <silent> < <gv
vnoremap <silent> > >gv

nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>e :Lexplore<CR>
nnoremap <leader>r mm:w<CR>:so $MYVIMRC<CR>:nohl<CR>:echo ".vimrc reloaded"<CR>`m
nnoremap <leader>ov :tabnew ~/.vimrc<CR>
" nnoremap <leader>sc :colorscheme <TAB>
nnoremap <leader>J ddpkJ



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
    call feedkeys( ":nohlsearch\<CR>", "n")
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
command! Bclose call <SID>BufcloseCloseIt()
function! <SID>BufcloseCloseIt()
  let l:currentBufNum = bufnr("%")
  let l:alternateBufNum = bufnr("#")
  if buflisted(l:alternateBufNum)
    buffer #
  else
    bnext
  endif
  if bufnr("%") == l:currentBufNum
    new
  endif
  if buflisted(l:currentBufNum)
    execute("bdelete! ".l:currentBufNum)
  endif
endfunction

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
" nnoremap <leader>e :e %:p:h<CR>
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

augroup filetypes
  au!
  au BufWinEnter * if &l:buftype ==# 'help' | nnoremap <buffer> q :q<CR> | endif
  " Make sure .aliases, .bash_aliases and similar files get syntax highlighting.
  au BufNewFile,BufRead *aliases* set ft=sh
  " Update a buffer's contents on focus if it changed outside of Vim.
  au FocusGained,BufEnter * :checktime
  " Ensure tabs don't get converted to spaces in Makefiles.
  " au FileType make setlocal noexpandtab
  " Automatically cd into dir of buffer
  " au BufEnter * if expand("%:p:h") !~ '^/tmp' | silent! lcd %:p:h | endif
  au FileType vim :iabbrev fun function ()<CR>endfunction<UP><LEFT><LEFT><LEFT>
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

tnoremap <Esc> <C-\><C-n>
tnoremap <silent> <C-h> <C-w>h
tnoremap <silent> <C-j> <C-w>j
tnoremap <silent> <C-k> <C-w>k
tnoremap <silent> <C-l> <C-w>l
nnoremap <leader>x :call SendCurrentTermCommand()<CR>
nnoremap <leader>X :SendTermCommand 

command! -complete=file -nargs=* SendTermCommand call SendTermCommand(<f-args>)

function! SendCurrentTermCommand()
  let currentTermCommand = get(g:, 'currentTermCommand', "")
  if !currentTermCommand
    call feedkeys(":SendTermCommand ".currentTermCommand."\<CR>",'n')
  else
    call feedkeys(":SendTermCommand ",'n')
  endif
endfunction

function! SendTermCommand(...)
  let g:currentTermCommand = join(a:000, " ")
  if !len(term_list())
    execute "vertical terminal ++close"
  endif
  call term_sendkeys(term_list()[0], g:currentTermCommand )
  call term_sendkeys(term_list()[0], "\<CR>" )
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

colorscheme habamax
if g:colors_name=="habamax"
  hi CursorLine ctermbg=235 guibg=#272727
  hi StatusLineNC ctermbg=0 ctermfg=8 guibg=black guifg=#555555
  hi StatusLine ctermbg=0 ctermfg=247 guibg=black guifg=#999999
  hi VertSplit ctermbg=0 guibg=black
  hi CursorLineNr term=bold cterm=bold ctermfg=130 gui=bold guifg=#bb7911
  hi QuickFixLine guibg=#444444 guifg=NONE
  " hi Search guibg=#5f875f
  hi Search guibg=#aa88cc
  hi CurSearch guibg=#ffaf5f
endif

" Spelling mistakes will be colored up red.
hi SpellBad cterm=underline ctermfg=203 guifg=#ff5f5f
hi SpellLocal cterm=underline ctermfg=203 guifg=#ff5f5f
hi SpellRare cterm=underline ctermfg=203 guifg=#ff5f5f
hi SpellCap cterm=underline ctermfg=203 guifg=#ff5f5f
hi Folded guifg=darkyellow

hi User1 guifg=green guibg=black
" hi User2 ctermbg=0 ctermfg=247 guibg=black guifg=#999999

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

" }}}

" --- search / replace / quickfix --- {{{

function! SearchToQF(...)
  let l:target = getcwd() == $HOME || a:0 ? "%" : "**/*"  " if any params, %
  " echo l:target
  silent execute "silent vimgrep! /\\C" . escape(@/, '/') . "/jg " . l:target
  copen
  call feedkeys("\<C-W>p",'n')
endfunction

" send // to quickfix locally (if in HOME directory) or globally
nnoremap <silent> <C-q> :call SearchToQF(1)<CR>

" search for word under cursor to quickfix
nnoremap <silent> <leader>/ /\V<C-r>=expand("<cword>")<CR><CR>:call SearchToQF()<CR>

" local search for visual selection
vnoremap <silent> / "hy/<C-r>h<CR><S-n>
vnoremap <silent> <Leader>/ "hy/<C-r>h<CR><S-n>:call SearchToQF()<CR>

" local search/replace word under cursor
" - set mark; from line to bottom do cWord substitution | repeat from top to line
" nnoremap <S-r> :%s/\<<C-r><C-w>\>/<C-r><C-w>/gc<Left><Left><Left>
nnoremap <S-r> mm:,$s/\V\<<c-r><c-w>\>/<C-r><C-w>/gIc \| 1,''-&&<c-left><left><left><left><left><left><left><left>
" local search/replace visual selection
" - set mark; yank visual selection into h register; from line to bottom do cWord substitution | repeat from top to line
vnoremap <S-r> mm"hy/\V<C-r>h<CR><S-n>:,$s/<C-r>h/<C-r>h/gIc \| 1,''-&&<c-left><left><left><left><left><left><left><left>

" Search for current word and replace with given text
" https://vim.fandom.com/wiki/Search_and_replace_in_multiple_buffers
function! Replace(bang, doQuickFix, mode, replace)
  let l:target = getcwd() == $HOME || !a:bang ? "%" : "**/*"
  if a:mode == 'n'
    let search = '\<' . escape(expand('<cword>'), '/\.*$^~[') . '\>'
  elseif a:mode == 'v'
    let search = escape(getreg("h"), '/\.*$^~[')
  endif
  let replace = escape(a:replace, '/\&~')
  execute "vimgrep /\\C" . search . '/ ' . l:target
  if a:doQuickFix
    copen
  endif
  execute 'cdo s/' . search . '/' . replace . '/cIge'
endfunction
nnoremap <Leader>sr :call Replace(0, 1, "n", input('Replace "'.expand('<cword>').'" : '))<CR>
nnoremap <Leader>sR :call Replace(1, 1, "n", input('Replace '.expand('<cword>').' with: '))<CR>
vnoremap <Leader>sr "hy:call Replace(0, 1, "v", input('Replace '.getreg("h").' with: '))<CR>
vnoremap <Leader>sR "hy:call Replace(1, 1, "v", input('Replace '.getreg("h").' with: '))<CR>

nnoremap <silent> <Leader>cc :call ToggleQuickFix()<CR><C-w><C-p>
nnoremap <silent> <expr> <C-p> empty(filter(getwininfo(), 'v:val.quickfix')) ? "<C-i>" : ":keepjumps cprevious<CR>zz"
nnoremap <silent> <expr> <C-n> empty(filter(getwininfo(), 'v:val.quickfix')) ? "<C-n>" : ":keepjumps cnext<CR>zz"
nnoremap <silent> <expr> <Leader>cp empty(filter(getwininfo(), 'v:val.quickfix')) ? "<nop>" : ":colder<CR>"
nnoremap <silent> <expr> <Leader>cn empty(filter(getwininfo(), 'v:val.quickfix')) ? "<nop>" : ":cnewer<CR>"
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
  nnoremap <buffer> <leader>bk :cclose<CR>
  nnoremap <buffer> <leader>bd :cclose<CR>
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

" }}}

" --- completion --- {{{

set completeopt=menu,menuone,preview,noinsert
set omnifunc=syntaxcomplete#Complete " basic completion for programming languages (C-x C-O)
set infercase            " infer case sensitivity when doing keyword completion

" inoremap <silent> <expr> <CR> pumvisible() ? "\<C-Y>" : "<Esc>:call Prep()<cr>a"
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
  let mode = " %#User1#%{mode()}%* "
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
    hi User1 guifg=orange guibg=black
  elseif a:mode == 'r'
    hi User1 guifg=magenta guibg=black
  else
    hi User1 guifg=darkgreen guibg=black
  endif
endfunction

augroup ModeEvents
  au!
  au InsertEnter *  call InsertStatuslineColor(v:insertmode)
  au InsertChange * call InsertStatuslineColor(v:insertmode)
  au InsertLeave *            hi User1 guifg=green  guibg=black
  au Modechanged [vV\x16]*:*  hi User1 guifg=green  guibg=black " leave visual
  au ModeChanged *:[vV\x16]*  hi User1 guifg=magenta guibg=black " enter visual
  au Modechanged *c:*         hi User1 guifg=green  guibg=black " leave command
  au Modechanged *:c*         hi User1 guifg=brown guibg=black " enter command
  " au TextChanged,TextChangedI  User2 guifg=#bb7911
  " au BufWritePost *            hi User2 guifg=#999999
augroup END

" }}}

" --- fzf --- {{{

set rtp^=/opt/homebrew/opt/fzf " If installed using Homebrew on Apple Silicon
set rtp^=~/.vim/bundle/fzf.vim " git clone git@github.com:junegunn/fzf.vim.git ~/.vim/bundle/fzf.vim
let g:fzf_vim = {}
" let g:fzf_vim.preview_window = ['right,50%,<100(up,40%)', 'ctrl-/']
" let g:fzf_vim.preview_window = ['down,50%', 'ctrl-/']
let g:fzf_layout = { 'down': '38%' }
let $FZF_DEFAULT_COMMAND="rg --files --hidden -g '!Library/' -g '!Applications' -g '!Documents' -g '!Downloads' -g '!Desktop' -g '!.git'"
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
nnoremap <silent> <leader>gs :Commits<CR> " FZF @Git Commits
nnoremap <silent> <leader>gb :BCommits<CR> " FZF @Git Commits Buffer
" b - buffer
nnoremap <silent> <leader>bb :Buffers<CR>
nnoremap <silent> <Leader>bl :Filetypes<CR>
" f - files
nnoremap <silent> <leader><leader> :Files<CR>
nnoremap <silent> <leader>fF :Files<CR>
nnoremap <silent> <expr> <leader>ff b:in_git_repo ? ":GFiles<CR>" : ":Files<CR>"
nnoremap <silent> <leader>fr :History<CR>
" s - search
nnoremap <silent> <leader>sb :BLines<CR>
nnoremap <silent> <leader>st :Colors<CR>| " [t]hemes
nnoremap <silent> <leader>sc :Commands<CR>
nnoremap <silent> <Leader>sf :RG<cr>
nnoremap <silent> <leader>sh :Helptags<CR>
nnoremap <silent> <leader>s; :History:<CR>
nnoremap <silent> <leader>s/ :History/<CR>
nnoremap <silent> <leader>sm :Maps<CR>
" Meta
nnoremap <silent> ≈ :Commands<CR>

" }}}

" --- comments --- {{{

function! Comet()
  " echo mode()
  let l:line=getline('.')
  let l:comment = substitute(split(&commentstring, '%s')[0], '\s*', '', 'g')
  " let l:save = winsaveview()
  let save_pos = getpos('.')
  if l:line =~ '^\s*' . l:comment
    let l:spacesBeforeText = match(strpart(l:line, match(l:line, l:comment) + 1), '\S') + 1
    call setline(line('.'), substitute(l:line, '\(^\s*\)' . l:comment . '\s*', '\1', ''))
    let save_pos[2] -= l:spacesBeforeText
    call setpos('.', save_pos)
  else
    call setline(line('.'), substitute(l:line, '\(^\s*\)', '\1' . l:comment . ' ', ''))
    let save_pos[2] += 2
    call setpos('.', save_pos)
  endif
  " call winrestview(l:save)
endfunction

" au! bufenter * 
" \   if &commentstring != ""
" \ |   let @c=substitute(split(&commentstring, '%s')[0], '\s*', '', 'g')
" \ |   nnoremap <buffer> <silent> gcc mm:keeppattern s/\(^\s*\)/\1<c-r>c /<cr>`m<RIGHT>
" \ |   nnoremap <buffer> <silent> gu mm:silent! keeppattern s/\(^\s*\)<c-r>c\s*/\1/<cr>`m<LEFT><LEFT><LEFT>
" \ |   vnoremap <buffer> <silent> gc mm:keeppattern s/\(^\s*\)/\1<c-r>c /<cr>`m<RIGHT>
" \ |   vnoremap <buffer> <silent> gu mm:silent! keeppattern s/\(^\s*\)<C-R>c\s*/\1/<CR>`m<LEFT><LEFT><LEFT>
" \ | else 
" \ |   let @c="" 
" \ | endif
nnoremap gcc :call Comet()<CR>
vnoremap gc :call Comet()<CR>

" }}}


" BONEYARD {{{


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

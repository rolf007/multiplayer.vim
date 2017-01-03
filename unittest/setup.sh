vimtestdir=$(mktemp -d)
mkdir $vimtestdir/.vim
cp -r ~/.vim/bundle/multiplayer/* $vimtestdir/.vim
rm $vimtestdir/.vim/profile*

succes_cmd="${succes_cmd:-qall!}"

cat >$vimtestdir/.vimrc <<EOL
syntax on
"call timer_start(1000, {-> feedkeys('  ')})
function! WinId()
	if exists('*win_getid')
		return "b=" . bufnr('%') . " w=" . win_getid() . " " . getpid()
	endif
	return bufnr('%')
endfunction
set laststatus=2
set statusline=
set statusline +=%1*[%{WinId()}]\ %*          "buffer number (and winid)
set statusline +=%4*\ %t%*            "filename
set statusline +=%2*%m%r%w%*          "modified flag, read only, 
set statusline +=\ UNITTESTING\ 
set statusline +=%=
let &statusline .= multiplayer#StatusLine()
set statusline +=%1*line:\ %l%*     "current line
set statusline +=%2*/%L,\ \ %*        "total lines
set statusline +=%1*row:\ %c\ %*      "virtual column number
set errorformat=%f\ line\ %l:\ %m
nnoremap q :qall!<CR>
set tabstop=4

"call timer_start(5000, {-> feedkeys("ihej\<ESC>")})
call timer_start(500, {-> <SID>Test()})

function! SendUnicastMsg(command, from_pid, buff, msg)
	call writefile(extend([a:command, a:from_pid, a:buff, len(a:msg)], a:msg), "/tmp/vim_multi_player_pipe_" . getpid())
endfunction

function! s:Test()
	source test.vim
	cgetexpr v:errors
	if len(v:errors)
		copen
	else
		$succes_cmd
	endif
endfunction
EOL

pushd $vimtestdir > /dev/null

return
vim:tw=78:ts=4:ft=vim:

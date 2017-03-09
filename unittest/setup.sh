ROOT=$PWD
vimtestdir=$(mktemp -d)
mkdir $vimtestdir/.vim
cp -r ~/.vim/bundle/multiplayer.vim/* $vimtestdir/.vim
rm -f $vimtestdir/.vim/profile*

succes_cmd=${succes_cmd:-"echom \"unittest succeded\""}

cat >$vimtestdir/.vimrc <<EOL
syntax on
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
set statusline +=\ UNITTESTING\ $0
set statusline +=%=
let &statusline .= multiplayer_statusline#Get()
set statusline +=\ %1*line:\ %l%*     "current line
set statusline +=%2*/%L,\ \ %*        "total lines
set statusline +=%1*row:\ %c\ %*      "virtual column number
set errorformat=%f\ line\ %l:\ %m
nnoremap q :qall!<CR>
set tabstop=4

call timer_start(500, {-> <SID>Test()})

let g:test_players = {}
let s:next_debug_pid = 1000001

function! CreateTestPlayer()
	let pid = s:next_debug_pid
	let s:next_debug_pid = s:next_debug_pid + 1
	let g:test_players[pid] = {}
	let g:test_players[pid].msgs = []
	return pid
endfunction

function! ExpectedMsg(command, msg)
	return [a:command, getpid(), len(a:msg)] + a:msg
endfunction

function! GetMsg(pid)
	if len(g:test_players[a:pid].msgs) == 0
		return 0
	endif
	let ret = g:test_players[a:pid].msgs[0]
	let g:test_players[a:pid].msgs = g:test_players[a:pid].msgs[1:]
	return ret
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

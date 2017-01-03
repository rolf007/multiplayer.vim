vimtestdir=$(mktemp -d)
mkdir $vimtestdir/.vim
cp -r ~/.vim/bundle/multiplayer.vim/* $vimtestdir/.vim
rm -f $vimtestdir/.vim/profile*

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

let g:players = {}
let s:next_debug_pid = 1000001

function! SendUnicastMsg(command, from_pid, msg)
	call writefile(extend([a:command, a:from_pid, g:players[a:from_pid].file, len(a:msg)], a:msg), "/tmp/vim_multi_player_pipe_" . getpid())
endfunction

function! SendCursor(from_pid)
	call SendUnicastMsg('cursor', a:from_pid, [g:players[a:from_pid].mode] + g:players[a:from_pid].range)
endfunction

function! s:MyHandlerOut(channel, msg, pid)
	call add(g:players[a:pid].read_buffer, a:msg)
	if len(g:players[a:pid].read_buffer) > 3 && g:players[a:pid].read_buffer[3] + 4 == len(g:players[a:pid].read_buffer)
		call add(g:players[a:pid].msgs, g:players[a:pid].read_buffer)
		let g:players[a:pid].read_buffer = []
	endif
endfunction

function! CreatePlayer()
	let pid = s:next_debug_pid
	let s:next_debug_pid = s:next_debug_pid + 1
	let g:players[pid] = {}
	let g:players[pid].read_buffer = []
	let g:players[pid].msgs = []
	let g:players[pid].file = "a.txt"
	let g:players[pid].mode = "n"
	let g:players[pid].range = [1,1,1,1]
	call system('mkfifo /tmp/vim_multi_player_pipe_' . pid)
	call system('sleep infinity > /tmp/vim_multi_player_pipe_' . pid . ' &')
	let job = job_start('cat /tmp/vim_multi_player_pipe_' . pid, {"out_cb": { channel, msg -> call('s:MyHandlerOut', [channel, msg, pid])}})
	return pid
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

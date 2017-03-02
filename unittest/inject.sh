
cat >>$vimtestdir/.vim/autoload/multiplayer.vim <<EOL


let g:test_broadcast_msgs = []

function! s:SendUnicastMsg(command, msg, recv_pid)
	call add(g:test_players[a:recv_pid].msgs, [a:command, getpid(), len(a:msg)] + a:msg)
endfunction

function! s:SendBroadcastMsg(command, msg)
	call add(g:test_broadcast_msgs, [a:command, getpid(), len(a:msg)] + a:msg)
endfunction

function! SendToDut(command, from_pid, msg)
	call <SID>ParseMsg([a:command, a:from_pid, len(a:msg)] + a:msg)
endfunction

function! TextChanged()
	call <SID>TextChanged()
endfunction

function! GetBroadCastedMsg(pid)
	if len(g:test_broadcast_msgs) == 0
		return 0
	endif
	let ret = g:test_broadcast_msgs[0]
	let g:test_broadcast_msgs = g:test_broadcast_msgs[1:]
	return ret
endfunction

EOL

# vim:tw=78:ts=4:ft=vim:


cat >>$vimtestdir/.vim/autoload/multiplayer.vim <<EOL


function! s:SendUnicastMsg(command, msg, recv_pid)
	call add(g:test_players[a:recv_pid].msgs, [a:command, getpid(), len(a:msg)] + a:msg)
endfunction

function! SendToDut(command, from_pid, msg)
	call <SID>ParseMsg([a:command, a:from_pid, len(a:msg)] + a:msg)
endfunction

function! TextChanged()
	call <SID>TextChanged()
endfunction

EOL

# vim:tw=78:ts=4:ft=vim:

source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh

cat >>$vimtestdir/.vimrc <<EOL
EOL

cat >>$vimtestdir/test.vim <<EOL

let s:cur_debug_pid = 0

function! s:DebugMove(delta)
	let g:test_players[s:cur_debug_pid].range[1] += a:delta
	let g:test_players[s:cur_debug_pid].range[3] += a:delta
	call SendCursor(s:cur_debug_pid)
endfunction

function! SendCursor(from_pid)
	call SendToDut('cursor', a:from_pid, [g:test_players[a:from_pid].file, g:test_players[a:from_pid].mode] + g:test_players[a:from_pid].range)
endfunction

function! s:DebugConnect()
	let s:cur_debug_pid = CreateTestPlayer()
	call s:DebugChange(s:cur_debug_pid-1000000)
	call SendToDut('hello', s:cur_debug_pid, [])
	call SendToDut('iam', s:cur_debug_pid, ["debug".s:cur_debug_pid])
	call SendCursor(s:cur_debug_pid)
	nnoremap <UP> :call <SID>DebugMove(-1)<CR>
	nnoremap <DOWN> :call <SID>DebugMove(1)<CR>
endfunction

function! s:DebugChange(count)
	if s:cur_debug_pid != 0 && a:count == 0
		let s:cur_debug_pid = 0
		nunmap <UP>
		nunmap <DOWN>
	elseif s:cur_debug_pid == 0 && a:count != 0
		nnoremap <UP> :call <SID>DebugMove(-1)<CR>
		nnoremap <DOWN> :call <SID>DebugMove(1)<CR>
	endif
	if a:count != 0
		let s:cur_debug_pid = 1000000 + a:count
	endif
endfunction

function! s:DebugDisconnect()
endfunction

execute "nnoremap <silent> mc :<C-U>call <SID>DebugConnect()<CR>"
execute "nnoremap <silent> mm :<C-U>call <SID>DebugChange(v:count)<CR>"
execute "nnoremap <silent> md :<C-U>call <SID>DebugDisconnect()<CR>"



MultiplayerConnect

let my_pid = CreateTestPlayer()
let g:test_players[my_pid].file = "a.txt"
let g:test_players[my_pid].mode = "n"
let g:test_players[my_pid].range = [1,1,1,1]
call SendToDut("hello", my_pid, [])

call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(my_pid))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['a.txt', 'n', 1, 1, 1, 1]), GetMsg(my_pid))
call assert_equal(0, GetMsg(my_pid))

call SendToDut("iam", my_pid, ['Tester'])
call SendCursor(my_pid)
call SendToDut("diff", my_pid, ['a.txt', '1c1', '< ', '---', '> hello world'])
call assert_equal(0, GetMsg(my_pid))
call assert_equal(['hello world'], getline(1, '$'))

call SendToDut("diff", my_pid, ['a.txt', '1a2,3', "> \<TAB>12345\<TAB>123", '> 123456789'])
call assert_equal(['hello world', "\<TAB>12345\<TAB>123", '123456789'], getline(1, '$'))

let g:test_players[my_pid].range = ['6', '2', '6', '2']
call SendCursor(my_pid)
let m = getmatches()
call assert_equal(1, len(m))
call assert_equal('MPCol2', m[0].group)
call assert_equal('\%>5v\%<7v\%2l', m[0].pattern)
call assert_equal(0, GetMsg(my_pid))

"======= OTHER SIDE =======

execute("normal! dd")
call TextChanged()
call assert_equal(ExpectedMsg('diff', ['a.txt', '1d0', '< hello world']), GetMsg(my_pid))
call assert_equal(0, GetMsg(my_pid))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

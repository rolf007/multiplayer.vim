succes_cmd="echom \"unittest succeded\""
source "${BASH_SOURCE%/*}"/../setup.sh

cat >>$vimtestdir/.vimrc <<EOL
EOL

cat >>$vimtestdir/test.vim <<EOL

function! s:DebugMove(delta)
	let s:players[s:debug_pid].range[1] += a:delta
	let s:players[s:debug_pid].range[3] += a:delta
	call SendUnicastMsg('cursor', s:debug_pid, s:players[s:debug_pid].file, ['n'] + s:players[s:debug_pid].range)
endfunction

function! s:Debug(pseudo_pid)
	if a:pseudo_pid == 0
		nunmap <UP>
		nunmap <DOWN>
	else
		let s:debug_pid = a:pseudo_pid
		if !has_key(s:players, s:debug_pid)
			let file = "a.txt"
			let s:players[s:debug_pid] = {"file":file, "mode":"n", "range":[1,1,1,1]}
			call SendUnicastMsg('hello', s:debug_pid, file, [])
			call SendUnicastMsg('iam', s:debug_pid, file, ["debug".s:debug_pid])
			call SendUnicastMsg('cursor', s:debug_pid, file, ['n'] + s:players[s:debug_pid].range)
		endif
		nnoremap <UP> :call <SID>DebugMove(-1)<CR>
		nnoremap <DOWN> :call <SID>DebugMove(1)<CR>
	endif
endfunction

let s:players = {}
execute "nnoremap <silent> mm :<C-U>call <SID>Debug(v:count)<CR>"

MultiplayerConnect
call SendUnicastMsg("hello", 1000001, "a.txt", [])
call SendUnicastMsg("iam", 1000001, "a.txt", ['Tester'])
call SendUnicastMsg("diff", 1000001, "a.txt", ['1c1', '< ', '---', '> hello world'])
sleep 200m
call assert_equal("hello world", getline(1))
call assert_equal(1, line('$'))
call SendUnicastMsg("diff", 1000001, "a.txt", ['1a2,3', "> \<TAB>12345\<TAB>123", '> 123456789'])
sleep 200m
call assert_equal(['hello world', "\<TAB>12345\<TAB>123", '123456789'], getline(1, '$'))
call SendUnicastMsg('cursor', '1000001', 'a.txt', ['n', '6', '2', '6', '2'])
sleep 200m
let m = getmatches()
call assert_equal(1, len(m))
call assert_equal('MPCol2', m[0].group)
call assert_equal('\%>5v\%<7v\%2l', m[0].pattern)

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

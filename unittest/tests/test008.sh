source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh
#Playing around with split

cat >>$vimtestdir/.vimrc <<EOL
EOL

cat >>$vimtestdir/test.vim <<EOL

let s:cur_debug_pid = 0

function! s:DebugMove(delta)
	if s:cur_debug_pid == 0
		return
	endif
	let g:test_players[s:cur_debug_pid].range[1] += a:delta[1]
	let g:test_players[s:cur_debug_pid].range[3] += a:delta[1]
	let g:test_players[s:cur_debug_pid].range[0] += a:delta[0]
	let g:test_players[s:cur_debug_pid].range[2] += a:delta[0]
	call SendCursor(s:cur_debug_pid)
endfunction

function! SendCursor(from_pid)
	call SendToDut('cursor', a:from_pid, [g:test_players[a:from_pid].file, g:test_players[a:from_pid].mode] + g:test_players[a:from_pid].range)
endfunction

function! s:DebugSetCur(pid)
	if s:cur_debug_pid != 0
		call SendToDut('iam', s:cur_debug_pid, ["debug".(s:cur_debug_pid-1000000)])
	endif
	let s:cur_debug_pid = a:pid
	if s:cur_debug_pid != 0
		call SendToDut('iam', s:cur_debug_pid, ["*debug".(s:cur_debug_pid-1000000)."*"])
	endif
endfunction

function! s:DebugConnect()
	let pid = CreateTestPlayer()
	let g:test_players[pid].file = "a.txt"
	let g:test_players[pid].mode = "n"
	let g:test_players[pid].range = [1,1,1,1]
	call SendToDut('hello', pid, [])
	call <SID>DebugSetCur(pid)
	call SendCursor(s:cur_debug_pid)
endfunction


function! s:DebugNext()
	let prev = -1
	for key in keys(g:test_players)
		if prev == s:cur_debug_pid
			call <SID>DebugSetCur(key)
			return
		endif
		let prev = key
	endfor
endfunction

function! s:DebugPrev()
	let prev = -1
	for key in keys(g:test_players)
		if key == s:cur_debug_pid && prev != -1
			call <SID>DebugSetCur(prev)
			return
		endif
		let prev = key
	endfor
endfunction

function! s:DebugDisconnect()
	if s:cur_debug_pid == 0
		return
	endif
	let prev = s:cur_debug_pid
	let nxt = 0
	unlet g:test_players[prev]
	if len(keys(g:test_players)) != 0
		let nxt = keys(g:test_players)[0]
	endif
	call <SID>DebugSetCur(nxt)
	call SendToDut('byebye', prev, [])
endfunction

nnoremap <silent> mc :<C-U>call <SID>DebugConnect()<CR>
nnoremap <silent> md :<C-U>call <SID>DebugDisconnect()<CR>
nnoremap <silent> mn :call <SID>DebugNext()<CR>
nnoremap <silent> mp :call <SID>DebugPrev()<CR>
nnoremap <silent> <C-Up> :call <SID>DebugMove([0,-1])<CR>
nnoremap <silent> <C-Down> :call <SID>DebugMove([0,1])<CR>
nnoremap <silent> <C-Left> :call <SID>DebugMove([-1,0])<CR>
nnoremap <silent> <C-Right> :call <SID>DebugMove([1,0])<CR>

execute("normal! i123\<CR>\<ESC>")
execute("normal! i456\<CR>\<ESC>")
execute("normal! i789\<CR>\<ESC>")
execute("normal! i1011\<CR>\<ESC>")
execute("normal! i1213\<CR>\<ESC>")
execute("normal! i1415\<CR>\<ESC>")
execute("normal! 3k")
MultiplayerConnect

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

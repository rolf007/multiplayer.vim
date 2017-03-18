source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh
#Playing around with split

cat >>$vimtestdir/.vimrc <<EOL
set scrolloff=3
let g:multiplayer_auto_split = 'y'
EOL

cat >>$vimtestdir/f <<EOL
#a
#b
#c
#d
#e
#f
EOL

cat >>$vimtestdir/test.vim <<EOL

call histadd(':', 'MultiplayerLs')
call histadd(':', 'call SplitAll(2,4)')
call histadd(':', 'call UnSplit()')

let g:tmp = []

function! SplitAll(same, others)
	let home = win_getid()
	if a:others > 0
		let &eadirection = "hor"
		for n in range(a:same)
			exe "aboveleft" . 6 . "split"
			call add(g:tmp,[win_getid(),&eadirection])
			wincmd j
		endfor
	endif

	if a:others > 0
		let &eadirection = "ver"
		botright 40vsplit a
		let height = winheight(0)/a:others-1
		call add(g:tmp,[win_getid(),&eadirection])
		let &eadirection = "hor"
		for n in range(a:others - 1)
			exe "rightbelow" . height . "split b"
			call add(g:tmp,[win_getid(),&eadirection])
			wincmd k
		endfor
	endif
	let &eadirection = "both"
	call win_gotoid(home)
endfunction

function! UnSplit()
  for winid in reverse(g:tmp)
    let &eadirection = winid[1]
    exe win_id2win(winid[0]) . "wincmd c"
  endfo
  let g:tmp = []
  let &eadirection = "both"
endfunction


let s:cur_debug_pid = 0

function! s:DebugMove(delta)
	if s:cur_debug_pid == 0
		return
	endif
	if g:test_players[s:cur_debug_pid].range[0] > 1 || a:delta[0] == 1
		let g:test_players[s:cur_debug_pid].range[0] += a:delta[0]
		let g:test_players[s:cur_debug_pid].range[2] += a:delta[0]
	endif
	if g:test_players[s:cur_debug_pid].range[1] > 1 || a:delta[1] == 1
		let g:test_players[s:cur_debug_pid].range[1] += a:delta[1]
		let g:test_players[s:cur_debug_pid].range[3] += a:delta[1]
	endif
	call SendCursor(s:cur_debug_pid)
endfunction

function! SendCursor(from_pid)
	call SendToDut('cursor', a:from_pid, [g:test_players[a:from_pid].mode] + g:test_players[a:from_pid].range)
endfunction

function! s:DebugSetCur(pid)
	let highlights = [
		\ ['inverse', 'Red', 'White'],
		\ ['inverse', 'Green', 'White'],
		\ ['inverse', 'Blue', 'White'],
		\ ['inverse', 'Cyan', 'White'],
		\ ['inverse', 'Magenta', 'White']
		\ ]
	if s:cur_debug_pid != 0
		call SendToDut('iam', s:cur_debug_pid, ["debug".(s:cur_debug_pid-1000000)])
	endif
	let s:cur_debug_pid = a:pid
	if s:cur_debug_pid != 0
		call SendToDut('iam', s:cur_debug_pid, ["*debug".(s:cur_debug_pid-1000000)."*"])
		call SendToDut('highlight', s:cur_debug_pid, [highlights[s:cur_debug_pid-1000000]])
	endif
endfunction

function! s:DebugConnect()
	let pid = CreateTestPlayer()
	let g:test_players[pid].file = "$vimtestdir/a.txt"
	let g:test_players[pid].mode = "n"
	let g:test_players[pid].range = [1,v:count1,1,v:count1]
	call SendToDut('hello', pid, [])
	call <SID>DebugSetCur(pid)
	call SendToDut('file', s:cur_debug_pid, ["$vimtestdir/a.txt"])
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

function! s:DebugFile()
	let file = input("goto file> ")
	if file == ""
		let file = "a.txt"
	endif
	call SendToDut('file', s:cur_debug_pid, [file])
	let g:test_players[s:cur_debug_pid].range[0] = 1
	let g:test_players[s:cur_debug_pid].range[2] = 1
	let g:test_players[s:cur_debug_pid].range[1] = 1
	let g:test_players[s:cur_debug_pid].range[3] = 1
	call SendCursor(s:cur_debug_pid)
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
nnoremap <silent> mf :call <SID>DebugFile()<CR>
nnoremap <silent> <C-Up> :<C-U>call <SID>DebugMove([0,-v:count1])<CR>
nnoremap <silent> <C-Down> :<C-U>call <SID>DebugMove([0,v:count1])<CR>
nnoremap <silent> <C-Left> :<C-U>call <SID>DebugMove([-v:count1,0])<CR>
nnoremap <silent> <C-Right> :<C-U>call <SID>DebugMove([v:count1,0])<CR>

for i in range(1,100)
	execute("normal! i" . i . "\<CR>\<ESC>")
endfor
execute("normal! 50G")
MultiplayerConnect

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

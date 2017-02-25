let s:players = {}

let s:read_buffer = []
let s:player_profile = {}
let s:profile_file = ""

function! multiplayer#LoadProfile(ip)
	let s:profile_file = g:multiplayer_profiles_path . "profile_" . a:ip . ".vim"
	if filereadable(s:profile_file)
		execute "let s:player_profile = " . readfile(s:profile_file)[0]
		for key in keys(s:player_profile)
			execute "let " . key . "=" . s:player_profile[key]
		endfor
	endif
endfunction

function! multiplayer#StatusLine()
	let ret  = "%#MPCol1#%{MultiplayerName(0)}%*"
	let ret .= "%#MPCol2#%{MultiplayerName(1)}%*"
	let ret .= "%#MPCol4#%{MultiplayerName(2)}%*"
	let ret .= "%#MPCol1#%{MultiplayerName(3)}%*"
	let ret .= "%#MPCol2#%{MultiplayerName(4)}%*"
	let ret .= "%#MPCol4#%{MultiplayerName(5)}%*"
	let ret .= "%#MPCol1#%{MultiplayerName(6)}%*"
	let ret .= "%#MPCol2#%{MultiplayerName(7)}%*"
	let ret .= "%#MPCol4#%{MultiplayerName(8)}%*"
	return ret
endfunction

function! multiplayer#Connect()
	let s:players[getpid()] = {"name": g:multiplayer_name, "file": "", "mode": "n", "range": [1,1,1,1]}
	command -nargs=1 MultiplayerChat call <SID>Chat("<args>")
	command -nargs=? MultiplayerLet call <SID>Let("<args>")
	command -nargs=0 MultiplayerDisconnect call <SID>Disconnect()
	command -nargs=0 MultiplayerConfigure call <SID>Configure()
	delcommand MultiplayerConnect
	augroup MultiplayerAuGroup
		autocmd!
		autocmd VimLeave * call <SID>Disconnect()
		autocmd TextChanged * call <SID>TextChanged()
		autocmd TextChangedI * call <SID>TextChanged()
		autocmd CursorMoved * call <SID>CursorMoved()
		autocmd CursorMovedI * call <SID>CursorMoved()
		autocmd BufEnter * call <SID>Write()
		autocmd BufWritePost * call <SID>BufWritePost()
	augroup END
	call <SID>Write()
	let my_pid = getpid()
	call system('mkfifo /tmp/vim_multi_player_pipe_' . my_pid)
	let s:sleep_job = job_start(['/bin/sh', '-c', 'sleep infinity > /tmp/vim_multi_player_pipe_' . my_pid])
	sleep 100m " make sure sleep keeps the cat alive
	call job_start('cat /tmp/vim_multi_player_pipe_' . my_pid, {"out_cb": function("s:MyHandlerOut")})
	call <SID>SendBroadcastMsg('hello', [])
	call <SID>CursorMoved()
	call <SID>MapAll()
endfunction


function! multiplayer#SwapExists(swapname)
	if has_key(s:players, getpid()) != 0
		let v:swapchoice = 'e'
		return
	endif

	let answer = confirm("Swap file \"" . a:swapname . "\" already exists!", "&Open Read-Only\nEdit anyway\n&Recover\n&Quit\n&Abort\n&Multiplayer", 1)
	if answer == 1
		let v:swapchoice = 'o'
	elseif answer == 2
		let v:swapchoice = 'e'
	elseif answer == 3
		let v:swapchoice = 'r'
	elseif answer == 4
		let v:swapchoice = 'q'
	elseif answer == 5
		let v:swapchoice = 'a'
	elseif answer == 6
		call multiplayer#Connect()
		let v:swapchoice = 'e'
	else
		let v:swapchoice = 'o'
	endif
endfunction

function! MultiplayerName(n)
	let players = <SID>GetPlayers('')
	if count(players, getpid()) == 0
		return ''
	elseif a:n >= len(players)
		return ''
	elseif players[a:n] == getpid()
		return ">" . <SID>GetFullNameFromPid(players[a:n]) . "<"
	else
		return <SID>GetFullNameFromPid(players[a:n])
endfunction

function! s:Write()
	let s:bu1 = getline(1,'$')
endfunction

function! s:BufWritePost()
	call <SID>SendMulticastMsg('written', [expand('<afile>')])
endfunction

function! s:Chat(chat_msg)
	let x = getpos(".")[2]
	let y = getpos(".")[1]
	call <SID>SendMulticastMsg('chat', [expand('%'), x, y, a:chat_msg])
	call <SID>AddToChatHistory(expand("%"), x, y, getpid(), a:chat_msg, 0)
endfunction

function! s:Let(key_value)
	if a:key_value == ''
		"list all values:
		for key in keys(s:player_profile)
			call s:Let(key)
		endfor
		return
	endif
	let spl = split(a:key_value, '=')
	if len(spl) == 1
		"list one values:
		if has_key(s:player_profile, a:key_value)
			if len(a:key_value) < 20
				let alignment = repeat(" ", 20 - len(a:key_value))
			else
				let alignment = ""
			endif
			echo a:key_value . alignment . "  " . s:player_profile[a:key_value]
		else
			echoe "Undefined variable: " . a:key_value
		endif
		return
	endif
	"assign one values:
	let key = spl[0]
	let value = join(spl[1:], '=')
	let do_remap = count(['g:multiplayer_nmap_leader', 'g:multiplayer_cmap_leader', 'g:multiplayer_imap_leader', 'g:multiplayer_chat_mapping'], key)
	if do_remap | call <SID>UnmapAll() | endif
	execute "let " . key . "=" . value
	if do_remap | call <SID>MapAll() | endif
	if key == 'g:multiplayer_name'
		execute "let s:players[getpid()].name = " . value
		call <SID>SendMulticastMsg('iam', [<SID>GetNameFromPid(getpid())])
		redrawstatus
	endif
	let s:player_profile[key] = value
endfunction

function! s:Configure()
	let name = input("Enter your name:", g:multiplayer_name)
	call <SID>Let("g:multiplayer_name='" . name . "'")

	let leader = input("Enter your normal mode map leader, e.g. <F4>, <C-Q> or mm:", g:multiplayer_nmap_leader)
	call <SID>Let("g:multiplayer_nmap_leader='" . leader . "'")

	let leader = input("Enter your command-line mode map leader, e.g. <F4>, <C-Q> or mm:", g:multiplayer_cmap_leader)
	call <SID>Let("g:multiplayer_cmap_leader='" . leader . "'")

	let leader = input("Enter your insert mode map leader, e.g. <F4>, <C-Q> or mm:", g:multiplayer_imap_leader)
	call <SID>Let("g:multiplayer_imap_leader='" . leader . "'")

	let auto = input("Enter auto connect (y/n):", g:multiplayer_auto_connect)
	call <SID>Let("g:multiplayer_auto_connect='" . auto . "'")

	let chat_mapping = input("Enter your chat mapping, e.g. <CR>:", g:multiplayer_chat_mapping)
	call <SID>Let("g:multiplayer_chat_mapping='" . chat_mapping . "'")

	let chat_dest = input("Enter your chat destination [clemCLEM]:", g:multiplayer_chat_destination)
	call <SID>Let("g:multiplayer_chat_destination='" . chat_dest . "'")
endfunction

function! s:Disconnect()
	call <SID>UnmapAll()
	call <SID>SendMulticastMsg('byebye', [])
	let my_pid = getpid()
	call system('rm /tmp/vim_multi_player_pipe_' . my_pid)
	augroup MultiplayerAuGroup
		autocmd!
	augroup END
	if s:profile_file != ''
		call writefile([string(s:player_profile)], s:profile_file)
	endif
	call job_stop(s:sleep_job)
	command -nargs=0 MultiplayerConnect call multiplayer#Connect()
	delcommand MultiplayerDisconnect
	delcommand MultiplayerConfigure
	delcommand MultiplayerChat
	delcommand MultiplayerLet
	let s:players = {}
endfunction

function! s:CursorMoved()
	let mode = mode()
	let range = [virtcol("."), getpos(".")[1], virtcol("v"), getpos("v")[1]]
	if mode != s:players[getpid()].mode || range != s:players[getpid()].range
		let s:players[getpid()].mode = mode
		let s:players[getpid()].range = range
		call <SID>SendMulticastMsg('cursor', [expand('%'), mode] + range)
	endif
endfunction


function! s:TextChanged()
	"echom "Text Changed"
	let my_pid = getpid()

	let s:bu2 = s:bu1
	call <SID>Write()
	call writefile(s:bu1, '/tmp/.bu1' . my_pid)
	call writefile(s:bu2, '/tmp/.bu2' . my_pid)

	let diff = split(system('diff /tmp/.bu2' . my_pid . ' /tmp/.bu1' . my_pid), '\n')
	call delete('/tmp/.bu1' . my_pid)
	call delete('/tmp/.bu2' . my_pid)
	if len(diff)
		"echom 'I have changes' . string(diff)
		call <SID>SendMulticastMsg('diff', [expand('%')] + diff)
	endif
endfunction


function! s:SendUnicastMsg(command, msg, recv_pid)
	call writefile([string([a:command, getpid(), len(a:msg)] + a:msg)], "/tmp/vim_multi_player_pipe_" . a:recv_pid)
endfunction

function! s:SendMulticastMsg(command, msg)
	let my_pid = getpid()
	for pid in keys(s:players)
		if pid != my_pid
			call <SID>SendUnicastMsg(a:command, a:msg, pid)
		endif
	endfor
endfunction

function! s:SendBroadcastMsg(command, msg)
	let all_pipes = split(globpath('/tmp', 'vim_multi_player_pipe_*'), '\n')
	for pipe in all_pipes
		let mtch = matchlist(pipe, '.*vim_multi_player_pipe_\(.*\)')
		if len(mtch) >= 2 && mtch[1] != getpid()
			call <SID>SendUnicastMsg(a:command, a:msg, mtch[1])
		endif
	endfor
endfunction

function! s:MyHandlerOut(channel, msg)
	execute "let m = " . a:msg
	call <SID>ParseMsg(m)
endfunction

function! s:ParseMsg(msg)
	let command = a:msg[0]
	let pid = a:msg[1]
	let msglen = a:msg[2]
	let msg = a:msg[3:msglen + 3 - 1]
	let rest = a:msg[msglen + 3:]
	if command == 'cursor'
		let file = msg[0]
		let mode = msg[1]
		let x0 = msg[2]
		let y0 = msg[3]
		let x1 = msg[4]
		let y1 = msg[5]
		"echom "received cursor: " . file . " " . mode . ' ' . x0 . ' ' . y0 . ' ' . x1 . ' ' . y1
		let files = [file]
		if has_key(s:players, pid) && count(files, s:players[pid].file) == 0
			call add(files, s:players[pid].file)
		endif
		let s:players[pid].file = file
		let s:players[pid].mode = mode
		if y0 < y1 || (y0 == y1 && x0 < x1)
			let s:players[pid].range = [x0, y0, x1, y1]
		else
			let s:players[pid].range = [x1, y1, x0, y0]
		endif
		call <SID>DrawCursors(files)
	elseif command == 'hello'
		"echom "received hello: " . string(pid)
		"echom "I would like to send iam " . <SID>GetNameFromPid(getpid()) . " to " . pid
		"echom "sending cursor" . string(s:players[getpid()].range)
		let s:players[pid] = {"name": "", "file": "", "mode": "n", "range": [1,1,1,1]}
		call <SID>SendUnicastMsg('hello_reply', [], pid)
		call <SID>SendUnicastMsg('iam', [<SID>GetNameFromPid(getpid())], pid)
		call <SID>SendUnicastMsg('cursor', [expand('%'), s:players[getpid()].mode] + s:players[getpid()].range, pid)
	elseif command == 'hello_reply'
		"echom "received hello_reply: " . string(pid)
		let s:players[pid] = {"name": "", "file": "", "mode": "n", "range": [1,1,1,1]}
		call <SID>SendUnicastMsg('iam', [<SID>GetNameFromPid(getpid())], pid)
		call <SID>SendUnicastMsg('cursor', [expand('%'), s:players[getpid()].mode] + s:players[getpid()].range, pid)
	elseif command == 'iam'
		"echom "received iam: " . string(pid) . '-' . string(msg[0])
		let s:players[pid].name = msg[0]
		redrawstatus
	elseif command == 'byebye'
		let byefile = s:players[pid].file
		unlet s:players[pid]
		call <SID>DrawCursors([byefile])
		redrawstatus
	elseif command == 'written'
		let written_as = msg[0]
		call <SID>BuffDo(written_as, { -> execute("edit!", "") })
	elseif command == 'chat'
		let file = msg[0]
		call <SID>AddToChatHistory(file, msg[1], msg[2], pid, msg[3], 1)
	elseif command == 'request_register'
		let register = msg[1]
		let operation = msg[0]
		"echom "received request_register: reg ='" . register . "', operation = '" . operation . "', from '" . pid
		if register == 'A' || register == 'B'
			let register_value = escape(expand("<cword>"), '/$.*\{[^')
			if register == 'B' && match(register_value, "\\k") != -1
				let register_value = '\<' . register_value . '\>'
			endif
			let register_type = 'v'
			"echom "replying: " . ' ' . operation . register_value . ' to ' . pid
			call <SID>SendUnicastMsg('reply_register', [operation, register_value, register_type], pid)
		elseif register == 'q/' || register == 'q?' || register == 'q:'
			let history = [histget('/', -3), histget('/', -2), histget('/', -1)]
			"echom "replying history: " . ' ' . string([operation] + history) . ' to ' . pid
			call <SID>SendUnicastMsg('reply_history', [operation] + history, pid)
		else
			let register_value = getreg(register)
			let register_type = getregtype(register)
			"echom "replying: " . ' ' . operation . register_value . ' to ' . pid
			call <SID>SendUnicastMsg('reply_register', [operation, register_value, register_type], pid)
		endif
	elseif command == 'reply_register'
		let operation = msg[0]
		let register_value = msg[1]
		let register_type = msg[2]
		"echom "received reply_register: operation ='" . operation . "', register_value = '" . register_value . "', from '" . pid
		if operation == 'p' || operation == 'P'
			let a = @a
			call setreg('a', register_value, register_type)
			silent execute "normal! \"a" . operation
			let @a = a
		elseif operation == '/' || operation == '?' || operation == ':'
			call feedkeys(operation . register_value)
		elseif operation == 'c'
			call feedkeys(register_value)
		endif
	elseif command == 'reply_history'
		let operation = msg[0]
		let history = msg[1:]
		"echom "received reply_history: operation ='" . operation . "', history = '" . string(history) . "', from '" . pid
		for h in history
			call histadd(operation[1], h)
		endfor
		call feedkeys(operation)
		augroup CmdwinLeaveAuGroup
			autocmd!
			execute "autocmd CmdwinLeave * call <SID>CmdWinLeave('" . operation[1] . "')"
		augroup END
	elseif command == 'diff'
		let file = msg[0]
		"echom "received changes" . string(msg[1:])
		"let wv = winsaveview()
		call <SID>BuffDo(file, { -> <SID>Patch(msg[1:]) })
		call <SID>Write()
		"call winrestview(wv)
	else
		echom "Unknown command received: '" . command . "'"
	endif
	if len(rest) > 0
		call <SID>ParseMsg(rest)
	endif
endfunction

function s:CmdWinLeave(hist)
	call histdel(a:hist, -1)
	call histdel(a:hist, -1)
	call histdel(a:hist, -1)
	augroup CmdwinLeaveAuGroup
		autocmd!
	augroup END
endfunction

function! s:Patch(patch)
	let pos = getpos(".")
	let my_pid = getpid()
	call writefile(a:patch, '/tmp/vim_multi_player_tmp_' .my_pid)
	call writefile(getline(1,'$'), '/tmp/.bu1' . my_pid)
	call system('cat /tmp/vim_multi_player_tmp_' . my_pid . ' | patch /tmp/.bu1' . my_pid . ' 2>&1')
	silent execute ":%!cat /tmp/.bu1" . my_pid
	call delete('/tmp/vim_multi_player_tmp_' . my_pid)
	call delete('/tmp/.bu1' . my_pid)
	call setpos(".", pos)
endfunction

function! s:InputOther()
	let the_others = <SID>GetPlayers(getpid())
	if len(the_others) == 0
		return 0
	elseif len(the_others) == 1
		return the_others[0]
	else
		let num = 0
		for other in the_others
			execute "echohl MPCol" . <SID>GetPlayerPower(other)
			echon "(" . num . ")"
			echon <SID>GetFullNameFromPid(other)
			let num = num + 1
		endfor
		echohl None
		echon "?"
		let answer = getchar() - 48
		if answer < 0 || answer >= len(the_others)
			return 0
		endif
		return the_others[answer]
	endif
endfunction

function! s:Put(register, operation)
	let other = s:InputOther()
	if other == 0
		return ''
	endif

	"echom "you asked for register '" . a:register . "' from '" . other . "!"
	call <SID>SendUnicastMsg('request_register', [a:operation, a:register], other)
	return ''
endfunction

function! s:GoToPlayer()
	let other = s:InputOther()
	if other == 0
		return ''
	endif
	execute "edit " . s:players[other].file
	let bufnum = bufnr(s:players[other].file)
	let lnum = s:players[other].range[1]
	let col = s:players[other].range[0]
	call setpos('.', [bufnum, lnum, col, 0])
endfunction


function! s:AddToChatHistory(file, x, y, pid, chat_msg, incoming)
	if (a:incoming && g:multiplayer_chat_destination =~# 'e') || (!a:incoming && g:multiplayer_chat_destination =~# 'E')
		execute "echohl MPCol" . <SID>GetPlayerPower(a:pid)
		redraw
		echon <SID>GetFullNameFromPid(a:pid)
		echohl None
		echon "> " . a:chat_msg
	endif
	if (a:incoming && g:multiplayer_chat_destination =~# 'm') || (!a:incoming && g:multiplayer_chat_destination =~# 'M')
		echom <SID>GetFullNameFromPid(a:pid) . "> " . a:chat_msg
	endif
	if (a:incoming && g:multiplayer_chat_destination =~# 'c') || (!a:incoming && g:multiplayer_chat_destination =~# 'C')
		caddexpr a:file . ":" . a:y . ":" . a:x . ":" . <SID>GetFullNameFromPid(a:pid) . "> " . a:chat_msg
		cbottom
	endif
	if (a:incoming && g:multiplayer_chat_destination =~# 'l') || (!a:incoming && g:multiplayer_chat_destination =~# 'L')
		laddexpr a:file . ":" . a:y . ":" . a:x . ":" . <SID>GetFullNameFromPid(a:pid) . "> " . a:chat_msg
		lbottom
	endif
endfunction


function! s:MapAll()
	if g:multiplayer_chat_mapping != ''
		execute "nnoremap " . g:multiplayer_chat_mapping . " :MultiplayerChat "
	endif
	if g:multiplayer_nmap_leader != ''
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "p :call <SID>Put(v:register, 'p')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "P :call <SID>Put(v:register, 'P')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "/ :call <SID>Put('/', '/')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "? :call <SID>Put('/', '?')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "* :call <SID>Put('B', '/')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "# :call <SID>Put('B', '?')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "g* :call <SID>Put('A', '/')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "g# :call <SID>Put('A', '?')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "q/ :call <SID>Put('q/', 'q/')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "q? :call <SID>Put('q/', 'q?')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . ": :call <SID>Put(':', ':')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "q: :call <SID>Put('q:', 'q:')<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "g. :call <SID>GoToPlayer()<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "g% :echom \"<l>g% not implemented yet\"<CR>"
		execute "nnoremap <silent> " . g:multiplayer_nmap_leader . "gv :echom \"<l>gv not implemented yet\"<CR>"
	endif
	if g:multiplayer_cmap_leader != ''
		execute "cnoremap <silent> " . g:multiplayer_cmap_leader . "<C-R> <C-R>=<SID>Put(nr2char(getchar()), 'c')<CR>"
	endif
	if g:multiplayer_imap_leader != ''
		execute "inoremap <silent> " . g:multiplayer_imap_leader . "<C-R> <C-R>=<SID>Put(nr2char(getchar()), 'c')<CR>"
	endif
endfunction

function! s:UnmapAll()
	if g:multiplayer_chat_mapping != ''
		execute "nunmap " . g:multiplayer_chat_mapping
	endif
	if g:multiplayer_nmap_leader != ''
		execute "nunmap " . g:multiplayer_nmap_leader . "p"
		execute "nunmap " . g:multiplayer_nmap_leader . "P"
		execute "nunmap " . g:multiplayer_nmap_leader . "/"
		execute "nunmap " . g:multiplayer_nmap_leader . "?"
		execute "nunmap " . g:multiplayer_nmap_leader . "*"
		execute "nunmap " . g:multiplayer_nmap_leader . "#"
		execute "nunmap " . g:multiplayer_nmap_leader . "g*"
		execute "nunmap " . g:multiplayer_nmap_leader . "g#"
		execute "nunmap " . g:multiplayer_nmap_leader . "q/"
		execute "nunmap " . g:multiplayer_nmap_leader . "q?"
		execute "nunmap " . g:multiplayer_nmap_leader . ":"
		execute "nunmap " . g:multiplayer_nmap_leader . "q:"
		execute "nunmap " . g:multiplayer_nmap_leader . "g."
		execute "nunmap " . g:multiplayer_nmap_leader . "g%"
		execute "nunmap " . g:multiplayer_nmap_leader . "gv"
	endif
	if g:multiplayer_cmap_leader != ''
		execute "cunmap " . g:multiplayer_cmap_leader . "<C-R>"
	endif
	if g:multiplayer_imap_leader != ''
		execute "iunmap " . g:multiplayer_imap_leader . "<C-R>"
	endif
endfunction

function! s:DrawCursors(files)
	let oldnr = winnr()
	for w in range(1, winnr('$'))
		exec w.'wincmd w'
		for m in getmatches()
			if match(m.group, "MPCol") == 0
				call matchdelete(m.id)
			endif
		endfor
	endfor
	exec oldnr.'wincmd w'

	for f in a:files
		let state = 0
		for y in <SID>AllCursorLines(f)
			let events = <SID>GetEvents(y, f)
			let xs = []
			for xx in keys(events)
				call add(xs, xx + 0)
			endfor
			for x in sort(xs, 'n')
				for pid in keys(events[x])
					let ev = events[x][pid]
					if state
						call <SID>BuffDoAll(f, { -> matchadd('MPCol' . state, '\%>' . string(xo-1) . 'v\%<' . x . 'v\%' . y . 'l') })
					endif
					let xo = x
					let playerPower = <SID>GetPlayerPower(pid)
					if ev == 'start'
						let state = or(state, playerPower)
					elseif ev == 'end'
						let state = and(state, 65535 - playerPower)
					endif
				endfor
			endfor
		endfor
	endfor
endfunction

function! s:GetEvents(line, file)
	let events = {}
	for pid in keys(s:players)
		if s:players[pid].file == a:file
			if s:players[pid].mode == 'v'
				if a:line == s:players[pid].range[1]
					call <SID>AddEvent(events, s:players[pid].range[0], pid, 'start')
				endif
				if a:line >= s:players[pid].range[1] && a:line < s:players[pid].range[3]
					call <SID>AddEvent(events, 1000, pid, 'end')
				endif
				if a:line > s:players[pid].range[1] && a:line <= s:players[pid].range[3]
					call <SID>AddEvent(events, 1, pid, 'start')
				endif
				if a:line == s:players[pid].range[3]
					call <SID>AddEvent(events, s:players[pid].range[2] + 1, pid, 'end')
				endif
			elseif s:players[pid].mode == 'V'
				if a:line >= s:players[pid].range[1] && a:line <= s:players[pid].range[3]
					call <SID>AddEvent(events, 1, pid, 'start')
					call <SID>AddEvent(events, 1000, pid, 'end')
				endif
			elseif s:players[pid].mode == ''
				let minx = min([s:players[pid].range[0], s:players[pid].range[2]])
				let maxx = max([s:players[pid].range[0], s:players[pid].range[2]])
				if a:line >= s:players[pid].range[1] && a:line <= s:players[pid].range[3]
					call <SID>AddEvent(events, minx, pid, 'start')
					call <SID>AddEvent(events, maxx + 1, pid, 'end')
				endif
			elseif s:players[pid].mode == 'n' || s:players[pid].mode == 'i'
				if a:line == s:players[pid].range[1]
					call <SID>AddEvent(events, s:players[pid].range[0], pid, 'start')
					call <SID>AddEvent(events, s:players[pid].range[0]+1, pid, 'end')
				endif
			endif
		endif
	endfor
	return events
endfunction

function! s:GetNameFromPid(pid)
	if has_key(s:players, a:pid)
		return s:players[a:pid].name
	endif
	return 'Noname'
endfunction

function! s:GetFullNameFromPid(pid)
	let name = <SID>GetNameFromPid(a:pid)
	let players = <SID>GetPlayers('')
	let num = 0
	for player in players
		if player == a:pid
			let mynum = num
		endif
		if (has_key(s:players, player) && s:players[player].name == name) || (!has_key(s:players, player) && name == 'noname')
			let num = num + 1
		endif
	endfor
	if num > 1
		let name = name . mynum
	endif
	return name
endfunction

function! s:GetPlayers(my_pid)
	let the_others = keys(s:players)
	call filter(the_others, 'v:val != a:my_pid')
	for i in range(len(the_others))
		let the_others[i] = the_others[i] + 0
	endfor
	return sort(the_others, 'n')
endfunction

function! s:GetPlayerPower(pid)
	let players = <SID>GetPlayers('')
	let power = 1
	for pid in players
		if pid == a:pid
			while power >= 8
				let power = power / 8
			endwhile
			return power
		endif
		let power = power*2
	endfor
	return 0
endfunction


function! s:AllCursorLines(file)
	let ret = []
	for pid in keys(s:players)
		if a:file == s:players[pid].file && pid != getpid()
			let ret += range(s:players[pid].range[1], s:players[pid].range[3])
		endif
	endfor
	call sort(ret, 'n')
	return ret
endfunction

function! s:AddEvent(events, x, pid, event)
	if !has_key(a:events, a:x)
		let a:events[a:x] = {}
	endif
	let a:events[a:x][a:pid] = a:event
endfunction


"echom BuffDo('x.txt',{ -> matchaddpos('MyGroup', [[2, 2,4]])})
""call BuffDo(1,{ -> execute("call setline(3, 'text')", "")})
function! s:BuffDoAll(expr, lambda)
	let oldnr = winnr()
	for w in range(1, winnr('$'))
		if bufnr(a:expr) == winbufnr(w)
			exec w.'wincmd w'
			let ret = a:lambda()
		endif
	endfor
	exec oldnr.'wincmd w'
endfunction

function! s:BuffDo(expr, lambda)
	let oldnr = winnr()
	let winnr = bufwinnr(a:expr)

	if oldnr != winnr
		if winnr == -1
			let bufnr = bufnr(a:expr)
			if bufnr == -1
				return
			endif
			silent exec "sp ".escape(bufname(bufnr), ' \')
			let ret = a:lambda()
			silent hide
		else
			exec winnr.'wincmd w'
			let ret = a:lambda()
		endif
	else
		let ret = a:lambda()
	endif
	exec oldnr.'wincmd w'
	return ret
endfunction

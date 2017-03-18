" Vim Multiplayer Marts 2017
" Usage:
" :help Multiplayer
" Author:
"   Rolf Asmund

function! multiplayer#Connect(profile_file, player_profile)
	let s:profile_file = a:profile_file
	let s:player_profile = a:player_profile
	let s:read_buffer = []
	let s:remote_history = 0
	let s:in_cmdwin = 0
	let s:msg_queue = []
	let s:players = {}
	let s:players[getpid()] = {"name": g:multiplayer_name, "file": "", "mode": "n", "range": [1,1,1,1], "highlight": g:multiplayer_highlight}
	call <SID>UpdateHighlight(getpid())
	command -nargs=1 MultiplayerChat call <SID>Chat("<args>")
	command -nargs=? MultiplayerLet call <SID>Let("<args>")
	command -nargs=0 MultiplayerDisconnect call <SID>Disconnect()
	command -nargs=0 MultiplayerConfigure call <SID>Configure()
	command -nargs=0 MultiplayerLs call <SID>Ls()
	delcommand MultiplayerConnect
	augroup MultiplayerAuGroup
		autocmd!
		autocmd VimLeave * call <SID>Disconnect()
		autocmd TextChanged * call <SID>TextChanged()
		autocmd TextChangedI * call <SID>TextChanged()
		autocmd CursorMoved * call <SID>CursorMoved()
		autocmd CursorMovedI * call <SID>CursorMoved()
		autocmd BufEnter * call <SID>BufEnter()
		autocmd BufWritePost * call <SID>BufWritePost()
		autocmd CmdwinEnter * call <SID>CmdWinEnter()
		autocmd CmdwinLeave * call <SID>CmdWinLeave()
	augroup END
	let s:players[getpid()].file = expand('%:p')
	let mode = mode()
	let range = [virtcol("."), getpos(".")[1], virtcol("v"), getpos("v")[1]]
	let s:players[getpid()].mode = mode
	let s:players[getpid()].range = range
	call <SID>Write()
	let my_pid = getpid()
	call system('mkfifo /tmp/vim_multi_player_pipe_' . my_pid)
	let s:sleep_job = job_start(['/bin/sh', '-c', 'sleep infinity > /tmp/vim_multi_player_pipe_' . my_pid])
	sleep 100m " make sure sleep keeps the cat alive
	call job_start('cat /tmp/vim_multi_player_pipe_' . my_pid, {"out_cb": function("s:MyHandlerOut")})
	call <SID>SendBroadcastMsg('hello', [])
	call <SID>MapAll()
	call <SID>UpdateStatusLine()
endfunction

function! s:BufEnter()
	"echom "BufEnter"
	let s:players[getpid()].file = expand('%:p')
	call <SID>SendMulticastMsg('file', [s:players[getpid()].file])
	call <SID>Write()
endfunction

function! s:Write()
	let s:bu1 = getline(1,'$')
endfunction

function! s:BufWritePost()
	call <SID>SendMulticastMsg('written', [expand('<afile>:p')])
endfunction

function! s:Chat(chat_msg)
	let x = getpos(".")[2]
	let y = getpos(".")[1]
	call <SID>SendMulticastMsg('chat', [s:players[getpid()].file, x, y, a:chat_msg])
	call <SID>AddToChatHistory(s:players[getpid()].file, x, y, getpid(), a:chat_msg, 0)
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
		call <SID>SendMulticastMsg('iam', [s:players[getpid()].name])
		redrawstatus
	endif
	if key == 'g:multiplayer_highlight'
		execute "let s:players[getpid()].highlight = " . value
		call <SID>UpdateHighlight(getpid())
		call <SID>SendMulticastMsg('highlight', [s:players[getpid()].highlight])
		redrawstatus
	endif
	let s:player_profile[key] = value
endfunction

function! s:UpdateHighlight(pid)
	let mode = s:players[a:pid].highlight[0]
	let fg = s:players[a:pid].highlight[1]
	let bg = s:players[a:pid].highlight[2]
	execute("highlight MPCol" . a:pid . " term=inverse cterm=" . mode . " ctermfg=" . fg . " ctermbg=" . bg . " gui=" . mode . " guifg=" . fg . " guibg=" . bg)
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

	let highlight_mode = g:multiplayer_highlight[0]
	let highlight_fg = g:multiplayer_highlight[1]
	let highlight_bg = g:multiplayer_highlight[2]
	let highlight_mode = input("Enter your highlight mode, e.g. inverse:", highlight_mode)
	let highlight_fg = input("Enter your highlight fg, e.g. Red:", highlight_fg)
	let highlight_bg = input("Enter your highlight bg, e.g. White:", highlight_bg)
	call <SID>Let("g:multiplayer_highlight=" . string([highlight_mode, highlight_fg, highlight_bg]) . "")
endfunction

function! s:Ls()
	echo ""
	let first = 1
	let cwd = getcwd() . '/'
	let l_cwd = len(cwd)
	for pid in sort(keys(s:players), 'N')
		if !first
			echon "\n"
		endif
		let first = 0
		let l_name = len(<SID>GetFullNameFromPid(pid))
		let file = s:players[pid].file
		if file[0:l_cwd-1] == cwd
			let file = file[l_cwd:]
		endif
		let l_file = len(file)
		call <SID>EchoHlPlayer(pid)
		echohl None
		if l_name < 10
			echon repeat(' ', 10-l_name)
		endif
		echon ' "' . file . '"'
		if l_file < 28
			echon repeat(' ', 28-l_file)
		endif
		echon ' line ' . s:players[pid].range[1] . ', col ' . s:players[pid].range[0]
	endfor
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
	command -nargs=0 MultiplayerConnect call multiplayer#Connect(s:profile_file, s:player_profile)
	delcommand MultiplayerDisconnect
	delcommand MultiplayerConfigure
	delcommand MultiplayerChat
	delcommand MultiplayerLet
	delcommand MultiplayerLs
	let s:players = {}
	call <SID>UpdateStatusLine()
endfunction

function! s:CursorMoved()
	let mode = mode()
	let range = [virtcol("."), getpos(".")[1], virtcol("v"), getpos("v")[1]]
	if mode != s:players[getpid()].mode || range != s:players[getpid()].range
		let s:players[getpid()].mode = mode
		let s:players[getpid()].range = range
		call <SID>SendMulticastMsg('cursor', [mode] + range)
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
		call <SID>SendMulticastMsg('diff', [s:players[getpid()].file] + diff)
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
	if s:in_cmdwin
		let s:msg_queue += [m]
	else
		for qm in s:msg_queue
			call <SID>ParseMsg(qm)
		endfor
		let s:msg_queue = []
		call <SID>ParseMsg(m)
	endif
endfunction

function! s:ParseMsg(msg)
	let command = a:msg[0]
	let pid = a:msg[1]
	let msglen = a:msg[2]
	let msg = a:msg[3:msglen + 3 - 1]
	let rest = a:msg[msglen + 3:]
	if command == 'cursor'
		let mode = msg[0]
		let x0 = msg[1]
		let y0 = msg[2]
		let x1 = msg[3]
		let y1 = msg[4]
		"echom "received cursor: " . mode . ' ' . x0 . ' ' . y0 . ' ' . x1 . ' ' . y1
		call <SID>RemoveCursor(pid)
		let s:players[pid].mode = mode
		if y0 < y1 || (y0 == y1 && x0 < x1)
			let s:players[pid].range = [x0, y0, x1, y1]
		else
			let s:players[pid].range = [x1, y1, x0, y0]
		endif
		if g:multiplayer_auto_split == 'y'
			call <SID>UpdateSplits()
		endif
		call <SID>DrawCursor(pid)
	elseif command == 'hello'
		"echom "received hello: " . string(pid)
		"echom "I would like to send iam " . s:players[getpid()].name . " to " . pid
		"echom "sending cursor" . string(s:players[getpid()].range)
		let s:players[pid] = {"name": "", "file": "", "mode": "n", "range": [1,1,1,1], "highlight":["","",""]}
		execute("highlight MPCol" . pid . " none")
		call <SID>SendUnicastMsg('hello_reply', [], pid)
		call <SID>SendUnicastMsg('iam', [s:players[getpid()].name], pid)
		call <SID>SendUnicastMsg('file', [s:players[getpid()].file], pid)
		call <SID>SendUnicastMsg('cursor', [s:players[getpid()].mode] + s:players[getpid()].range, pid)
		call <SID>SendUnicastMsg('highlight', [s:players[getpid()].highlight], pid)
		call <SID>UpdateStatusLine()
	elseif command == 'hello_reply'
		"echom "received hello_reply: " . string(pid)
		let s:players[pid] = {"name": "", "file": "", "mode": "n", "range": [1,1,1,1], "highlight":["","",""]}
		execute("highlight MPCol" . pid . " none")
		call <SID>SendUnicastMsg('iam', [s:players[getpid()].name], pid)
		call <SID>SendUnicastMsg('file', [s:players[getpid()].file], pid)
		call <SID>SendUnicastMsg('cursor', [s:players[getpid()].mode] + s:players[getpid()].range, pid)
		call <SID>SendUnicastMsg('highlight', [s:players[getpid()].highlight], pid)
		call <SID>UpdateStatusLine()
	elseif command == 'iam'
		"echom "received iam: " . string(pid) . '-' . string(msg[0])
		let s:players[pid].name = msg[0]
		call <SID>UpdateStatusLine()
		redrawstatus
	elseif command == 'highlight'
		"echom "received highlight: " . string(pid) . ' ' . string(msg[0])
		let s:players[pid].highlight = msg[0]
		call <SID>UpdateHighlight(pid)
		if pid < getpid() && msg[0] == s:players[getpid()].highlight
			call <SID>SetFirstAvailableHighlight()
		end
		call <SID>UpdateStatusLine()
		redrawstatus
	elseif command == 'file'
		let file = msg[0]
		call <SID>RemoveCursor(pid)
		let s:players[pid].file = file
		call <SID>DrawCursor(pid)
	elseif command == 'byebye'
		call <SID>RemoveCursor(pid)
		unlet s:players[pid]
		call <SID>UpdateStatusLine()
		redrawstatus
	elseif command == 'written'
		let written_as = msg[0]
		call <SID>BuffDo(written_as, { -> execute("edit!", "") })
	elseif command == 'chat'
		let file = msg[0]
		let x = msg[1]
		let y = msg[2]
		let chat_msg = msg[3]
		call <SID>AddToChatHistory(file, x, y, pid, chat_msg, 1)
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
			"echom "cmdwinheight = " . string(&cmdwinheight)
			let history = []
			for i in range(-&cmdwinheight, -1)
				let history += [histget(register[1], i)]
			endfor
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
		let s:remote_history = 1
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

function! s:SetFirstAvailableHighlight()
	let highlights = [
		\ ['inverse', 'Red', 'White'],
		\ ['inverse', 'Green', 'White'],
		\ ['inverse', 'Blue', 'White'],
		\ ['inverse', 'Cyan', 'White'],
		\ ['inverse', 'Magenta', 'White']
		\ ]
	for h in highlights
		let good = 1
		for player in keys(s:players)
			if s:players[player].highlight == h
				let good = 0
			endif
		endfor
		if good
			let s:players[getpid()].highlight = h
			call <SID>UpdateHighlight(getpid())
			call <SID>SendMulticastMsg('highlight', [s:players[getpid()].highlight])
			return
		endif
	endfor
endfunction

function! s:CmdWinEnter()
	"echom "CmdWinEnter"
	let s:in_cmdwin = 1
endfunction

function! s:CmdWinLeave()
	"echom "CmdWinLeave"
	if s:remote_history_size != 0
		let hist = expand("<afile>")
		for i in range(-&cmdwinheight, -1)
			call histdel(hist, -1)
		endfor
	endif
	let s:remote_history_size = 0
	let s:in_cmdwin = 0
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

function! s:EchoHlPlayer(pid)
	execute "echohl MPCol" . a:pid
	echon <SID>GetFullNameFromPid(a:pid)
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
			call <SID>EchoHlPlayer(other)
			echon "(" . num . ")"
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
		call <SID>EchoHlPlayer(a:pid)
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

function! s:RemoveCursorPart(pid)
	for m in getmatches()
		if m.group == "MPCol" . a:pid
			call matchdelete(m.id)
		endif
	endfor
endfunction

function! s:RemoveCursor(pid)
	let f = s:players[a:pid].file
	call <SID>BuffDoAll(f, { -> <SID>RemoveCursorPart(a:pid) })
endfunction

function! s:DrawCursor(pid)
	let f = s:players[a:pid].file
	for y in range(s:players[a:pid].range[1], s:players[a:pid].range[3])
		let events = <SID>GetEvents(y, a:pid)
		call <SID>BuffDoAll(f, { -> matchadd('MPCol' . a:pid, '\%>' . string(events[0]-1) . 'v\%<' . events[1] . 'v\%' . y . 'l') })
	endfor
endfunction

function! s:GetEvents(line, pid)
	if s:players[a:pid].mode == 'v'
		if a:line == s:players[a:pid].range[1]
			return [s:players[a:pid].range[0], 1000]
		elseif a:line == s:players[a:pid].range[3]
			return [1, s:players[a:pid].range[2] + 1]
		endif
		return [1,1000]
	elseif s:players[a:pid].mode == 'V'
		return [1,1000]
	elseif s:players[a:pid].mode == ''
		let minx = min([s:players[a:pid].range[0], s:players[a:pid].range[2]])
		let maxx = max([s:players[a:pid].range[0], s:players[a:pid].range[2]])
		return [minx, maxx + 1]
	else
		return [s:players[a:pid].range[0], s:players[a:pid].range[0] + 1]
	endif
endfunction

function! s:GetFullNameFromPid(pid)
	let name = s:players[a:pid].name
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
	if a:pid == getpid()
		return ">" . name . "<"
	else
		return name
	endif
endfunction

function! s:GetPlayers(my_pid)
	let the_others = keys(s:players)
	call filter(the_others, 'v:val != a:my_pid')
	for i in range(len(the_others))
		let the_others[i] = the_others[i] + 0
	endfor
	return sort(the_others, 'n')
endfunction

function! s:UpdateStatusLine()
	let a = &statusline
	let body = ""
	let players = <SID>GetPlayers('')
	for pid in players
		let body .= "%#MPCol" . pid . "#" . <SID>GetFullNameFromPid(pid) . "%*"
	endfor
	let a = substitute(a, '\(.*%{multiplayer_statusline#Begin()}\)\(.*\)\(%{multiplayer_statusline#End()}.*\)', '\1' . body . '\3', "")
	let &statusline = a
endfunction

function! s:FindMotherWinId(file, the_others)
	for w in range(1, winnr('$'))
		if bufnr(a:file) == winbufnr(w)
			let winid = win_getid(w)
			let mother = 1
			for pid in a:the_others
				if has_key(s:players[pid], 'winid') && s:players[pid].winid == winid
					let mother = 0
				endif
			endfor
			if mother == 1
				return winid
			endif
		endif
	endfor
	return -1
endfunction

function! s:FindBrotherWinId(the_others)
	for pid in a:the_others
		if has_key(s:players[pid], 'dir' && s:players[pid].dir == 'side')
			return s:players[pid].winid
		endif
	endfor
	return -1
endfunction

function! s:UpdateSplits()
	let home = win_getid()
	let the_others = <SID>GetPlayers(getpid())
	" (1) close and create splits if needed
	let chg = 1
	while chg
		let chg = 0
		for pid in the_others
			let motherId = <SID>FindMotherWinId(s:players[pid].file, the_others)
			if motherId > 0
				let top = line('w0')
				let bot = line('w$')
				let y0 = s:players[pid].range[1]
				if has_key(s:players[pid], 'dir')
					let d = s:players[pid].dir
					if d == 'side'
						call win_gotoid(s:players[pid].winid)
						unlet s:players[pid].winid
						unlet s:players[pid].dir
						let &eadirection = "both"
						close
					endif
					if (y0 >= top && d == 'above') || (y0 <= bot && d == 'below')
						call win_gotoid(s:players[pid].winid)
						unlet s:players[pid].winid
						unlet s:players[pid].dir
						let &eadirection = "hor"
						close
					endif
				endif
				if !has_key(s:players[pid], 'dir')
					if y0 < top
						call win_gotoid(motherId)
						let &eadirection = "hor"
						aboveleft 6split
						let s:players[pid].winid = win_getid()
						let s:players[pid].dir = 'above'
						wincmd j
						let chg = 1
					elseif y0 > bot
						call win_gotoid(motherId)
						let &eadirection = "hor"
						belowright 6split
						let s:players[pid].winid = win_getid()
						let s:players[pid].dir = 'below'
						wincmd k
						let chg = 1
					endif
				endif
			else
				if has_key(s:players[pid], 'dir')
					if s:players[pid].dir != 'side'
						call win_gotoid(s:players[pid].winid)
						unlet s:players[pid].winid
						unlet s:players[pid].dir
						let &eadirection = "hor"
						close
					endif
				endif
				if !has_key(s:players[pid], 'dir')
					let brotherId = <SID>FindBrotherWinId(the_others)
					if brotherId > 0
						echom "found brother"
						call win_gotoid(brotherId)
						let &eadirection = "both"
						execute("rightbelow split " . s:players[pid].file)
						let s:players[pid].winid = win_getid()
						let s:players[pid].dir = 'side'
					else
						echom "NOT found brother"
						let &eadirection = "ver"
						execute("botright 40vsplit " . s:players[pid].file)
						let s:players[pid].winid = win_getid()
						let s:players[pid].dir = 'side'
					endif
				endif
			endif
		endfor
	endwhile
	" (2) reorder splits if needed

	" (3) scroll in splits
	for pid in the_others
		if has_key(s:players[pid], 'winid')
			call win_gotoid(s:players[pid].winid)
			let y0 = s:players[pid].range[1]
			execute("normal! " . y0 . "G")
		endif
	endfor

	let &eadirection = "both"
	call win_gotoid(home)
endfunction


"echom BuffDo('x.txt',{ -> matchaddpos('MyGroup', [[2, 2,4]])})
""call BuffDo(1,{ -> execute("call setline(3, 'text')", "")})
"do something in all windows that show the given buffer
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

"do something in the given buffer
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

" Vim Multiplayer Marts 2017
" Usage:
" :help Multiplayer
" Author:
"   Rolf Asmund

let s:player_profile = {}
let s:profile_file = ""

if !exists('g:multiplayer_profiles_path')
	let mtch = matchlist(expand('<sfile>'), '\(.*\)plugin.*')
	if len(mtch) >= 2
		let g:multiplayer_profiles_path = mtch[1]
	endif
endif

function! s:LoadProfile(ip)
	let s:profile_file = g:multiplayer_profiles_path . "profile_" . a:ip . ".vim"
	if filereadable(s:profile_file)
		execute "let s:player_profile = " . readfile(s:profile_file)[0]
		for key in keys(s:player_profile)
			execute "let " . key . "=" . s:player_profile[key]
		endfor
	endif
endfunction

let ip = "local"
if !exists('g:multiplayer_profiles_path')
	echoerr "multiplayer can't find a place to save player profiles. Please set 'g:multiplayer_profiles_path'"
else
	let mtch = matchlist($SSH_CLIENT, '\([^ ]\+\).*')
	if len(mtch) >= 2
		let ip = mtch[1]
	endif
	call <SID>LoadProfile(ip)
endif

if !exists('g:multiplayer_name')
	let g:multiplayer_name = "noname"
endif

if !exists('g:multiplayer_highlight')
	let g:multiplayer_highlight = ['inverse', 'Red', 'White']
endif

if !exists('g:multiplayer_nmap_leader')
	let g:multiplayer_nmap_leader = "<F4>"
endif

if !exists('g:multiplayer_cmap_leader')
	let g:multiplayer_cmap_leader = ""
endif

if !exists('g:multiplayer_imap_leader')
	let g:multiplayer_imap_leader = ""
endif

if !exists('g:multiplayer_auto_connect')
	if ip == 'local'
		let g:multiplayer_auto_connect = "n"
	else
		let g:multiplayer_auto_connect = "y"
	endif
endif

if !exists('g:multiplayer_auto_split')
	let g:multiplayer_auto_split = "n"
endif

if !exists('g:multiplayer_chat_mapping')
	let g:multiplayer_chat_mapping = "m<CR>"
endif

if !exists('g:multiplayer_chat_destination')
	let g:multiplayer_chat_destination = 'Cec'
endif

command! -nargs=0 MultiplayerConnect call multiplayer#Connect(s:profile_file, s:player_profile)

if g:multiplayer_auto_connect == 'y'
	autocmd VimEnter * :call multiplayer#Connect(s:profile_file, s:player_profile)
endif

augroup MultiplayerGlobalAuGroup
	autocmd!
	autocmd SwapExists * call <SID>SwapExists(v:swapname)
augroup END

function! s:SwapExists(swapname)
	if g:multiplayer_auto_connect == 'y'
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
		call multiplayer#Connect(s:profile_file, s:player_profile)
		let v:swapchoice = 'e'
	else
		let v:swapchoice = 'o'
	endif
endfunction


"for x in $(ls /tmp/vim* | sed -e 's/[^0-9]*\(.*\)/\1/'); do kill $x; done ; rm /tmp/vim*

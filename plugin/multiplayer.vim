" Vim Multiplayer 0.1 October 2016
" A plugin to allow multiple vim users on the same file
" Installation:
"     Source this file
"   or
"     If using pathogen, copy this file into .vim/bundle/multiplayer/plugin/
"   or
"     Copy it to your .vim/plugin directory to automatically source it when vim
"     starts
"   or
"     Copy it to your .vim/plugins directory (or any other directory) and source
"     it explicitly from your .vimrc
" Usgae:
" try help Multiplayer
" Note:
" Author:
"   Rolf Asmund
"

if !exists('g:multiplayer_profiles_path')
	let mtch = matchlist(expand('<sfile>'), '\(.*\)plugin.*')
	if len(mtch) >= 2
		let g:multiplayer_profiles_path = mtch[1]
	endif
endif

let ip = "local"
if !exists('g:multiplayer_profiles_path')
	echoerr "multiplayer can't find a place to save player profiles. Please set 'g:multiplayer_profiles_path'"
else
	let mtch = matchlist($SSH_CLIENT, '\([^ ]\+\).*')
	if len(mtch) >= 2
		let ip = mtch[1]
	endif
	call multiplayer#LoadProfile(ip)
endif

if !exists('g:multiplayer_name')
	let g:multiplayer_name = "noname"
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

if !exists('g:multiplayer_chat_mapping')
	let g:multiplayer_chat_mapping = "m<CR>"
endif

if !exists('g:multiplayer_chat_destination')
	let g:multiplayer_chat_destination = 'cmC'
endif

command! -nargs=0 MultiplayerConnect call multiplayer#Connect()

if g:multiplayer_auto_connect == 'y'
	autocmd VimEnter * :call multiplayer#Connect()
endif

hi MPCol1 term=reverse cterm=bold ctermfg=White ctermbg=Red guifg=White guibg=Red
hi MPCol2 term=reverse cterm=bold ctermfg=White ctermbg=Green guifg=White guibg=Green
hi MPCol3 term=reverse cterm=bold ctermfg=White ctermbg=Yellow guifg=White guibg=Yellow
hi MPCol4 term=reverse cterm=bold ctermfg=White ctermbg=Blue guifg=White guibg=Blue
hi MPCol5 term=reverse cterm=bold ctermfg=White ctermbg=Magenta guifg=White guibg=Magenta
hi MPCol6 term=reverse cterm=bold ctermfg=White ctermbg=Cyan guifg=White guibg=Cyan
hi MPCol7 term=reverse cterm=bold ctermfg=White ctermbg=Black guifg=White guibg=Black

augroup MultiplayerGlobalAuGroup
	autocmd!
	autocmd SwapExists * call multiplayer#SwapExists(v:swapname)
augroup END


"for x in $(ls /tmp/vim* | sed -e 's/[^0-9]*\(.*\)/\1/'); do kill $x; done ; rm /tmp/vim*

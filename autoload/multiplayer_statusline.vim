" Vim Multiplayer Marts 2017
" Usage:
" :help Multiplayer
" Author:
"   Rolf Asmund

function! multiplayer_statusline#Get()
	return "%{multiplayer_statusline#Begin()}%{multiplayer_statusline#End()}"
endfunction

function! multiplayer_statusline#Begin()
	return ""
endfunction

function! multiplayer_statusline#End()
	return ""
endfunction

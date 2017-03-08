source "${BASH_SOURCE%/*}"/../setup.sh
#Test async communication

cat >>$vimtestdir/test.vim <<EOL

function! s:MyHandlerOut(channel, msg, pid)
	execute "let m = " . a:msg
	call add(g:test_players[a:pid].msgs, m)
endfunction

function! SendUnicastMsg(command, from_pid, msg)
	call writefile([string([a:command, a:from_pid, len(a:msg)] + a:msg)], "/tmp/vim_multi_player_pipe_" . getpid())
endfunction

function! CreatePipe(pid)
	let g:test_players[a:pid].read_buffer = []
	call system('mkfifo /tmp/vim_multi_player_pipe_' . a:pid)
	call system('sleep infinity > /tmp/vim_multi_player_pipe_' . a:pid . ' &')
	let job = job_start('cat /tmp/vim_multi_player_pipe_' . a:pid, {"out_cb": { channel, msg -> call('s:MyHandlerOut', [channel, msg, a:pid])}})
endfunction

MultiplayerConnect

let my_pid = CreateTestPlayer()
call CreatePipe(my_pid)
call SendUnicastMsg("hello", my_pid, [])
sleep 1200m
call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(my_pid))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('file', ['$vimtestdir/a.txt']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['n', 1, 1, 1, 1]), GetMsg(my_pid))
call assert_equal(ExpectedMsg('highlight', [['inverse', 'Red', 'White']]), GetMsg(my_pid))
call assert_equal(0, GetMsg(my_pid))
call SendUnicastMsg("iam", my_pid, ['Tester'])
sleep 200m
call SendUnicastMsg("diff", my_pid, ['$vimtestdir/a.txt', '0a1', '> hello world'])
sleep 200m
call assert_equal("hello world", getline(1))

EOL

HOME=$vimtestdir vim -X a.txt
rm /tmp/vim_multi_player_pipe_100000*

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

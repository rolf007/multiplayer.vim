source "${BASH_SOURCE%/*}"/../setup.sh
#Test history (q/, q? and q:)

cat >>$vimtestdir/.vimrc <<EOL
let g:multiplayer_nmap_leader = 'm'
nunmap q
EOL

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect
sleep 200m

let my_pid = CreatePlayer()
sleep 200m
call SendUnicastMsg("hello", my_pid, [])
call SendUnicastMsg("iam", my_pid, ['Tester'])
sleep 2000m

call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['a.txt', 'n', '1', '1', '1', '1']), GetMsg(my_pid))


execute "normal mq/"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['q/', 'q/']), GetMsg(my_pid))
call SendUnicastMsg('reply_history', my_pid, ['q/', '6', '7', '8'])
sleep 200m
call assert_equal('6', histget('/', -3))
call assert_equal('7', histget('/', -2))
call assert_equal('8', histget('/', -1))
sleep 2000m
call feedkeys("", 'x')
execute "normal! kk"
"call feedkeys("\<CR>", 'x')
sleep 2000m
call assert_equal('7', getreg('/'))
call assert_equal('', histget('/', -2))
call assert_equal('7', histget('/', -1))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

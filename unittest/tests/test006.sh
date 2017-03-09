source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh
#Test history (q/, q? and q:)

cat >>$vimtestdir/.vimrc <<EOL
let g:multiplayer_nmap_leader = 'm'
nnoremap q: q:
nnoremap q/ q/
nnoremap q? q?
EOL

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect

let my_pid = CreateTestPlayer()
call SendToDut("hello", my_pid, [])

call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(my_pid))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('file', ['$vimtestdir/a.txt']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['n', 1, 1, 1, 1]), GetMsg(my_pid))
call assert_equal(ExpectedMsg('highlight', [['inverse', 'Red', 'White']]), GetMsg(my_pid))

call histadd('/', 'a')
call histadd('/', 'b')
call histadd('/', 'c')
call assert_equal('a', histget('/', -3))
call assert_equal('b', histget('/', -2))
call assert_equal('c', histget('/', -1))

execute "normal mq/"
call assert_equal(ExpectedMsg('request_register', ['q/', 'q/']), GetMsg(my_pid))
call SendToDut('reply_history', my_pid, ['q/', '6', '7', '8'])
call assert_equal('6', histget('/', -3))
call assert_equal('7', histget('/', -2))
call assert_equal('8', histget('/', -1))
call feedkeys("", 'x')
execute "normal! kk"
"call feedkeys("\<CR>", 'x')
"call assert_equal('7', getreg('/'))
"call assert_equal('', histget('/', -2))
"call assert_equal('7', histget('/', -1))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

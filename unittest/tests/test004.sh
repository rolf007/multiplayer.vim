source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh
#Test search

cat >>$vimtestdir/.vimrc <<EOL
let g:multiplayer_nmap_leader = 'm'
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

execute "normal! i1234567896611\<esc>0"

"search forwards for remote search register
execute "normal m/"
call assert_equal(ExpectedMsg('request_register', ['/', '/']), GetMsg(my_pid))
call SendToDut('reply_register', my_pid, ['/', '6', 'v'])
call feedkeys("\<CR>", 'x')
call assert_equal('6', getreg('/'))
call assert_equal(6, getpos('.')[2])

"search backwards for remote search register
execute "normal m?"
call assert_equal(ExpectedMsg('request_register', ['?', '/']), GetMsg(my_pid))
call assert_equal(0, GetMsg(my_pid))
call SendToDut('reply_register', my_pid, ['?', '1', 'v'])
call feedkeys("\<CR>", 'x')
call assert_equal('1', getreg('/'))
call assert_equal(1, getpos('.')[2])

"======= OTHER SIDE =======

"remote searches forward for word nearest to cursor. whole word. (star)
execute "normal! ccword1 word2 word3\<esc>0wl"
call SendToDut('request_register', my_pid, ['/', 'B'])
call assert_equal(ExpectedMsg('reply_register', ['/', '\\<word2\\>', 'v']), GetMsg(my_pid))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

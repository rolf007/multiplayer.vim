source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh
#Test 'Put' from remote register

cat >>$vimtestdir/.vimrc <<EOL
let g:multiplayer_nmap_leader = 'm'
call histadd(':', 'call SendToDut("chat", 1000001, ["file", 3,4, "woot"])')
let g:multiplayer_chat_destination = 'ceC'
call histadd(':', 'MultiplayerLs')
EOL

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect

execute "normal! i123456\<esc>hh"

execute "normal mP"
call assert_equal(['123456'], getline(1, '$'))

"A new player 'Tester' connects
let pid_tester = CreateTestPlayer()
call SendToDut("hello", pid_tester, [])
call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(pid_tester))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(pid_tester))
call assert_equal(ExpectedMsg('file', ['$vimtestdir/a.txt']), GetMsg(pid_tester))
call assert_equal(ExpectedMsg('cursor', ['n', 1, 1, 1, 1]), GetMsg(pid_tester))
call assert_equal(ExpectedMsg('highlight', [['inverse', 'Red', 'White']]), GetMsg(pid_tester))
call assert_equal(0, GetMsg(pid_tester))
call SendToDut("iam", pid_tester, ['Tester'])
call SendToDut("highlight", pid_tester, [['inverse', 'Green', 'White']])


"put 'before' from default register
execute "normal mP"
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_tester))
call SendToDut('reply_register', pid_tester, ['P', 'data', 'v'])
call assert_equal(['123data456'], getline(1, '$'))

"put 'after' from register x
execute "normal \"xmp"
call assert_equal(ExpectedMsg('request_register', ['p', 'x']), GetMsg(pid_tester))
call SendToDut('reply_register', pid_tester, ['p', 'beef', 'v'])
call assert_equal(['123databeef456'], getline(1, '$'))

"put line 'before'
execute "normal mP"
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_tester))
call SendToDut('reply_register', pid_tester, ['P', 'line-putted-before', 'V'])
call assert_equal(['line-putted-before', '123databeef456'], getline(1, '$'))

"put line 'after'
execute "normal mp"
call assert_equal(ExpectedMsg('request_register', ['p', '"']), GetMsg(pid_tester))
call SendToDut('reply_register', pid_tester, ['p', 'line-putted-after', 'V'])
call assert_equal(['line-putted-before', 'line-putted-after', '123databeef456'], getline(1, '$'))

"put block 'before'
execute "normal mP"
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_tester))
call SendToDut('reply_register', pid_tester, ['P', "ABCD\nEFGH\nIJKL", "\<C-V>"])
call assert_equal(['line-putted-before', 'ABCDline-putted-after', 'EFGH123databeef456', 'IJKL'], getline(1, '$'))

"put block 'after'
execute "normal mp"
call assert_equal(ExpectedMsg('request_register', ['p', '"']), GetMsg(pid_tester))
call SendToDut('reply_register', pid_tester, ['p', "x\ny\nz", "\<C-V>"])
call assert_equal(['line-putted-before', 'AxBCDline-putted-after', 'EyFGH123databeef456', 'IzJKL'], getline(1, '$'))


"A new player 'Jester' connects
let pid_jester = CreateTestPlayer()
call SendToDut("hello", pid_jester, [])
call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(pid_jester))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(pid_jester))
call assert_equal(ExpectedMsg('file', ['$vimtestdir/a.txt']), GetMsg(pid_jester))
call assert_equal(ExpectedMsg('cursor', ['n', 1, 1, 1, 1]), GetMsg(pid_jester))
call assert_equal(ExpectedMsg('highlight', [['inverse', 'Red', 'White']]), GetMsg(pid_jester))
call assert_equal(0, GetMsg(pid_jester))
call SendToDut("iam", pid_jester, ['James Bond'])
call SendToDut("highlight", pid_jester, [['bold,reverse', 'DarkGrey', 'Yellow']])

"put 'before' from player 1
execute "normal mP1"
call assert_equal(0, GetMsg(pid_tester))
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_jester))
call SendToDut('reply_register', pid_jester, ['P', 'jester', 'v'])
call assert_equal(['line-putted-before', 'AjesterxBCDline-putted-after', 'EyFGH123databeef456', 'IzJKL'], getline(1, '$'))

"put 'before' from player 0
execute "normal mP0"
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_tester))
call assert_equal(0, GetMsg(pid_jester))
call SendToDut('reply_register', pid_jester, ['P', 'tester', 'v'])
call assert_equal(['line-putted-before', 'AjestetesterrxBCDline-putted-after', 'EyFGH123databeef456', 'IzJKL'], getline(1, '$'))

"======= OTHER SIDE =======

let @a = 'a word'
call SendToDut('request_register', pid_jester, ['P', 'a'])
call assert_equal(ExpectedMsg('reply_register', ['P', 'a word', 'v']), GetMsg(pid_jester))
call assert_equal(0, GetMsg(pid_jester))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

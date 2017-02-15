source "${BASH_SOURCE%/*}"/../setup.sh
#Test 'Put' from remote register

cat >>$vimtestdir/.vimrc <<EOL
let g:multiplayer_nmap_leader = 'm'
EOL

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect
sleep 200m

execute "normal! i123456\<esc>hh"

execute "normal mP"
call assert_equal(['123456'], getline(1, '$'))

"A new player 'Tester' connects
let pid_tester = CreatePlayer()
sleep 200m
call SendUnicastMsg("hello", pid_tester, [])
call SendUnicastMsg("iam", pid_tester, ['Tester'])
sleep 200m
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(pid_tester))
call assert_equal(ExpectedMsg('cursor', ['a.txt', 'n', '1', '1', '1', '1']), GetMsg(pid_tester))


"put 'before' from default register
execute "normal mP"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_tester))
call SendUnicastMsg('reply_register', pid_tester, ['P', 'data', 'v'])
sleep 200m
call assert_equal(['123data456'], getline(1, '$'))

"put 'after' from register x
execute "normal \"xmp"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['p', 'x']), GetMsg(pid_tester))
call SendUnicastMsg('reply_register', pid_tester, ['p', 'beef', 'v'])
sleep 200m
call assert_equal(['123databeef456'], getline(1, '$'))

"put line 'before'
execute "normal mP"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_tester))
call SendUnicastMsg('reply_register', pid_tester, ['P', 'line-putted-before', 'V'])
sleep 200m
call assert_equal(['line-putted-before', '123databeef456'], getline(1, '$'))

"put line 'after'
execute "normal mp"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['p', '"']), GetMsg(pid_tester))
call SendUnicastMsg('reply_register', pid_tester, ['p', 'line-putted-after', 'V'])
sleep 200m
call assert_equal(['line-putted-before', 'line-putted-after', '123databeef456'], getline(1, '$'))

"put block 'before'
execute "normal mP"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_tester))
call SendUnicastMsg('reply_register', pid_tester, ['P', "ABCD\nEFGH\nIJKL", "\<C-V>"])
sleep 200m
call assert_equal(['line-putted-before', 'ABCDline-putted-after', 'EFGH123databeef456', 'IJKL'], getline(1, '$'))

"put block 'after'
execute "normal mp"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['p', '"']), GetMsg(pid_tester))
call SendUnicastMsg('reply_register', pid_tester, ['p', "x\ny\nz", "\<C-V>"])
sleep 200m
call assert_equal(['line-putted-before', 'AxBCDline-putted-after', 'EyFGH123databeef456', 'IzJKL'], getline(1, '$'))


"A new player 'Jester' connects
let pid_jester = CreatePlayer()
sleep 200m
call SendUnicastMsg("hello", pid_jester, [])
call SendUnicastMsg("iam", pid_jester, ['Jester'])
sleep 200m
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(pid_jester))
call assert_equal(ExpectedMsg('cursor', ['a.txt', 'n', '1', '1', '1', '1']), GetMsg(pid_jester))

"put 'before' from player 1
execute "normal mP1"
sleep 200m
call assert_equal(0, GetMsg(pid_tester))
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_jester))
call SendUnicastMsg('reply_register', pid_jester, ['P', 'jester', 'v'])
sleep 200m
call assert_equal(['line-putted-before', 'AjesterxBCDline-putted-after', 'EyFGH123databeef456', 'IzJKL'], getline(1, '$'))

"put 'before' from player 0
execute "normal mP0"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(pid_tester))
call assert_equal(0, GetMsg(pid_jester))
call SendUnicastMsg('reply_register', pid_jester, ['P', 'tester', 'v'])
sleep 200m
call assert_equal(['line-putted-before', 'AjestetesterrxBCDline-putted-after', 'EyFGH123databeef456', 'IzJKL'], getline(1, '$'))

"======= OTHER SIDE =======

let @a = 'a word'
call SendUnicastMsg('request_register', pid_jester, ['P', 'a'])
sleep 200m
call assert_equal(ExpectedMsg('reply_register', ['P', 'a word', 'v']), GetMsg(pid_jester))
call assert_equal(0, GetMsg(pid_jester))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

source "${BASH_SOURCE%/*}"/../setup.sh
#Test 'Put' from remote register

cat >>$vimtestdir/.vimrc <<EOL
let g:multiplayer_nmap_leader = 'm'
EOL

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect
sleep 200m

let my_pid = CreatePlayer()
sleep 200m
call SendUnicastMsg("hello", my_pid, [])
call SendUnicastMsg("iam", my_pid, ['Tester'])
sleep 200m

call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['a.txt', 'n', '1', '1', '1', '1']), GetMsg(my_pid))

execute "normal! i123456\<esc>hh"

"put 'before' from default register
execute "normal mP"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(my_pid))
call SendUnicastMsg('reply_register', my_pid, ['P', 'data', 'v'])
sleep 200m
call assert_equal(['123data456'], getline(1, '$'))

"put 'after' from register x
execute "normal \"xmp"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['p', 'x']), GetMsg(my_pid))
call SendUnicastMsg('reply_register', my_pid, ['p', 'beef', 'v'])
sleep 200m
call assert_equal(['123databeef456'], getline(1, '$'))

"put line 'before'
execute "normal mP"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(my_pid))
call SendUnicastMsg('reply_register', my_pid, ['P', 'line-putted-before', 'V'])
sleep 200m
call assert_equal(['line-putted-before', '123databeef456'], getline(1, '$'))

"put line 'after'
execute "normal mp"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['p', '"']), GetMsg(my_pid))
call SendUnicastMsg('reply_register', my_pid, ['p', 'line-putted-after', 'V'])
sleep 200m
call assert_equal(['line-putted-before', 'line-putted-after', '123databeef456'], getline(1, '$'))

"put block 'before'
execute "normal mP"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['P', '"']), GetMsg(my_pid))
call SendUnicastMsg('reply_register', my_pid, ['P', "ABCD\nEFGH\nIJKL", "\<C-V>"])
sleep 200m
call assert_equal(['line-putted-before', 'ABCDline-putted-after', 'EFGH123databeef456', 'IJKL'], getline(1, '$'))

"put block 'after'
execute "normal mp"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['p', '"']), GetMsg(my_pid))
call SendUnicastMsg('reply_register', my_pid, ['p', "x\ny\nz", "\<C-V>"])
sleep 200m
call assert_equal(['line-putted-before', 'AxBCDline-putted-after', 'EyFGH123databeef456', 'IzJKL'], getline(1, '$'))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

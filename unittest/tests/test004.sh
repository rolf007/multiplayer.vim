source "${BASH_SOURCE%/*}"/../setup.sh
#Test search

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

execute "normal! i1234567896611\<esc>0"

"search forwards for remote search register
execute "normal m/"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['/', '/']), GetMsg(my_pid))
call SendUnicastMsg('reply_register', my_pid, ['/', '6', 'v'])
sleep 200m
call feedkeys("\<CR>", 'x')
call assert_equal('6', getreg('/'))
call assert_equal(6, getpos('.')[2])

"search backwards for remote search register
execute "normal m?"
sleep 200m
call assert_equal(ExpectedMsg('request_register', ['?', '/']), GetMsg(my_pid))
call assert_equal(0, GetMsg(my_pid))
call SendUnicastMsg('reply_register', my_pid, ['?', '1', 'v'])
sleep 200m
call feedkeys("\<CR>", 'x')
call assert_equal('1', getreg('/'))
call assert_equal(1, getpos('.')[2])

"======= OTHER SIDE =======

"remote searches forward for word nearest to cursor. whole word. (star)
execute "normal! ccword1 word2 word3\<esc>0wl"
call SendUnicastMsg('request_register', my_pid, ['/', 'B'])
sleep 200m
call assert_equal(ExpectedMsg('reply_register', ['/', '\\<word2\\>', 'v']), GetMsg(my_pid))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

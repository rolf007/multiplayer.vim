source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh
#Test diff and cursor

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect

let my_pid = CreateTestPlayer()
let g:test_players[my_pid].file = "a.txt"
let g:test_players[my_pid].mode = "n"
let g:test_players[my_pid].range = [1,1,1,1]
call SendToDut("hello", my_pid, [])

call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(my_pid))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['a.txt', 'n', 1, 1, 1, 1]), GetMsg(my_pid))
call assert_equal(0, GetMsg(my_pid))

call SendToDut("iam", my_pid, ['Tester'])
call SendToDut('cursor', my_pid, ['a.txt', 'n', 1, 1, 1, 1])

call SendToDut("diff", my_pid, ['a.txt', '1c1', '< ', '---', '> hello world'])
call assert_equal(0, GetMsg(my_pid))
call assert_equal(['hello world'], getline(1, '$'))

call SendToDut("diff", my_pid, ['a.txt', '1a2,3', "> \<TAB>12345\<TAB>123", '> 123456789'])
call assert_equal(['hello world', "\<TAB>12345\<TAB>123", '123456789'], getline(1, '$'))

let g:test_players[my_pid].range = ['6', '2', '6', '2']
call SendToDut('cursor', my_pid, ['a.txt', 'n', '6', '2', '6', '2'])
let m = getmatches()
call assert_equal(1, len(m))
call assert_equal('MPCol2', m[0].group)
call assert_equal('\%>5v\%<7v\%2l', m[0].pattern)
call assert_equal(0, GetMsg(my_pid))

"======= OTHER SIDE =======

execute("normal! dd")
call TextChanged()
call assert_equal(ExpectedMsg('diff', ['a.txt', '1d0', '< hello world']), GetMsg(my_pid))
call assert_equal(0, GetMsg(my_pid))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

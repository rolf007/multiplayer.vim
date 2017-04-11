source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh
#Test MultiplayerLs

cat >>$vimtestdir/.vimrc <<EOL
let g:multiplayer_nmap_leader = 'm'
let g:multiplayer_name = 'dut'
EOL

cat >>$vimtestdir/test.vim <<EOL

call histadd(':', 'MultiplayerLs')

MultiplayerConnect


let my_pid = CreateTestPlayer()
call SendToDut("hello", my_pid, [])
call SendToDut("iam", my_pid, ['Tester'])
call SendToDut("file", my_pid, ['$vimtestdir/sub/b.txt'])

call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(my_pid))
call assert_equal(ExpectedMsg('iam', ['dut']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('file', ['$vimtestdir/a.txt']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['n', 1, 1, 1, 1]), GetMsg(my_pid))
call assert_equal(ExpectedMsg('highlight', [['inverse', 'Red', 'White']]), GetMsg(my_pid))
call assert_equal(0, GetMsg(my_pid))

let a = split(execute("MultiplayerLs"), "\n")
call assert_equal([
   \ '>dut<      "a.txt"                        line 1, col 1',
   \ 'Tester     "sub/b.txt"                    line 1, col 1'], a)

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

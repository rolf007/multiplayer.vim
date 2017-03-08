source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh
#Test file and cursor

cat >>$vimtestdir/.vimrc <<EOL
let g:multiplayer_nmap_leader = 'm'
EOL

cat >>$vimtestdir/test.vim <<EOL

call histadd(':', "echo expand('%:p')")
let pid1 = CreateTestPlayer()

MultiplayerConnect
call assert_equal(ExpectedMsg('hello', []), GetBroadCastedMsg(pid1))
call assert_equal(0, GetBroadCastedMsg(pid1))
call SendToDut("hello_reply", pid1, [])
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(pid1))
call assert_equal(ExpectedMsg('file', ['$vimtestdir/a.txt']), GetMsg(pid1))
call assert_equal(ExpectedMsg('cursor', ['n', 1, 1, 1, 1]), GetMsg(pid1))
call assert_equal(ExpectedMsg('highlight', [['inverse', 'Red', 'White']]), GetMsg(pid1))
call assert_equal(0, GetMsg(pid1))

let pid2 = CreateTestPlayer()
call SendToDut("hello", pid2, [])

call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(pid2))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(pid2))
call assert_equal(ExpectedMsg('file', ['$vimtestdir/a.txt']), GetMsg(pid2))
call assert_equal(ExpectedMsg('cursor', ['n', 1, 1, 1, 1]), GetMsg(pid2))
call assert_equal(ExpectedMsg('highlight', [['inverse', 'Red', 'White']]), GetMsg(pid2))
call assert_equal(0, GetMsg(pid2))
call assert_equal(0, GetMsg(pid1))


EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

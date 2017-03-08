source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect

let my_pid = CreateTestPlayer()

call SendToDut("hello", my_pid, [])
call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(my_pid))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('file', ['$vimtestdir/a.txt']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['n', 1, 1, 1, 1]), GetMsg(my_pid))
call assert_equal(ExpectedMsg('highlight', [['inverse', 'Red', 'White']]), GetMsg(my_pid))
call SendToDut("iam", my_pid, ['Tester'])
call SendToDut("diff", my_pid, ['$vimtestdir/a.txt', '0a1', '> hello world'])
call assert_equal("hello world", getline(1))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

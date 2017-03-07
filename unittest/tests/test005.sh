source "${BASH_SOURCE%/*}"/../setup.sh
source $ROOT/"${BASH_SOURCE%/*}"/../inject.sh
#Test configuration

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

echom "First instance"
MultiplayerLet &ts=12
call assert_notequal("\n\nNo mapping found", execute("nmap mp"))
MultiplayerLet g:multiplayer_nmap_leader='<F5>'
MultiplayerLet g:multiplayer_imap_leader='<F6>'
call assert_equal("\n\nNo mapping found", execute("nmap mp"))
call assert_notequal("\n\nNo mapping found", execute("nmap <F5>p"))
call assert_notequal("\n\nNo mapping found", execute("imap <F6><C-R>"))

EOL

HOME=$vimtestdir vim -X a.txt

rm $vimtestdir/test.vim

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect

let my_pid = CreateTestPlayer()
call SendToDut("hello", my_pid, [])

call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(my_pid))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('file', ['$vimtestdir/a.txt']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['n', 1, 1, 1, 1]), GetMsg(my_pid))
call assert_equal(ExpectedMsg('highlight', [['inverse', 'Red', 'White']]), GetMsg(my_pid))

echom "Second instance"
call assert_equal(12, &ts)

call assert_equal("\n\nNo mapping found", execute("nmap mp"))
call assert_notequal("\n\nNo mapping found", execute("nmap <F5>p"))
call assert_notequal("\n\nNo mapping found", execute("imap <F6><C-R>"))

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

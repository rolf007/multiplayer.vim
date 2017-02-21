source "${BASH_SOURCE%/*}"/../setup.sh
#Test configuration

cat >>$vimtestdir/.vimrc <<EOL
let g:multiplayer_nmap_leader = 'm'
EOL

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect
sleep 200m

let my_pid = CreatePlayer()
sleep 200m
call SendUnicastMsg("hello", my_pid, [])
sleep 1200m

call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(my_pid))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['a.txt', 'n', '1', '1', '1', '1']), GetMsg(my_pid))

echom "First instance"
sleep 2000m

EOL

HOME=$vimtestdir vim -X a.txt

rm $vimtestdir/test.vim
rm /tmp/vim_multi_player_pipe_100000*

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect
sleep 200m

let my_pid = CreatePlayer()
sleep 200m
call SendUnicastMsg("hello", my_pid, [])
sleep 1200m

call assert_equal(ExpectedMsg('hello_reply', []), GetMsg(my_pid))
call assert_equal(ExpectedMsg('iam', ['noname']), GetMsg(my_pid))
call assert_equal(ExpectedMsg('cursor', ['a.txt', 'n', '1', '1', '1', '1']), GetMsg(my_pid))

echom "Second instance"
sleep 2000m

EOL

HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

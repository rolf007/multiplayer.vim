#succes_cmd="echom \"unittest succeded\""
source "${BASH_SOURCE%/*}"/../setup.sh

cat >>$vimtestdir/.vimrc <<EOL
EOL

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect
sleep 200m

let my_pid = CreatePlayer()
sleep 200m
call SendUnicastMsg("hello", my_pid, [])
sleep 200m
call SendUnicastMsg("diff", my_pid, ['0a1', '> hello world'])
sleep 200m
call assert_equal("hello world", getline(1))

EOL

#touch $vimtestdir/.a.txt.swp
HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

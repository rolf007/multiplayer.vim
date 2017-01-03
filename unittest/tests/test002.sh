#succes_cmd="echom \"unittest succeded\""
source "${BASH_SOURCE%/*}"/../setup.sh

cat >>$vimtestdir/.vimrc <<EOL
EOL

cat >>$vimtestdir/test.vim <<EOL

MultiplayerConnect
call SendUnicastMsg("hello", 1000001, "a.txt", [])
call SendUnicastMsg("diff", 1000001, "a.txt", ['0a1', '> hello world'])
sleep
call assert_equal("hello world", getline(1))

EOL

#touch $vimtestdir/.a.txt.swp
HOME=$vimtestdir vim -X a.txt

popd > /dev/null
source "${BASH_SOURCE%/*}"/../tear_down.sh
exit 0

vim:tw=78:ts=4:ft=vim:

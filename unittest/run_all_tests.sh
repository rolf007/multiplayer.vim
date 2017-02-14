export succes_cmd="qall!"
export sleep_cmd="redraw"

for test in "${BASH_SOURCE%/*}"/tests/test*.sh; do
	$test
done

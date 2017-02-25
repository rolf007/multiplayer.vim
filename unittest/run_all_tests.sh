export succes_cmd="qall!"

for test in "${BASH_SOURCE%/*}"/tests/test*.sh; do
	$test
done

#!/usr/bin/env bash

# Check and print hard-coded interpreter path of ELF file

if [ $# -eq 0 ]; then
	echo "Usage: $0 [FILE]..."
	exit
fi

for file in "$@"
do
	out=$(readelf -l -- "$file" 2>/dev/null)
	if [[ $? -eq 0 ]]; then
		printf "%s: " "$file"
		result=$(echo "$out" | grep -m1 "Requesting program interpreter")
		if [[ -n "$result" ]]; then
			echo "$result" | sed -E 's/^.*: ([^]]+)]$/\1/'
		else
			echo "Does not have hard-coded interpreter"
		fi
	else
		echo "$file: Is not an ELF file, it's $(file -b -- "$file")"
	fi
done

#!/bin/bash

# Number of lines per test case output block
LINES_PER_CASE=1

set -e

if [ $# -eq 0 ]; then
    echo "Error: Please provide a filename (without .cpp)"
    exit 1
fi

filename="$1"
output="out/$1"

mkdir -p out

g++-16 -std=c++20 -g -fsanitize=address,undefined -fno-omit-frame-pointer "$filename" -o "$output"

if [ ! -f "input.txt" ]; then
    echo "Error: input.txt not found"
    exit 1
fi

if [ ! -f "expected.txt" ]; then
    echo "Error: expected.txt not found"
    exit 1
fi

set +e
actual=$(./"$output" < input.txt 2> /tmp/cp_debug.txt)
exit_code=$?
set -e

echo
echo "========== RESULTS =========="

if [ $exit_code -ne 0 ]; then
    printf "\033[31mPROGRAM CRASHED (exit code: %d)\033[0m\n" "$exit_code"
    echo
    echo "See DEBUG OUTPUT below for the error."
    echo "============================="
    echo
    echo "========== DEBUG OUTPUT =========="
    cat /tmp/cp_debug.txt
    echo "==================================="
    exit 0
fi

# Build arrays without mapfile (portable to bash 3.2)
expected_lines=()
while IFS= read -r line; do
    expected_lines+=("$line")
done < expected.txt

actual_lines=()
while IFS= read -r line; do
    actual_lines+=("$line")
done <<< "$actual"

total_expected=${#expected_lines[@]}

test_num=1
idx=0
while [ $idx -lt $total_expected ]; do
    exp_block=""
    act_block=""
    for ((k=0; k<LINES_PER_CASE; k++)); do
        line_idx=$((idx + k))
        [ $line_idx -ge $total_expected ] && break
        exp_line="${expected_lines[$line_idx]}"
        act_line="${actual_lines[$line_idx]}"
        exp_block+="${exp_line}"$'\n'
        act_block+="${act_line}"$'\n'
    done

    # trim trailing whitespace on each line, then restore block's trailing newline
    exp_block="$(printf '%s' "$exp_block" | sed 's/[[:space:]]*$//')"$'\n'
    act_block="$(printf '%s' "$act_block" | sed 's/[[:space:]]*$//')"$'\n'

    if [ "$exp_block" = "$act_block" ]; then
        printf "\033[32m✓ Test %d: CORRECT\033[0m\n" "$test_num"
        echo "    Output:"
        printf "%s" "$exp_block" | sed 's/^/      /'
    else
        printf "\033[31m✗ Test %d: INCORRECT\033[0m\n" "$test_num"
        echo "    Expected:"
        printf "%s" "$exp_block" | sed 's/^/      /'
        echo "    Actual:"
        printf "%s" "$act_block" | sed 's/^/      /'
    fi

    idx=$((idx + LINES_PER_CASE))
    test_num=$((test_num + 1))
done

echo "============================="
echo
echo "========== DEBUG OUTPUT =========="
cat /tmp/cp_debug.txt
echo "==================================="
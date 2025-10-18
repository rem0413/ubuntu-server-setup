#!/bin/bash

echo "========================================="
echo "  Simple Input Test"
echo "========================================="
echo ""
echo "This tests if input works when piped"
echo ""

printf "Enter your choice (1-5): "

# Handle both terminal and piped input
if [ -t 0 ]; then
    echo "[Reading from stdin - terminal mode]"
    read -r choice
else
    echo "[Reading from /dev/tty - piped mode]"
    read -r choice < /dev/tty
fi

echo ""
echo "You entered: $choice"
echo ""

if [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo "Valid number: $choice"
else
    echo "Not a number: $choice"
fi

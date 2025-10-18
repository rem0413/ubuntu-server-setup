#!/bin/bash

# Test script to verify input reading works when piped

echo "Testing input reading..."
echo ""

# Test 1: Check if stdin is a terminal
if [ -t 0 ]; then
    echo "✓ stdin is a terminal"
else
    echo "✗ stdin is NOT a terminal (piped)"
fi

echo ""
echo "Attempting to read input..."
echo -n "Enter your name: "

# Try to read input
if [ -t 0 ]; then
    # stdin is a terminal
    read -r name
else
    # stdin is piped, read from /dev/tty
    read -r name < /dev/tty 2>/dev/null || name="(no input)"
fi

echo ""
echo "You entered: $name"
echo ""

# Test 2: Test with timeout
echo "Testing with timeout (10 seconds)..."
echo -n "Enter a number: "

if [ -t 0 ]; then
    read -r -t 10 number 2>/dev/null
else
    read -r -t 10 number < /dev/tty 2>/dev/null || number=""
fi

if [[ -n "$number" ]]; then
    echo "You entered: $number"
else
    echo "No input received (timeout or error)"
fi

echo ""
echo "Test complete!"

#!/bin/bash

echo "============================================"
echo "  Input Diagnostic Tool"
echo "============================================"
echo ""

# Check 1: stdin type
echo "Check 1: stdin type"
if [ -t 0 ]; then
    echo "  Result: stdin IS a terminal"
else
    echo "  Result: stdin is NOT a terminal (piped)"
fi
echo ""

# Check 2: /dev/tty exists
echo "Check 2: /dev/tty availability"
if [ -e /dev/tty ]; then
    echo "  Result: /dev/tty exists"
    ls -l /dev/tty
else
    echo "  Result: /dev/tty does NOT exist"
fi
echo ""

# Check 3: Can read from /dev/tty
echo "Check 3: Test reading from /dev/tty"
echo "  (Will wait 5 seconds for input...)"
if timeout 5 bash -c 'read -r test < /dev/tty 2>/dev/null && echo "Got: $test"'; then
    echo "  Result: Successfully read from /dev/tty"
else
    echo "  Result: FAILED to read from /dev/tty"
fi
echo ""

# Check 4: Environment
echo "Check 4: Environment info"
echo "  TERM: ${TERM:-not set}"
echo "  SHELL: ${SHELL:-not set}"
echo "  User: $(whoami)"
echo "  TTY: $(tty 2>/dev/null || echo 'no tty')"
echo ""

# Check 5: Try exec redirect
echo "Check 5: Testing exec redirect"
if exec < /dev/tty 2>/dev/null; then
    echo "  Result: exec redirect successful"
else
    echo "  Result: exec redirect FAILED"
fi
echo ""

echo "============================================"
echo "Diagnosis complete. Share this output for help."
echo "============================================"

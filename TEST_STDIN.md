# Testing stdin/tty Input Fix

## The Problem

When running scripts via `curl | bash`, stdin is connected to curl's output pipe, not the terminal keyboard. This causes `read` commands to fail or timeout.

```bash
# This doesn't work for interactive input:
curl -fsSL URL | bash
```

## The Solution

Redirect input from `/dev/tty` (the actual terminal) instead of stdin when piped:

```bash
# Check if stdin is a terminal
if [ -t 0 ]; then
    # stdin is terminal, read normally
    read -r input
else
    # stdin is piped, read from /dev/tty
    read -r input < /dev/tty
fi
```

## Testing

### Test 1: Local Test Script

```bash
# Run normally (should detect terminal)
./test-input.sh

# Run via pipe (should still work with /dev/tty)
cat test-input.sh | bash
```

### Test 2: Test Remote Install Script Locally

```bash
# Simulate remote installation
cat remote-install.sh | sudo bash
```

This should:
1. Download files
2. Show menu
3. Accept keyboard input
4. Install selected components

### Test 3: Actual Remote Test

If you have a test VPS:

```bash
# SSH into VPS
ssh root@your-vps

# Run remote install
curl -fsSL https://raw.githubusercontent.com/rem0413/ubuntu-server-setup/master/remote-install.sh | sudo bash
```

Should work interactively now!

### Test 4: Non-Interactive (Should Still Work)

```bash
# Install all
curl -fsSL URL | sudo bash -s -- --all

# Use profile
curl -fsSL URL | sudo bash -s -- --profile nodejs-app
```

## What Changed

### Files Modified:

1. **remote-install.sh**
   - Added `/dev/tty` redirect when calling install.sh
   - Check if stdin is terminal first

2. **install.sh** (`show_simple_selection_menu`)
   - Check stdin with `[ -t 0 ]`
   - Read from `/dev/tty` when piped

3. **lib/ui.sh** (multiple functions)
   - `confirm_installation()` - fixed confirmation prompt
   - `ask_yes_no()` - fixed yes/no questions
   - `get_input()` - fixed general input

## How to Verify Fix Works

### Expected Behavior:

**Before Fix:**
```
> (cursor blinks but no input works)
Error: Input timeout or not available
```

**After Fix:**
```
> 1 4 5 7 8
Selected components: 1 4 5 7 8
```

### Debug Mode:

Add debug output to see what's happening:

```bash
# In install.sh, before read:
echo "DEBUG: stdin is terminal: $([ -t 0 ] && echo 'yes' || echo 'no')" >&2

# After read:
echo "DEBUG: input received: '$input'" >&2
```

## Common Issues

### Issue 1: `/dev/tty` not available

Some containers or environments don't have `/dev/tty`.

**Workaround:** Use non-interactive mode:
```bash
curl -fsSL URL | bash -s -- --all
```

### Issue 2: Permission denied on `/dev/tty`

Running as non-root without proper tty access.

**Solution:** Run with `sudo`:
```bash
curl -fsSL URL | sudo bash
```

### Issue 3: Still timing out

Check if script is running in truly non-interactive environment (cron, automation).

**Solution:** Always use flags for automation:
```bash
curl -fsSL URL | bash -s -- --profile nodejs-app
```

## Best Practices

1. **Always provide non-interactive option** (`--all`, `--profile`)
2. **Add timeout to read commands** (`read -t 60`)
3. **Check stdin before reading** (`[ -t 0 ]`)
4. **Fallback gracefully** with helpful error messages
5. **Test both modes** (piped and direct execution)

## Rollback Plan

If this causes issues, revert to pure non-interactive:

```bash
git revert HEAD
```

Then only support flag-based installation:
```bash
curl -fsSL URL | bash -s -- --profile nodejs-app
```

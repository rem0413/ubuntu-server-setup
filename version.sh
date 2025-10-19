#!/bin/bash

################################################################################
# Version Management Script
# Usage: ./version.sh [show|set|bump] [args]
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load utilities
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# Show help
show_help() {
    cat << HELP
Version Management Script

Usage: $0 <command> [args]

Commands:
    show                Show current version
    set <version>       Set specific version (e.g., 2.2.0)
    bump major          Bump major version (2.1.0 → 3.0.0)
    bump minor          Bump minor version (2.1.0 → 2.2.0)
    bump patch          Bump patch version (2.1.0 → 2.1.1)
    help                Show this help message

Examples:
    $0 show             # Display current version
    $0 set 2.2.0        # Set version to 2.2.0
    $0 bump minor       # Bump from 2.1.0 to 2.2.0
    $0 bump patch       # Bump from 2.1.0 to 2.1.1

HELP
}

# Main
case "$1" in
    show)
        show_version "$SCRIPT_DIR"
        ;;
    set)
        if [[ -z "$2" ]]; then
            echo "Error: Version required"
            echo "Usage: $0 set <version>"
            exit 1
        fi
        set_version "$2" "$SCRIPT_DIR"
        ;;
    bump)
        if [[ -z "$2" ]]; then
            echo "Error: Bump type required (major, minor, or patch)"
            echo "Usage: $0 bump <major|minor|patch>"
            exit 1
        fi
        bump_version "$2" "$SCRIPT_DIR"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Error: Unknown command '$1'"
        echo ""
        show_help
        exit 1
        ;;
esac

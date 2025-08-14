#!/bin/bash

# Script to update version across all jenkins-mcp files
# Usage: ./scripts/update-version.sh <new-version>

set -e

# Check if version argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <new-version>"
    echo "Example: $0 0.0.5-beta"
    exit 1
fi

NEW_VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Updating jenkins-mcp version to: $NEW_VERSION"

# Update Makefile
echo "Updating Makefile..."
sed -i '' "s/^TAG=.*/TAG=$NEW_VERSION/" "$PROJECT_ROOT/Makefile"

# Update JenkinsMCP.swift
echo "Updating JenkinsMCP.swift..."
sed -i '' 's/version: "[^"]*"/version: "'"$NEW_VERSION"'"/' "$PROJECT_ROOT/Sources/JenkinsMCP/JenkinsMCP.swift"

# Update README.md
echo "Updating README.md..."
sed -i '' 's|ghcr.io/t089/jenkins-mcp:[^ "]*|ghcr.io/t089/jenkins-mcp:'"$NEW_VERSION"'|g' "$PROJECT_ROOT/README.md"

echo "Version updated successfully to $NEW_VERSION in:"
echo "  - Makefile"
echo "  - Sources/JenkinsMCP/JenkinsMCP.swift"
echo "  - README.md"
echo ""
echo "Don't forget to:"
echo "  1. Commit these changes"
echo "  2. Tag the release: git tag v$NEW_VERSION"
echo "  3. Push the tag: git push origin v$NEW_VERSION"
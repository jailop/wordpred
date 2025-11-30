#!/bin/bash
# run_tests.sh - Test runner for word prediction plugin

set -e

echo "======================================"
echo "Word Prediction Plugin Test Suite"
echo "======================================"
echo ""

# Check if we're in the tests directory
if [ ! -f "test_analyzer.vim" ]; then
    cd tests
fi

FAILED=0

# Run VimScript tests
echo "Running VimScript tests..."
echo "--------------------------------------"
if vim -u NONE -S test_analyzer.vim; then
    echo "✓ VimScript tests passed"
else
    echo "✗ VimScript tests failed"
    FAILED=1
fi

echo ""

# Run Lua tests if nvim is available
if command -v nvim &> /dev/null; then
    echo "Running Lua tests (Neovim)..."
    echo "--------------------------------------"
    if nvim --headless -u NONE -c "luafile test_analyzer_lua.lua"; then
        echo "✓ Lua tests passed"
    else
        echo "✗ Lua tests failed"
        FAILED=1
    fi
else
    echo "Neovim not found, skipping Lua tests"
fi

echo ""
echo "======================================"
if [ $FAILED -eq 0 ]; then
    echo "All test suites passed! ✓"
    echo "======================================"
    exit 0
else
    echo "Some test suites failed! ✗"
    echo "======================================"
    exit 1
fi

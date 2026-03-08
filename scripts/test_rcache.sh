#!/usr/bin/env bash
#
# Test the spaces rule cache (rcache) mechanism.
#
# This script must be run from the workspace root. It:
#   1. Restores the input file to its known initial value.
#   2. Cleans leftover build artifacts so we start fresh.
#   3. Runs the prepare rule, then the transform rule (first run — cache miss).
#   4. Runs both rules again without changes (second run — cache hit).
#   5. Modifies the checkout input file to simulate a developer edit.
#   6. Runs both rules again (third run — cache miss, targets updated).
#   7. Runs both rules again without changes (fourth run — cache hit).
#   8. Restores the original input so subsequent test suite runs start clean.
#
# Each rule is invoked individually with `spaces run <target>` so that only
# the rcache rules execute and we can verify files between each step.
#
# Cache hits vs misses are detected by comparing file modification timestamps
# of the target files before and after each spaces run. On a cache hit the
# command is skipped and the target file's mtime does not change. On a cache
# miss the command re-executes and writes a new target file, updating the mtime.

set -euo pipefail

INITIAL_CONTENT="initial content"

INPUT_FILE="testlab/rcache/input.txt"
PREPARE_TARGET="build/testlab/rcache/prepare/input_copy.txt"
TRANSFORM_TARGET="build/testlab/rcache/transform/output.txt"

PREPARE_RULE="//spaces-e2e-testlab:testlab/rcache/prepare"
TRANSFORM_RULE="//spaces-e2e-testlab:testlab/rcache/transform"

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

fail() {
    echo "FAIL: $1" >&2
    # Attempt to restore input before exiting so the workspace stays clean.
    #echo "$INITIAL_CONTENT" > "$INPUT_FILE" 2>/dev/null || true
    exit 1
}

pass() {
    echo "PASS: $1"
}

# Returns the modification timestamp (epoch seconds) for a file.
get_mtime() {
    if stat --version >/dev/null 2>&1; then
        # GNU stat (Linux)
        stat -c '%Y' "$1"
    else
        # BSD stat (macOS)
        stat -f '%m' "$1"
    fi
}

run_prepare() {
    local label="$1"
    echo ""
    echo "--- spaces run prepare: $label ---"
    spaces --ci run "$PREPARE_RULE"
}

run_transform() {
    local label="$1"
    echo ""
    echo "--- spaces run transform: $label ---"
    spaces --ci run "$TRANSFORM_RULE"
}

run_both() {
    local label="$1"
    run_prepare "$label"
    run_transform "$label"
}

# --------------------------------------------------------------------------- #
# Pre-flight: restore input to known initial state and clean build artifacts
# --------------------------------------------------------------------------- #

if [ ! -f "$INPUT_FILE" ]; then
    fail "Input file $INPUT_FILE does not exist. Run 'spaces checkout' first."
fi

echo "$INITIAL_CONTENT" > "$INPUT_FILE"

# Clean any leftover build artifacts from previous test runs.
rm -rf build/testlab/rcache

# --------------------------------------------------------------------------- #
# Run 1: First execution — expect cache miss, targets are created
# --------------------------------------------------------------------------- #

run_both "run 1 (initial, expect cache miss)"

[ -f "$PREPARE_TARGET" ] || fail "Run 1: prepare target was not created"
[ -f "$TRANSFORM_TARGET" ] || fail "Run 1: transform target was not created"

# Verify prepare target matches the input.
if ! grep -qF "$INITIAL_CONTENT" "$PREPARE_TARGET"; then
    fail "Run 1: prepare target does not contain expected content"
fi
pass "Run 1: prepare target content is correct"

# Verify transform target contains the input plus the marker.
if ! grep -qF "$INITIAL_CONTENT" "$TRANSFORM_TARGET"; then
    fail "Run 1: transform target does not contain input content"
fi
if ! grep -qF "transformed" "$TRANSFORM_TARGET"; then
    fail "Run 1: transform target does not contain 'transformed' marker"
fi
pass "Run 1: transform target content is correct"

# Record timestamps after first run.
mtime_prepare_1=$(get_mtime "$PREPARE_TARGET")
mtime_transform_1=$(get_mtime "$TRANSFORM_TARGET")

pass "Run 1: cache miss — targets created successfully"

# --------------------------------------------------------------------------- #
# Run 2: No changes — expect cache hit, targets should not be rewritten
# --------------------------------------------------------------------------- #

# Sleep to ensure any rewrite would produce a different mtime.
sleep 2

run_both "run 2 (no changes, expect cache hit)"

mtime_prepare_2=$(get_mtime "$PREPARE_TARGET")
mtime_transform_2=$(get_mtime "$TRANSFORM_TARGET")

if [ "$mtime_prepare_2" != "$mtime_prepare_1" ]; then
    fail "Run 2: prepare target mtime changed (expected cache hit). Before: $mtime_prepare_1, After: $mtime_prepare_2"
fi
pass "Run 2: prepare target unchanged (cache hit)"

if [ "$mtime_transform_2" != "$mtime_transform_1" ]; then
    fail "Run 2: transform target mtime changed (expected cache hit). Before: $mtime_transform_1, After: $mtime_transform_2"
fi
pass "Run 2: transform target unchanged (cache hit)"

# --------------------------------------------------------------------------- #
# Run 3: Modify input — expect cache miss, targets should be updated
# --------------------------------------------------------------------------- #

sleep 2

MODIFIED_CONTENT="modified content"
echo "$MODIFIED_CONTENT" > "$INPUT_FILE"

run_both "run 3 (input changed, expect cache miss)"

mtime_prepare_3=$(get_mtime "$PREPARE_TARGET")
mtime_transform_3=$(get_mtime "$TRANSFORM_TARGET")

if [ "$mtime_prepare_3" = "$mtime_prepare_1" ]; then
    fail "Run 3: prepare target mtime unchanged (expected cache miss)"
fi
pass "Run 3: prepare target updated (cache miss)"

if [ "$mtime_transform_3" = "$mtime_transform_1" ]; then
    fail "Run 3: transform target mtime unchanged (expected cache miss)"
fi
pass "Run 3: transform target updated (cache miss)"

# Verify content reflects the modified input.
if ! grep -qF "$MODIFIED_CONTENT" "$PREPARE_TARGET"; then
    fail "Run 3: prepare target does not contain modified content"
fi
pass "Run 3: prepare target content updated correctly"

if ! grep -qF "$MODIFIED_CONTENT" "$TRANSFORM_TARGET"; then
    fail "Run 3: transform target does not contain modified content"
fi
if ! grep -qF "transformed" "$TRANSFORM_TARGET"; then
    fail "Run 3: transform target missing 'transformed' marker after re-run"
fi
pass "Run 3: transform target content updated correctly"

# --------------------------------------------------------------------------- #
# Run 4: No changes after modification — expect cache hit
# --------------------------------------------------------------------------- #

sleep 2

run_both "run 4 (no changes after modification, expect cache hit)"

mtime_prepare_4=$(get_mtime "$PREPARE_TARGET")
mtime_transform_4=$(get_mtime "$TRANSFORM_TARGET")

if [ "$mtime_prepare_4" != "$mtime_prepare_3" ]; then
    fail "Run 4: prepare target mtime changed (expected cache hit). Before: $mtime_prepare_3, After: $mtime_prepare_4"
fi
pass "Run 4: prepare target unchanged (cache hit)"

if [ "$mtime_transform_4" != "$mtime_transform_3" ]; then
    fail "Run 4: transform target mtime changed (expected cache hit). Before: $mtime_transform_3, After: $mtime_transform_4"
fi
pass "Run 4: transform target unchanged (cache hit)"

# --------------------------------------------------------------------------- #
# Restore original input so subsequent test suite runs start clean.
# --------------------------------------------------------------------------- #

echo "$INITIAL_CONTENT" > "$INPUT_FILE"

echo ""
echo "========================================="
echo " All rcache tests passed."
echo "========================================="

#!/usr/bin/env bash
#
# Test the spaces rule cache (rcache) mechanism.
#
# This script must be run from the workspace root. It exercises a multi-stage
# dependency graph:
#
#   prepare (target_files)
#       ├── split_alpha (target_dirs only)
#       └── split_beta  (target_dirs + target_files)
#               └── merge (target_files only)
#                       └── finalize (target_dirs + target_files)
#
# The script:
#   1. Restores input files to known initial values and cleans build artifacts.
#   2. Runs the full graph via the finalize rule (all deps cascade) — cache miss.
#   3. Runs again without changes — cache hit for all stages.
#   4. Modifies input.txt — cache miss propagates through prepare → alpha → merge → finalize,
#      but split_beta's data/ glob deps are unchanged so beta itself may or may not re-run
#      depending on whether the prepare rule dep causes a digest change.
#   5. Runs again without changes — cache hit again.
#   6. Modifies data/records.csv — cache miss propagates through split_beta → merge → finalize.
#      prepare and split_alpha are unaffected.
#   7. Runs again without changes — cache hit again.
#   8. Modifies config.json — cache miss propagates through prepare → all downstream.
#   9. Restores original inputs so the workspace stays clean.
#
# Cache hit/miss is detected via:
#   spaces logs query <rule> --member=cache_status --json
# which returns:
#   {"Executed":"<hash>"}  → cache miss (rule was executed)
#   {"Restored":"<hash>"}  → cache hit  (targets restored from cache)
#   "None"                 → no caching (rule has no targets)

set -euo pipefail

# ========================================================================= #
# Constants — must match test_rcache.star exactly
# ========================================================================= #

PREFIX="testlab/rcache"

# Checkout input assets
INPUT_FILE="${PREFIX}/input.txt"
CONFIG_FILE="${PREFIX}/config.json"
DATA_RECORDS="${PREFIX}/data/records.csv"
DATA_SCHEMA="${PREFIX}/data/schema.json"

# Prepare outputs (target_files)
PREPARE_INPUT_COPY="build/${PREFIX}/prepare/input_copy.txt"
PREPARE_CONFIG_COPY="build/${PREFIX}/prepare/config_copy.json"

# Split alpha outputs (target_dirs only)
SPLIT_ALPHA_DIR="build/${PREFIX}/split_alpha/lines"

# Split beta outputs (target_dirs + target_files)
SPLIT_BETA_DIR="build/${PREFIX}/split_beta/merged"
SPLIT_BETA_MANIFEST="build/${PREFIX}/split_beta/manifest.txt"

# Merge output (target_files)
MERGE_OUTPUT="build/${PREFIX}/merge/combined.txt"

# Finalize outputs (target_dirs + target_files)
FINALIZE_DIR="build/${PREFIX}/finalize/artifacts"
FINALIZE_SUMMARY="build/${PREFIX}/finalize/summary.txt"

# Rule names (fully qualified)
RULE_PREPARE="//spaces-e2e-testlab:${PREFIX}/prepare"
RULE_SPLIT_ALPHA="//spaces-e2e-testlab:${PREFIX}/split_alpha"
RULE_SPLIT_BETA="//spaces-e2e-testlab:${PREFIX}/split_beta"
RULE_MERGE="//spaces-e2e-testlab:${PREFIX}/merge"
RULE_FINALIZE="//spaces-e2e-testlab:${PREFIX}/finalize"

ALL_RULES=("$RULE_PREPARE" "$RULE_SPLIT_ALPHA" "$RULE_SPLIT_BETA" "$RULE_MERGE" "$RULE_FINALIZE")

# Initial content (must match checkout assets in test_rcache.star)
INITIAL_INPUT='initial content
second line'
INITIAL_CONFIG='{"setting": "default", "version": 1}'
INITIAL_RECORDS='id,name,value
1,alpha,100
2,beta,200
3,gamma,300'
INITIAL_SCHEMA='{"fields": ["id", "name", "value"], "types": ["int", "str", "int"]}'

# ========================================================================= #
# Helpers
# ========================================================================= #

restore_all_inputs() {
    printf '%s' "$INITIAL_INPUT" > "$INPUT_FILE"
    printf '%s' "$INITIAL_CONFIG" > "$CONFIG_FILE"
    mkdir -p "$(dirname "$DATA_RECORDS")"
    printf '%s' "$INITIAL_RECORDS" > "$DATA_RECORDS"
    printf '%s' "$INITIAL_SCHEMA" > "$DATA_SCHEMA"
}

fail() {
    echo "FAIL: $1" >&2
    restore_all_inputs
    exit 1
}

pass() {
    echo "PASS: $1"
}

# Query the cache status of a rule from the latest spaces log.
# Returns "Executed", "Restored", or "None".
get_cache_status() {
    local rule="$1"
    local raw
    raw=$(spaces logs query "$rule" --member=cache_status --json 2>&1)
    if echo "$raw" | grep -q '"Executed"'; then
        echo "Executed"
    elif echo "$raw" | grep -q '"Restored"'; then
        echo "Restored"
    elif echo "$raw" | grep -q '"None"' || echo "$raw" | grep -q 'None'; then
        echo "None"
    else
        echo "Unknown"
    fi
}

# Assert a rule was a cache miss (Executed).
assert_miss() {
    local rule="$1" desc="$2"
    local status
    status=$(get_cache_status "$rule")
    if [ "$status" = "Executed" ]; then
        pass "${desc}: $(basename_rule "$rule") was Executed (cache miss)"
    else
        fail "${desc}: $(basename_rule "$rule") expected Executed (cache miss), got ${status}"
    fi
}

# Assert a rule was a cache hit (Restored).
assert_hit() {
    local rule="$1" desc="$2"
    local status
    status=$(get_cache_status "$rule")
    if [ "$status" = "Restored" ]; then
        pass "${desc}: $(basename_rule "$rule") was Restored (cache hit)"
    else
        fail "${desc}: $(basename_rule "$rule") expected Restored (cache hit), got ${status}"
    fi
}

# Assert all rules were cache misses.
assert_all_miss() {
    local desc="$1"
    for rule in "${ALL_RULES[@]}"; do
        assert_miss "$rule" "$desc"
    done
}

# Assert all rules were cache hits.
assert_all_hit() {
    local desc="$1"
    for rule in "${ALL_RULES[@]}"; do
        assert_hit "$rule" "$desc"
    done
}

# Extract short rule name for display.
basename_rule() {
    echo "$1" | sed 's|.*:||'
}

assert_file_exists() {
    if [ -f "$1" ]; then
        pass "exists: $1"
    else
        fail "missing file: $1"
    fi
}

assert_dir_exists() {
    if [ -d "$1" ]; then
        pass "exists: $1"
    else
        fail "missing dir: $1"
    fi
}

assert_file_contains() {
    local file="$1" pattern="$2" desc="$3"
    if grep -qF "$pattern" "$file" 2>/dev/null; then
        pass "$desc"
    else
        fail "${desc} — '${pattern}' not found in ${file}"
    fi
}

run_graph() {
    local label="$1"
    echo ""
    echo "=== spaces run finalize (cascades full graph): ${label} ==="
    spaces --ci run "$RULE_FINALIZE"
}

# ========================================================================= #
# Pre-flight: restore inputs and clean build artifacts
# ========================================================================= #

echo "--- Pre-flight ---"

for f in "$INPUT_FILE" "$CONFIG_FILE" "$DATA_RECORDS" "$DATA_SCHEMA"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: Input file ${f} does not exist. Run 'spaces checkout' first." >&2
        exit 1
    fi
done

restore_all_inputs

# Clean leftover build artifacts from previous test runs.
rm -rf "build/${PREFIX}"

echo "Inputs restored, build artifacts cleaned."

# ========================================================================= #
# Run 1: First execution — expect cache miss, all targets created
# ========================================================================= #

run_graph "run 1 (initial, expect cache miss)"

echo ""
echo "--- Run 1: verify targets exist ---"

# target_files
assert_file_exists "$PREPARE_INPUT_COPY"
assert_file_exists "$PREPARE_CONFIG_COPY"
assert_file_exists "$SPLIT_BETA_MANIFEST"
assert_file_exists "$MERGE_OUTPUT"
assert_file_exists "$FINALIZE_SUMMARY"

# target_dirs
assert_dir_exists "$SPLIT_ALPHA_DIR"
assert_dir_exists "$SPLIT_BETA_DIR"
assert_dir_exists "$FINALIZE_DIR"

# Verify content correctness
assert_file_contains "$PREPARE_INPUT_COPY" "initial content" "Run 1: prepare has input content"
assert_file_contains "$PREPARE_CONFIG_COPY" '"setting"' "Run 1: prepare has config content"
assert_file_contains "$SPLIT_BETA_MANIFEST" "records.csv" "Run 1: beta manifest lists records"
assert_file_contains "$SPLIT_BETA_MANIFEST" "schema.json" "Run 1: beta manifest lists schema"
assert_file_contains "$MERGE_OUTPUT" "alpha lines" "Run 1: merge has alpha header"
assert_file_contains "$MERGE_OUTPUT" "beta manifest" "Run 1: merge has beta header"
assert_file_contains "$FINALIZE_SUMMARY" "finalized" "Run 1: finalize summary has marker"

# Verify split_alpha created per-line files (input has 2 lines)
assert_file_exists "${SPLIT_ALPHA_DIR}/0.txt"
assert_file_exists "${SPLIT_ALPHA_DIR}/1.txt"
assert_file_contains "${SPLIT_ALPHA_DIR}/0.txt" "initial content" "Run 1: alpha line 0 correct"
assert_file_contains "${SPLIT_ALPHA_DIR}/1.txt" "second line" "Run 1: alpha line 1 correct"

# Verify split_beta dir has the expected files
assert_file_exists "${SPLIT_BETA_DIR}/config.json"
assert_file_exists "${SPLIT_BETA_DIR}/records.csv"
assert_file_exists "${SPLIT_BETA_DIR}/schema.json"

# Verify finalize artifacts dir
assert_file_exists "${FINALIZE_DIR}/combined.txt"
assert_file_exists "${FINALIZE_DIR}/line_count.txt"

# All rules should have been executed (cache miss)
echo ""
echo "--- Run 1: verify cache status ---"
assert_all_miss "Run 1"

# ========================================================================= #
# Run 2: No changes — expect cache hit on everything
# ========================================================================= #

run_graph "run 2 (no changes, expect cache hit)"

echo ""
echo "--- Run 2: verify cache hits ---"
assert_all_hit "Run 2"

# ========================================================================= #
# Run 3: Modify input.txt — prepare changes, propagates downstream
#   prepare: MISS (file dep on input.txt changed)
#   split_alpha: MISS (rule dep on prepare, prepare targets changed)
#   split_beta: MISS (rule dep on prepare, prepare targets changed)
#   merge: MISS (rule deps on alpha+beta changed)
#   finalize: MISS (rule dep on merge changed)
# ========================================================================= #

echo ""
echo "--- Modifying input.txt ---"
printf 'modified content\nnew second line\nthird line' > "$INPUT_FILE"

run_graph "run 3 (input.txt changed, expect cache miss cascade)"

echo ""
echo "--- Run 3: verify cache misses ---"
assert_miss "$RULE_PREPARE" "Run 3"
assert_miss "$RULE_SPLIT_ALPHA" "Run 3"
assert_miss "$RULE_MERGE" "Run 3"
assert_miss "$RULE_FINALIZE" "Run 3"

# Verify updated content propagated
assert_file_contains "$PREPARE_INPUT_COPY" "modified content" "Run 3: prepare has modified input"
assert_file_contains "${SPLIT_ALPHA_DIR}/0.txt" "modified content" "Run 3: alpha line 0 updated"
assert_file_exists "${SPLIT_ALPHA_DIR}/2.txt"
assert_file_contains "${SPLIT_ALPHA_DIR}/2.txt" "third line" "Run 3: alpha line 2 has third line"

# ========================================================================= #
# Run 4: No changes — expect cache hit on everything
# ========================================================================= #

run_graph "run 4 (no changes after input mod, expect cache hit)"

echo ""
echo "--- Run 4: verify cache hits ---"
assert_all_hit "Run 4"

# ========================================================================= #
# Run 5: Modify data/records.csv — split_beta has a glob dep on data/**
#   prepare: HIT (its deps didn't change — file(input.txt) + glob(*.json excl data/))
#   split_alpha: HIT (only depends on prepare rule, which didn't change)
#   split_beta: MISS (glob dep on data/**/*.csv changed)
#   merge: MISS (rule dep on split_beta, beta targets changed)
#   finalize: HIT — merge re-ran but its output (combined.txt) is byte-identical
#             because merge only lists filenames from beta, not file contents.
# ========================================================================= #

echo ""
echo "--- Modifying data/records.csv ---"
printf 'id,name,value\n1,alpha,100\n2,beta,999\n3,gamma,300\n4,delta,400' > "$DATA_RECORDS"

run_graph "run 5 (data/records.csv changed, expect partial miss)"

echo ""
echo "--- Run 5: verify selective cache behavior ---"

# Prepare should be a cache hit — its deps are input.txt + *.json (excl data/**)
assert_hit "$RULE_PREPARE" "Run 5"

# Split alpha should be a cache hit — only depends on prepare rule
assert_hit "$RULE_SPLIT_ALPHA" "Run 5"

# Split beta should be a cache miss — glob dep on data/**/*.csv changed
assert_miss "$RULE_SPLIT_BETA" "Run 5"

# Merge should be a cache miss — rule dep on split_beta changed
assert_miss "$RULE_MERGE" "Run 5"

# Finalize should be a cache hit — merge re-ran but produced identical output
# (combined.txt only lists filenames, not file contents, so it didn't change)
assert_hit "$RULE_FINALIZE" "Run 5"

# Verify updated records propagated into beta
assert_file_contains "${SPLIT_BETA_DIR}/records.csv" "delta" "Run 5: beta dir has new record"

# ========================================================================= #
# Run 6: No changes — expect cache hit on everything
# ========================================================================= #

run_graph "run 6 (no changes after data mod, expect cache hit)"

echo ""
echo "--- Run 6: verify cache hits ---"
assert_all_hit "Run 6"

# ========================================================================= #
# Run 7: Modify config.json — prepare has a glob dep on *.json (excl data/**)
#   prepare: MISS (glob dep on *.json changed)
#   split_alpha: MISS (rule dep on prepare)
#   split_beta: MISS (rule dep on prepare)
#   merge: MISS (rule deps changed)
#   finalize: HIT — merge re-ran but its output (combined.txt) is byte-identical
#             because merge only lists filenames from beta, not file contents.
# ========================================================================= #

echo ""
echo "--- Modifying config.json ---"
printf '{"setting": "custom", "version": 2, "debug": true}' > "$CONFIG_FILE"

run_graph "run 7 (config.json changed, expect full cascade miss)"

echo ""
echo "--- Run 7: verify cache status ---"
assert_miss "$RULE_PREPARE" "Run 7"
assert_miss "$RULE_SPLIT_ALPHA" "Run 7"
assert_miss "$RULE_SPLIT_BETA" "Run 7"
assert_miss "$RULE_MERGE" "Run 7"

# Finalize should be a cache hit — merge re-ran but produced identical output
# (combined.txt only lists filenames, not file contents, so it didn't change)
assert_hit "$RULE_FINALIZE" "Run 7"

# Verify config change propagated
assert_file_contains "$PREPARE_CONFIG_COPY" '"debug"' "Run 7: prepare has updated config"
assert_file_contains "${SPLIT_BETA_DIR}/config.json" '"custom"' "Run 7: beta dir has updated config"

# ========================================================================= #
# Run 8: No changes — final cache hit verification
# ========================================================================= #

run_graph "run 8 (no changes after config mod, expect cache hit)"

echo ""
echo "--- Run 8: verify cache hits ---"
assert_all_hit "Run 8"

# ========================================================================= #
# Cleanup: restore original inputs
# ========================================================================= #

restore_all_inputs

echo ""
echo "========================================="
echo " ALL RCACHE TESTS PASSED"
echo "========================================="

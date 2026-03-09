"""
Tests for the rule cache (rcache) mechanism in spaces.

When a run_add_exec rule declares target_files or target_dirs, spaces computes
a digest from the rule definition and the content of files matching the deps.
If the digest matches a previous run, the targets are restored from cache and
the command is skipped. If the inputs or rule definition change, the digest
changes and the command re-runs.

This module creates a multi-stage dependency graph to exercise the rcache
comprehensively:

  ┌─────────────────────────────────────────────────────────────────────┐
  │                        Checkout Assets                             │
  │  input.txt   config.json   data/records.csv   data/schema.json    │
  └───────┬──────────┬──────────────┬──────────────────┬───────────────┘
          │          │              │                   │
          ▼          ▼              ▼                   ▼
  ┌───────────────────────────────────────────────────────────────────┐
  │  prepare  (target_files)                                         │
  │  deps: file(input.txt) + glob(*.json, exclude data/**)           │
  │  → copies input + config into build target files                 │
  └───────────────────┬───────────────────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
  ┌────────────────┐   ┌────────────────────────────────────────────┐
  │  split_alpha   │   │  split_beta                                │
  │  (target_dirs) │   │  (target_dirs + target_files)              │
  │  deps: rule    │   │  deps: rule(prepare) + glob(data/**)       │
  │    (prepare)   │   │  → merges prepare output with data/ files  │
  │  → extracts    │   └─────────────────┬──────────────────────────┘
  │    lines into  │                     │
  │    a directory │                     │
  └───────┬────────┘                     │
          │          ┌───────────────────┘
          ▼          ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  merge  (target_files)                                           │
  │  deps: rule(split_alpha) + rule(split_beta)                      │
  │  → combines outputs from both branches into a single file        │
  └───────────────────┬──────────────────────────────────────────────┘
                      │
                      ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  finalize  (target_dirs + target_files)                          │
  │  deps: rule(merge) + glob(spaces-e2e-testlab/**/*.star,          │
  │         exclude **/*test*, **/internal/run/**)                   │
  │  → writes a manifest dir + a summary file                       │
  └──────────────────────────────────────────────────────────────────┘

The companion script spaces-e2e-testlab/scripts/test_rcache.sh drives the
full test by recording timestamps, modifying inputs, and verifying cache
hit/miss behavior across all stages.
"""

load(
    "//@star/sdk/star/checkout.star",
    "checkout_add_asset",
)
load(
    "//@star/sdk/star/deps.star",
    "deps",
    "deps_glob",
)
load(
    "//@star/sdk/star/run.star",
    "run_add_exec",
    "run_type_all",
)

_PREFIX = "testlab/rcache"

# ===================================================================== #
# Paths (all workspace-root-relative)
# ===================================================================== #

# -- Checkout input assets ------------------------------------------------- #
_INPUT_FILE = "{}/input.txt".format(_PREFIX)
_CONFIG_FILE = "{}/config.json".format(_PREFIX)
_DATA_RECORDS = "{}/data/records.csv".format(_PREFIX)
_DATA_SCHEMA = "{}/data/schema.json".format(_PREFIX)

# -- Prepare outputs (target_files) ---------------------------------------- #
_PREPARE_INPUT_COPY = "build/{}/prepare/input_copy.txt".format(_PREFIX)
_PREPARE_CONFIG_COPY = "build/{}/prepare/config_copy.json".format(_PREFIX)

# -- Split alpha outputs (target_dirs only) -------------------------------- #
_SPLIT_ALPHA_DIR = "build/{}/split_alpha/lines".format(_PREFIX)

# -- Split beta outputs (target_dirs + target_files) ----------------------- #
_SPLIT_BETA_DIR = "build/{}/split_beta/merged".format(_PREFIX)
_SPLIT_BETA_MANIFEST = "build/{}/split_beta/manifest.txt".format(_PREFIX)

# -- Merge output (target_files) ------------------------------------------- #
_MERGE_OUTPUT = "build/{}/merge/combined.txt".format(_PREFIX)

# -- Finalize outputs (target_dirs + target_files) ------------------------- #
_FINALIZE_DIR = "build/{}/finalize/artifacts".format(_PREFIX)
_FINALIZE_SUMMARY = "build/{}/finalize/summary.txt".format(_PREFIX)

# ===================================================================== #
# Rule names
# ===================================================================== #

_PREPARE_RULE = "{}/prepare".format(_PREFIX)
_SPLIT_ALPHA_RULE = "{}/split_alpha".format(_PREFIX)
_SPLIT_BETA_RULE = "{}/split_beta".format(_PREFIX)
_MERGE_RULE = "{}/merge".format(_PREFIX)
_FINALIZE_RULE = "{}/finalize".format(_PREFIX)

# ===================================================================== #
# Scripts
# ===================================================================== #

_PREPARE_SCRIPT = " && ".join([
    "mkdir -p $(dirname {input_copy})".format(input_copy = _PREPARE_INPUT_COPY),
    "cp {src} {dst}".format(src = _INPUT_FILE, dst = _PREPARE_INPUT_COPY),
    "cp {src} {dst}".format(src = _CONFIG_FILE, dst = _PREPARE_CONFIG_COPY),
])

# Split alpha: write each line of the prepared input into its own numbered
# file inside the target directory.
_SPLIT_ALPHA_SCRIPT = " && ".join([
    "rm -rf {dir}".format(dir = _SPLIT_ALPHA_DIR),
    "mkdir -p {dir}".format(dir = _SPLIT_ALPHA_DIR),
    "n=0; while IFS= read -r line || [ -n \"$line\" ]; do echo \"$line\" > {dir}/${{n}}.txt; n=$((n+1)); done < {input}".format(
        dir = _SPLIT_ALPHA_DIR,
        input = _PREPARE_INPUT_COPY,
    ),
])

# Split beta: merge the prepared config with the data directory files and
# write a combined file plus a manifest listing what was merged.
_SPLIT_BETA_SCRIPT = " && ".join([
    "rm -rf {dir}".format(dir = _SPLIT_BETA_DIR),
    "mkdir -p {dir}".format(dir = _SPLIT_BETA_DIR),
    "mkdir -p $(dirname {manifest})".format(manifest = _SPLIT_BETA_MANIFEST),
    "cp {config} {dir}/config.json".format(
        config = _PREPARE_CONFIG_COPY,
        dir = _SPLIT_BETA_DIR,
    ),
    "cp {records} {dir}/records.csv".format(
        records = _DATA_RECORDS,
        dir = _SPLIT_BETA_DIR,
    ),
    "cp {schema} {dir}/schema.json".format(
        schema = _DATA_SCHEMA,
        dir = _SPLIT_BETA_DIR,
    ),
    "echo 'config.json' > {manifest}".format(manifest = _SPLIT_BETA_MANIFEST),
    "echo 'records.csv' >> {manifest}".format(manifest = _SPLIT_BETA_MANIFEST),
    "echo 'schema.json' >> {manifest}".format(manifest = _SPLIT_BETA_MANIFEST),
])

# Merge: combine the split_alpha line files and split_beta manifest into one.
_MERGE_SCRIPT = " && ".join([
    "mkdir -p $(dirname {output})".format(output = _MERGE_OUTPUT),
    "echo '=== alpha lines ===' > {output}".format(output = _MERGE_OUTPUT),
    "cat {alpha_dir}/*.txt >> {output} 2>/dev/null || true".format(
        alpha_dir = _SPLIT_ALPHA_DIR,
        output = _MERGE_OUTPUT,
    ),
    "echo '=== beta manifest ===' >> {output}".format(output = _MERGE_OUTPUT),
    "cat {manifest} >> {output}".format(
        manifest = _SPLIT_BETA_MANIFEST,
        output = _MERGE_OUTPUT,
    ),
    "echo '=== beta merged files ===' >> {output}".format(output = _MERGE_OUTPUT),
    "ls {beta_dir}/ >> {output}".format(
        beta_dir = _SPLIT_BETA_DIR,
        output = _MERGE_OUTPUT,
    ),
])

# Finalize: write an artifacts directory with copies of everything and a
# summary file with counts and a completion marker.
_FINALIZE_SCRIPT = " && ".join([
    "rm -rf {dir}".format(dir = _FINALIZE_DIR),
    "mkdir -p {dir}".format(dir = _FINALIZE_DIR),
    "mkdir -p $(dirname {summary})".format(summary = _FINALIZE_SUMMARY),
    "cp {merge_output} {dir}/combined.txt".format(
        merge_output = _MERGE_OUTPUT,
        dir = _FINALIZE_DIR,
    ),
    "wc -l < {merge_output} | tr -d ' ' > {dir}/line_count.txt".format(
        merge_output = _MERGE_OUTPUT,
        dir = _FINALIZE_DIR,
    ),
    "echo 'finalized' > {summary}".format(summary = _FINALIZE_SUMMARY),
    "echo \"lines: $(cat {dir}/line_count.txt)\" >> {summary}".format(dir = _FINALIZE_DIR, summary = _FINALIZE_SUMMARY),
    "echo \"merge_size: $(wc -c < {merge_output} | tr -d ' ')\" >> {summary}".format(
        merge_output = _MERGE_OUTPUT,
        summary = _FINALIZE_SUMMARY,
    ),
])

# ===================================================================== #
# Public API
# ===================================================================== #

def testlab_rcache_checkout():
    """Creates the input assets used by the rcache test rules during checkout."""
    checkout_add_asset(
        "{}/input".format(_PREFIX),
        content = "initial content\nsecond line",
        destination = _INPUT_FILE,
    )
    checkout_add_asset(
        "{}/config".format(_PREFIX),
        content = '{"setting": "default", "version": 1}',
        destination = _CONFIG_FILE,
    )
    checkout_add_asset(
        "{}/data_records".format(_PREFIX),
        content = "id,name,value\n1,alpha,100\n2,beta,200\n3,gamma,300",
        destination = _DATA_RECORDS,
    )
    checkout_add_asset(
        "{}/data_schema".format(_PREFIX),
        content = '{"fields": ["id", "name", "value"], "types": ["int", "str", "int"]}',
        destination = _DATA_SCHEMA,
    )

def testlab_rcache_run():
    """Adds a multi-stage rule graph that comprehensively exercises the rcache.

    The graph tests:
      - target_files only (prepare, merge)
      - target_dirs only (split_alpha)
      - target_dirs + target_files combined (split_beta, finalize)
      - deps with files (prepare)
      - deps with globs including includes/excludes (prepare, split_beta, finalize)
      - deps with rules (split_alpha, split_beta, merge, finalize)
      - fan-out (prepare → split_alpha + split_beta)
      - fan-in (split_alpha + split_beta → merge)
      - deep chaining (prepare → split → merge → finalize)
    """

    # ----------------------------------------------------------------- #
    # Stage 1: prepare
    #   deps: explicit file deps (input.txt) + glob on *.json at the
    #         prefix level, excluding the data/ subdirectory.
    #   targets: target_files only
    # ----------------------------------------------------------------- #
    run_add_exec(
        _PREPARE_RULE,
        command = "bash",
        args = ["-c", _PREPARE_SCRIPT],
        deps = deps(
            files = ["//" + _INPUT_FILE],
            globs = [deps_glob(
                includes = ["//{prefix}/*.json".format(prefix = _PREFIX)],
                excludes = ["//{prefix}/data/**".format(prefix = _PREFIX)],
            )],
        ),
        target_files = [
            "//" + _PREPARE_INPUT_COPY,
            "//" + _PREPARE_CONFIG_COPY,
        ],
        type = run_type_all(),
        help = "rcache test: prepare — copy input + config into build targets",
    )

    # ----------------------------------------------------------------- #
    # Stage 2a: split_alpha (fan-out branch A)
    #   deps: rule dep on prepare only
    #   targets: target_dirs only (exercises dir-only caching)
    # ----------------------------------------------------------------- #
    run_add_exec(
        _SPLIT_ALPHA_RULE,
        command = "bash",
        args = ["-c", _SPLIT_ALPHA_SCRIPT],
        deps = deps(rules = [":" + _PREPARE_RULE]),
        target_dirs = ["//" + _SPLIT_ALPHA_DIR],
        type = run_type_all(),
        help = "rcache test: split_alpha — split input lines into dir (target_dirs only)",
    )

    # ----------------------------------------------------------------- #
    # Stage 2b: split_beta (fan-out branch B)
    #   deps: rule dep on prepare + glob on the data/ subdirectory
    #         with includes for csv and json, excluding the top-level
    #         config.json.
    #   targets: target_dirs + target_files combined
    # ----------------------------------------------------------------- #
    run_add_exec(
        _SPLIT_BETA_RULE,
        command = "bash",
        args = ["-c", _SPLIT_BETA_SCRIPT],
        deps = deps(
            rules = [":" + _PREPARE_RULE],
            globs = [deps_glob(
                includes = [
                    "//{prefix}/data/**/*.csv".format(prefix = _PREFIX),
                    "//{prefix}/data/**/*.json".format(prefix = _PREFIX),
                ],
                excludes = [],
            )],
        ),
        target_dirs = ["//" + _SPLIT_BETA_DIR],
        target_files = ["//" + _SPLIT_BETA_MANIFEST],
        type = run_type_all(),
        help = "rcache test: split_beta — merge config+data (target_dirs + target_files)",
    )

    # ----------------------------------------------------------------- #
    # Stage 3: merge (fan-in)
    #   deps: rule deps on both split_alpha and split_beta
    #   targets: target_files only
    # ----------------------------------------------------------------- #
    run_add_exec(
        _MERGE_RULE,
        command = "bash",
        args = ["-c", _MERGE_SCRIPT],
        deps = deps(rules = [
            ":" + _SPLIT_ALPHA_RULE,
            ":" + _SPLIT_BETA_RULE,
        ]),
        target_files = ["//" + _MERGE_OUTPUT],
        type = run_type_all(),
        help = "rcache test: merge — combine both branches into one file",
    )

    # ----------------------------------------------------------------- #
    # Stage 4: finalize (deep chain terminus)
    #   deps: rule dep on merge + a broad glob on the testlab star
    #         files with excludes to exercise complex glob patterns.
    #   targets: target_dirs + target_files combined
    # ----------------------------------------------------------------- #
    run_add_exec(
        _FINALIZE_RULE,
        command = "bash",
        args = ["-c", _FINALIZE_SCRIPT],
        deps = deps(
            rules = [":" + _MERGE_RULE],
            globs = [deps_glob(
                includes = ["//spaces-e2e-testlab/**/*.star"],
                excludes = [
                    "//spaces-e2e-testlab/**/*test*.star",
                    "//spaces-e2e-testlab/internal/run/**",
                ],
            )],
        ),
        target_dirs = ["//" + _FINALIZE_DIR],
        target_files = ["//" + _FINALIZE_SUMMARY],
        type = run_type_all(),
        help = "rcache test: finalize — write artifacts dir + summary (target_dirs + target_files)",
    )

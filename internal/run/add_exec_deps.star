"""
Tests for run_add_exec dependency behavior defined in @star/sdk/star/run.star.

Exercises complex dependency configurations to verify:

  1. deps(files=[]) — empty file list means "run once per workspace".
     The rule executes on the first run but is skipped on subsequent
     runs because there are no file inputs whose changes would
     invalidate the cached result.

  2. deps(files=["//some/file"]) — the rule re-runs whenever any of
     the listed files have been modified since the last run.

  3. deps(rules=[...]) — the rule waits for the named rules to
     complete before executing.

  4. deps(globs=[...]) — the rule re-runs when any file matching
     the glob pattern has changed.

  5. Mixed deps — rules + files + globs combined in a single deps()
     call to verify they compose correctly.

  6. Multi-stage dependency graphs — fan-out, fan-in, and linear
     chains that exercise ordering through rule deps, with
     file/glob deps controlling cache invalidation at each stage.

The checkout phase creates input asset files that the run-phase rules
reference as file dependencies. All ordering validation happens inside
the run phase via rule deps; file/glob deps control *whether* a rule
re-executes (cache invalidation), not ordering.

Dependency graph for the multi-stage test:

  ┌──────────────────────────────────────────────────────────────────┐
  │                    Checkout Assets                               │
  │  source_a.txt   source_b.txt   config/settings.json             │
  └───────┬──────────────┬──────────────────┬────────────────────────┘
          │              │                  │
          ▼              ▼                  ▼
  ┌────────────┐  ┌────────────┐   ┌────────────────────────────────┐
  │  stage_a   │  │  stage_b   │   │  stage_c                       │
  │  files: a  │  │  files: b  │   │  globs: config/*.json          │
  └─────┬──────┘  └──────┬─────┘   └───────────┬────────────────────┘
        │                │                      │
        └───────┬────────┘                      │
                ▼                               │
        ┌──────────────┐                        │
        │   merge      │                        │
        │   rules:     │                        │
        │   a + b      │                        │
        └──────┬───────┘                        │
               │            ┌───────────────────┘
               ▼            ▼
        ┌────────────────────────────────────────┐
        │   finalize                              │
        │   rules: merge + stage_c               │
        │   files: source_a + source_b           │
        └────────────────────────────────────────┘
"""

load(
    "//@star/sdk/star/checkout.star",
    "checkout_add_asset",
)
load(
    "//@star/sdk/star/deps.star",
    "deps",
    "deps_glob",
    "deps_run_once",
)
load(
    "//@star/sdk/star/run.star",
    "run_add_exec",
    "run_inputs_once",
    "run_type_all",
)
load(
    "../test.star",
    "test_assert_file_contains",
    "test_assert_path_exists",
)

_PREFIX = "testlab/run_add_exec_deps"

# =========================================================================== #
# Paths (all workspace-root-relative)
# =========================================================================== #

# -- Checkout input assets ------------------------------------------------- #
_SOURCE_A = "{}/source_a.txt".format(_PREFIX)
_SOURCE_B = "{}/source_b.txt".format(_PREFIX)
_CONFIG_JSON = "{}/config/settings.json".format(_PREFIX)
_EXTRA_TXT = "{}/extra.txt".format(_PREFIX)

# -- Build outputs --------------------------------------------------------- #

def _build(name, filename = None):
    base = "build/{}/{}".format(_PREFIX, name)
    if filename:
        return "{}/{}".format(base, filename)
    return base

# =========================================================================== #
# Public API – checkout phase
# =========================================================================== #

def testlab_run_add_exec_deps_checkout():
    """Creates the input assets used by the dependency tests during checkout."""
    checkout_add_asset(
        "{}/source_a".format(_PREFIX),
        content = "content of source a\n",
        destination = _SOURCE_A,
    )
    checkout_add_asset(
        "{}/source_b".format(_PREFIX),
        content = "content of source b\n",
        destination = _SOURCE_B,
    )
    checkout_add_asset(
        "{}/config_json".format(_PREFIX),
        content = '{"setting": "default", "version": 1}\n',
        destination = _CONFIG_JSON,
    )
    checkout_add_asset(
        "{}/extra_txt".format(_PREFIX),
        content = "extra input for glob tests\n",
        destination = _EXTRA_TXT,
    )

# =========================================================================== #
# Public API – run phase
# =========================================================================== #

def testlab_run_add_exec_deps():
    """Tests run_add_exec with various deps configurations."""

    _test_empty_files_runs_once()
    _test_empty_files_no_targets()
    _test_inputs_empty_no_targets()
    _test_file_deps_single()
    _test_file_deps_multiple()
    _test_rule_deps_ordering()
    _test_glob_deps()
    _test_mixed_deps()
    _test_multi_stage_graph()

# =========================================================================== #
# 1. deps(files=[]) — run once per workspace
#
# When files is an empty list, the rule has no file inputs to track.
# The digest is constant so the rule executes on the first run and is
# cached on subsequent runs. We verify it produces its target file.
# =========================================================================== #

def _test_empty_files_runs_once():
    target = _build("empty_files", "output.txt")
    rule_name = "{}/empty_files".format(_PREFIX)
    run_add_exec(
        rule_name,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo 'ran_once' > {}".format(
            target,
            target,
        )],
        deps = deps(files = []),
        target_files = ["//" + target],
        type = run_type_all(),
        help = "deps(files=[]) — should run once then be cached",
    )
    test_assert_path_exists(target, deps = [":{}".format(rule_name)])
    test_assert_file_contains(
        "{}/empty_files_body".format(_PREFIX),
        target,
        "ran_once",
        deps = [":{}".format(rule_name)],
    )

# =========================================================================== #
# 1b. deps(files=[]) with no targets — run once, no artefacts
#
# Same empty-file-list semantics as above but without declaring any
# target_files or target_dirs. The rule simply succeeds (echo) and
# should run once per workspace.
# =========================================================================== #

def _test_empty_files_no_targets():
    rule_name = "{}/empty_files_no_targets".format(_PREFIX)
    run_add_exec(
        rule_name,
        command = "echo",
        args = ["empty_files_no_targets executed"],
        deps = deps_run_once([]),
        type = run_type_all(),
        help = "deps(files=[]) with no targets — should run once",
    )

# =========================================================================== #
# 1c. inputs=[] with no targets — run once, no artefacts
#
# Uses inputs=run_inputs_once() (i.e. []) instead of deps to express
# "run once per workspace". No deps, no targets — the rule simply
# succeeds and should not re-execute on subsequent runs.
# =========================================================================== #

def _test_inputs_empty_no_targets():
    rule_name = "{}/inputs_empty_no_targets".format(_PREFIX)
    run_add_exec(
        rule_name,
        command = "echo",
        args = ["inputs_empty_no_targets executed"],
        inputs = run_inputs_once(),
        type = run_type_all(),
        help = "inputs=[] with no targets — should run once",
    )

# =========================================================================== #
# 2. deps(files=["//path"]) — re-run when file changes
#
# A single file dep. The rule copies the source file into its target.
# If source_a.txt were modified between runs the rule would re-execute;
# here we just verify the plumbing works on the first run.
# =========================================================================== #

def _test_file_deps_single():
    target = _build("file_single", "copy.txt")
    rule_name = "{}/file_single".format(_PREFIX)
    run_add_exec(
        rule_name,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && cp {} {}".format(
            target,
            _SOURCE_A,
            target,
        )],
        deps = deps(files = ["//" + _SOURCE_A]),
        target_files = ["//" + target],
        type = run_type_all(),
        help = "deps(files=[source_a]) — re-runs when source_a changes",
    )
    test_assert_path_exists(target, deps = [":{}".format(rule_name)])
    test_assert_file_contains(
        "{}/file_single_body".format(_PREFIX),
        target,
        "content of source a",
        deps = [":{}".format(rule_name)],
    )

# =========================================================================== #
# 3. deps(files=[a, b]) — multiple file deps
#
# Two file deps. The rule concatenates both sources into the target.
# A change to either file would trigger a re-run.
# =========================================================================== #

def _test_file_deps_multiple():
    target = _build("file_multi", "combined.txt")
    rule_name = "{}/file_multi".format(_PREFIX)
    run_add_exec(
        rule_name,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && cat {} {} > {}".format(
            target,
            _SOURCE_A,
            _SOURCE_B,
            target,
        )],
        deps = deps(files = ["//" + _SOURCE_A, "//" + _SOURCE_B]),
        target_files = ["//" + target],
        type = run_type_all(),
        help = "deps(files=[a, b]) — re-runs when either file changes",
    )
    test_assert_path_exists(target, deps = [":{}".format(rule_name)])
    test_assert_file_contains(
        "{}/file_multi_has_a".format(_PREFIX),
        target,
        "content of source a",
        deps = [":{}".format(rule_name)],
    )
    test_assert_file_contains(
        "{}/file_multi_has_b".format(_PREFIX),
        target,
        "content of source b",
        deps = [":{}".format(rule_name)],
    )

# =========================================================================== #
# 4. deps(rules=[...]) — ordering via rule deps
#
# producer writes a file; consumer depends on producer via rule dep and
# reads that file. This verifies execution ordering.
# =========================================================================== #

def _test_rule_deps_ordering():
    producer_target = _build("rule_producer", "data.txt")
    producer_rule = "{}/rule_producer".format(_PREFIX)
    consumer_target = _build("rule_consumer", "result.txt")
    consumer_rule = "{}/rule_consumer".format(_PREFIX)

    run_add_exec(
        producer_rule,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo 'from_producer' > {}".format(
            producer_target,
            producer_target,
        )],
        target_files = ["//" + producer_target],
        type = run_type_all(),
        help = "rule deps: producer writes data.txt",
    )

    run_add_exec(
        consumer_rule,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && cat {} > {} && echo 'from_consumer' >> {}".format(
            consumer_target,
            producer_target,
            consumer_target,
            consumer_target,
        )],
        deps = deps(rules = [":{}".format(producer_rule)]),
        target_files = ["//" + consumer_target],
        type = run_type_all(),
        help = "rule deps: consumer reads producer output",
    )

    test_assert_path_exists(consumer_target, deps = [":{}".format(consumer_rule)])
    test_assert_file_contains(
        "{}/rule_consumer_has_producer".format(_PREFIX),
        consumer_target,
        "from_producer",
        deps = [":{}".format(consumer_rule)],
    )
    test_assert_file_contains(
        "{}/rule_consumer_has_consumer".format(_PREFIX),
        consumer_target,
        "from_consumer",
        deps = [":{}".format(consumer_rule)],
    )

# =========================================================================== #
# 5. deps(globs=[...]) — glob-based cache invalidation
#
# The rule depends on all .json files under the config/ directory.
# It copies the config into its target. A change to any matching file
# would invalidate the cache and cause a re-run.
# =========================================================================== #

def _test_glob_deps():
    target = _build("glob_deps", "config_snapshot.json")
    rule_name = "{}/glob_deps".format(_PREFIX)
    run_add_exec(
        rule_name,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && cp {} {}".format(
            target,
            _CONFIG_JSON,
            target,
        )],
        deps = deps(
            globs = [deps_glob(
                includes = ["//{}/config/**/*.json".format(_PREFIX)],
            )],
        ),
        target_files = ["//" + target],
        type = run_type_all(),
        help = "deps(globs=[config/*.json]) — re-runs when config changes",
    )
    test_assert_path_exists(target, deps = [":{}".format(rule_name)])
    test_assert_file_contains(
        "{}/glob_deps_body".format(_PREFIX),
        target,
        "default",
        deps = [":{}".format(rule_name)],
    )

# =========================================================================== #
# 6. Mixed deps — rules + files + globs in one call
#
# Combines all three dep types. The rule depends on:
#   - a prerequisite rule (ordering)
#   - a specific file (cache invalidation)
#   - a glob pattern (cache invalidation)
# =========================================================================== #

def _test_mixed_deps():
    prereq_target = _build("mixed_prereq", "prereq.txt")
    prereq_rule = "{}/mixed_prereq".format(_PREFIX)
    mixed_target = _build("mixed_main", "output.txt")
    mixed_rule = "{}/mixed_main".format(_PREFIX)

    # Prerequisite rule
    run_add_exec(
        prereq_rule,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo 'prereq_done' > {}".format(
            prereq_target,
            prereq_target,
        )],
        target_files = ["//" + prereq_target],
        type = run_type_all(),
        help = "mixed deps: prerequisite",
    )

    # Main rule with mixed deps
    run_add_exec(
        mixed_rule,
        command = "bash",
        args = ["-c", " && ".join([
            "mkdir -p $(dirname {})".format(mixed_target),
            "cat {} > {}".format(prereq_target, mixed_target),
            "cat {} >> {}".format(_SOURCE_A, mixed_target),
            "cat {} >> {}".format(_CONFIG_JSON, mixed_target),
            "echo 'mixed_done' >> {}".format(mixed_target),
        ])],
        deps = deps(
            rules = [":{}".format(prereq_rule)],
            files = ["//" + _SOURCE_A],
            globs = [deps_glob(
                includes = ["//{}/config/**/*.json".format(_PREFIX)],
            )],
        ),
        target_files = ["//" + mixed_target],
        type = run_type_all(),
        help = "mixed deps: rules + files + globs combined",
    )

    test_assert_path_exists(mixed_target, deps = [":{}".format(mixed_rule)])
    test_assert_file_contains(
        "{}/mixed_has_prereq".format(_PREFIX),
        mixed_target,
        "prereq_done",
        deps = [":{}".format(mixed_rule)],
    )
    test_assert_file_contains(
        "{}/mixed_has_source_a".format(_PREFIX),
        mixed_target,
        "content of source a",
        deps = [":{}".format(mixed_rule)],
    )
    test_assert_file_contains(
        "{}/mixed_has_config".format(_PREFIX),
        mixed_target,
        "default",
        deps = [":{}".format(mixed_rule)],
    )
    test_assert_file_contains(
        "{}/mixed_has_done".format(_PREFIX),
        mixed_target,
        "mixed_done",
        deps = [":{}".format(mixed_rule)],
    )

# =========================================================================== #
# 7. Multi-stage dependency graph
#
# Exercises fan-out, fan-in, and mixed dep types across multiple stages.
#
#   stage_a  (files: source_a)
#   stage_b  (files: source_b)
#   stage_c  (globs: config/*.json)
#       │          │          │
#       └────┬─────┘          │
#            ▼                │
#          merge              │
#       (rules: a+b)         │
#            │       ┌────────┘
#            ▼       ▼
#         finalize
#    (rules: merge+c, files: source_a+source_b)
# =========================================================================== #

# -- Stage outputs --------------------------------------------------------- #
_STAGE_A_OUT = _build("stage_a", "out.txt")
_STAGE_B_OUT = _build("stage_b", "out.txt")
_STAGE_C_OUT = _build("stage_c", "out.txt")
_MERGE_OUT = _build("merge", "combined.txt")
_FINALIZE_OUT = _build("finalize", "summary.txt")

# -- Rule names ------------------------------------------------------------ #
_STAGE_A_RULE = "{}/stage_a".format(_PREFIX)
_STAGE_B_RULE = "{}/stage_b".format(_PREFIX)
_STAGE_C_RULE = "{}/stage_c".format(_PREFIX)
_MERGE_RULE = "{}/merge".format(_PREFIX)
_FINALIZE_RULE = "{}/finalize".format(_PREFIX)

def _test_multi_stage_graph():
    # ----------------------------------------------------------------- #
    # Stage A: depends on source_a.txt (file dep for cache invalidation)
    # ----------------------------------------------------------------- #
    run_add_exec(
        _STAGE_A_RULE,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo 'stage_a:' > {} && cat {} >> {}".format(
            _STAGE_A_OUT,
            _STAGE_A_OUT,
            _SOURCE_A,
            _STAGE_A_OUT,
        )],
        deps = deps(files = ["//" + _SOURCE_A]),
        target_files = ["//" + _STAGE_A_OUT],
        type = run_type_all(),
        help = "multi-stage: stage_a — file dep on source_a",
    )

    # ----------------------------------------------------------------- #
    # Stage B: depends on source_b.txt (file dep for cache invalidation)
    # ----------------------------------------------------------------- #
    run_add_exec(
        _STAGE_B_RULE,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo 'stage_b:' > {} && cat {} >> {}".format(
            _STAGE_B_OUT,
            _STAGE_B_OUT,
            _SOURCE_B,
            _STAGE_B_OUT,
        )],
        deps = deps(files = ["//" + _SOURCE_B]),
        target_files = ["//" + _STAGE_B_OUT],
        type = run_type_all(),
        help = "multi-stage: stage_b — file dep on source_b",
    )

    # ----------------------------------------------------------------- #
    # Stage C: depends on config/*.json (glob dep for cache invalidation)
    # ----------------------------------------------------------------- #
    run_add_exec(
        _STAGE_C_RULE,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo 'stage_c:' > {} && cat {} >> {}".format(
            _STAGE_C_OUT,
            _STAGE_C_OUT,
            _CONFIG_JSON,
            _STAGE_C_OUT,
        )],
        deps = deps(
            globs = [deps_glob(
                includes = ["//{}/config/**/*.json".format(_PREFIX)],
            )],
        ),
        target_files = ["//" + _STAGE_C_OUT],
        type = run_type_all(),
        help = "multi-stage: stage_c — glob dep on config/*.json",
    )

    # ----------------------------------------------------------------- #
    # Merge: fan-in from stage_a + stage_b (rule deps for ordering)
    # ----------------------------------------------------------------- #
    run_add_exec(
        _MERGE_RULE,
        command = "bash",
        args = ["-c", " && ".join([
            "mkdir -p $(dirname {})".format(_MERGE_OUT),
            "echo 'merge:' > {}".format(_MERGE_OUT),
            "cat {} >> {}".format(_STAGE_A_OUT, _MERGE_OUT),
            "cat {} >> {}".format(_STAGE_B_OUT, _MERGE_OUT),
        ])],
        deps = deps(rules = [
            ":" + _STAGE_A_RULE,
            ":" + _STAGE_B_RULE,
        ]),
        target_files = ["//" + _MERGE_OUT],
        type = run_type_all(),
        help = "multi-stage: merge — fan-in from stage_a + stage_b",
    )

    # ----------------------------------------------------------------- #
    # Finalize: depends on merge + stage_c (rule deps) and on both
    # source files (file deps for cache invalidation). This exercises
    # the combination of rule ordering with file-based invalidation
    # in a single deps() call.
    # ----------------------------------------------------------------- #
    run_add_exec(
        _FINALIZE_RULE,
        command = "bash",
        args = ["-c", " && ".join([
            "mkdir -p $(dirname {})".format(_FINALIZE_OUT),
            "echo 'finalize:' > {}".format(_FINALIZE_OUT),
            "cat {} >> {}".format(_MERGE_OUT, _FINALIZE_OUT),
            "cat {} >> {}".format(_STAGE_C_OUT, _FINALIZE_OUT),
            "echo 'finalize_done' >> {}".format(_FINALIZE_OUT),
        ])],
        deps = deps(
            rules = [
                ":" + _MERGE_RULE,
                ":" + _STAGE_C_RULE,
            ],
            files = [
                "//" + _SOURCE_A,
                "//" + _SOURCE_B,
            ],
        ),
        target_files = ["//" + _FINALIZE_OUT],
        type = run_type_all(),
        help = "multi-stage: finalize — rules(merge+c) + files(a+b)",
    )

    # ----------------------------------------------------------------- #
    # Run-phase assertions on the finalize output
    # ----------------------------------------------------------------- #
    _fin_dep = [":{}".format(_FINALIZE_RULE)]

    test_assert_path_exists(_FINALIZE_OUT, deps = _fin_dep)
    test_assert_file_contains(
        "{}/finalize_has_stage_a".format(_PREFIX),
        _FINALIZE_OUT,
        "stage_a:",
        deps = _fin_dep,
    )
    test_assert_file_contains(
        "{}/finalize_has_source_a".format(_PREFIX),
        _FINALIZE_OUT,
        "content of source a",
        deps = _fin_dep,
    )
    test_assert_file_contains(
        "{}/finalize_has_stage_b".format(_PREFIX),
        _FINALIZE_OUT,
        "stage_b:",
        deps = _fin_dep,
    )
    test_assert_file_contains(
        "{}/finalize_has_source_b".format(_PREFIX),
        _FINALIZE_OUT,
        "content of source b",
        deps = _fin_dep,
    )
    test_assert_file_contains(
        "{}/finalize_has_stage_c".format(_PREFIX),
        _FINALIZE_OUT,
        "stage_c:",
        deps = _fin_dep,
    )
    test_assert_file_contains(
        "{}/finalize_has_config".format(_PREFIX),
        _FINALIZE_OUT,
        "default",
        deps = _fin_dep,
    )
    test_assert_file_contains(
        "{}/finalize_has_merge".format(_PREFIX),
        _FINALIZE_OUT,
        "merge:",
        deps = _fin_dep,
    )
    test_assert_file_contains(
        "{}/finalize_has_done".format(_PREFIX),
        _FINALIZE_OUT,
        "finalize_done",
        deps = _fin_dep,
    )

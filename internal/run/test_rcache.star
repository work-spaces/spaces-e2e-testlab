"""
Tests for the rule cache (rcache) mechanism in spaces.

When a run_add_exec rule declares target_files or target_dirs, spaces computes
a digest from the rule definition and the content of files matching the deps.
If the digest matches a previous run, the targets are restored from cache and
the command is skipped. If the inputs or rule definition change, the digest
changes and the command re-runs.

This module creates two rules to exercise the rcache:

  1. A **prepare** rule that copies the checkout input asset into a build
     target file. Its deps point at the raw checkout file so changes to the
     input propagate through the digest.

  2. A **transform** rule that depends on the prepare *rule*. Spaces treats
     the prepare rule's declared targets as file deps for the transform rule,
     so the transform digest changes whenever the prepare output changes.
     The transform rule appends a marker line to the prepare output and
     writes the result as its own target file.

Both rules are pure transformations with no side effects. The companion
script spaces-e2e-testlab/scripts/test_rcache.sh drives the full test by:
  - Recording timestamps of target files before and after each spaces run.
  - Modifying the checkout input file to simulate a developer edit.
  - Comparing timestamps and file content to verify that cache hits skip
    execution (targets unchanged) and cache misses re-run (targets updated).
"""

load(
    "//@star/sdk/star/checkout.star",
    "checkout_add_asset",
)
load(
    "//@star/sdk/star/deps.star",
    "deps",
)
load(
    "//@star/sdk/star/run.star",
    "run_add_exec",
    "run_type_all",
)

_PREFIX = "testlab/rcache"

# ---- Paths (all workspace-root-relative) --------------------------------- #

# The raw checkout input asset.
_INPUT_FILE = "{}/input.txt".format(_PREFIX)

# Prepare rule writes a copy of the input here (declared as a target file).
_PREPARE_OUTPUT = "build/{}/prepare/input_copy.txt".format(_PREFIX)

# Transform rule output file (declared as a target file).
_TRANSFORM_OUTPUT = "build/{}/transform/output.txt".format(_PREFIX)

# ---- Rule names ---------------------------------------------------------- #

_PREPARE_RULE = "{}/prepare".format(_PREFIX)
_TRANSFORM_RULE = "{}/transform".format(_PREFIX)

# ---- Scripts ------------------------------------------------------------- #

_PREPARE_SCRIPT = "mkdir -p $(dirname {output}) && cp {input} {output}".format(
    input = _INPUT_FILE,
    output = _PREPARE_OUTPUT,
)

_TRANSFORM_SCRIPT = (
    "mkdir -p $(dirname {output}) && " +
    "{{ cat {input}; echo 'transformed'; }} > {output}"
).format(
    input = _PREPARE_OUTPUT,
    output = _TRANSFORM_OUTPUT,
)

# ---- Public API ---------------------------------------------------------- #

def testlab_rcache_checkout():
    """Creates the input asset used by the rcache test rules during checkout."""
    checkout_add_asset(
        "{}/input".format(_PREFIX),
        content = "initial content",
        destination = _INPUT_FILE,
    )

def testlab_rcache_run():
    """Adds two run rules that together exercise the rcache.

    prepare rule:
      - Depends on the checkout input file via deps(files=[...]).
      - Declares _PREPARE_OUTPUT as a target_file so rcache is enabled.
      - Simply copies the input to the target.

    transform rule:
      - Depends on the prepare *rule* via deps(rules=[...]). Spaces treats
        the prepare rule's declared targets as file deps, so the transform
        digest changes whenever the prepare output changes — without the
        transform rule's own outputs feeding back into its digest.
      - Declares _TRANSFORM_OUTPUT as a target_file so rcache is enabled.
      - Copies the prepare output and appends a "transformed" marker line.
    """

    # Rule 1: prepare – copy checkout input into a build target file.
    run_add_exec(
        _PREPARE_RULE,
        command = "bash",
        args = ["-c", _PREPARE_SCRIPT],
        deps = deps(files = ["//" + _INPUT_FILE]),
        target_files = ["//" + _PREPARE_OUTPUT],
        type = run_type_all(),
        help = "rcache test: prepare input as a build target",
    )

    # Rule 2: transform – depends on prepare rule (targets become file deps).
    run_add_exec(
        _TRANSFORM_RULE,
        command = "bash",
        args = ["-c", _TRANSFORM_SCRIPT],
        deps = deps(rules = [":" + _PREPARE_RULE]),
        target_files = ["//" + _TRANSFORM_OUTPUT],
        type = run_type_all(),
        help = "rcache test: transform prepare output with marker",
    )

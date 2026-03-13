"""
Tests for checkout_add_exec defined in @star/sdk/star/checkout.star.

Exercises every parameter of checkout_add_exec and verifies that the
dependency graph executes tasks in the correct order. checkout_add_exec
can depend on:
  - checkout_add_repo rules (repo must be cloned before exec runs)
  - checkout_add_asset rules (asset must be written before exec runs)
  - other checkout_add_exec rules (chaining)

Dependency graph ordering is validated by having each step write or append
marker files during checkout. The checkout_add_exec steps themselves enforce
ordering — if a predecessor hasn't run, the dependent step will fail because
the file it tries to read won't exist. Run-phase assertions simply verify
the final output files contain the expected content. Run tasks have no deps
on checkout tasks because all checkout tasks complete before any run task
begins.
"""

load(
    "//@star/sdk/star/checkout.star",
    "CHECKOUT_EXPECT_ANY",
    "CHECKOUT_EXPECT_FAILURE",
    "checkout_add_asset",
    "checkout_add_exec",
    "checkout_add_repo",
    "checkout_clone_blobless",
)
load(
    "//@star/sdk/star/visibility.star",
    "visibility_private",
    "visibility_public",
)
load(
    "../test.star",
    "test_assert_file_contains",
    "test_assert_path_exists",
)

_PREFIX = "testlab/checkout_add_exec"

# =========================================================================== #
# Shared paths for dependency-order tests
# =========================================================================== #

_ASSET_FILE = "{}/seed_asset.txt".format(_PREFIX)
_ASSET_BODY = "seed asset content"
_REPO_PATH = "testlab/checkout_add_exec_repo"
_REPO_URL = "https://github.com/work-spaces/sdk"
_REPO_REV = "v0.3.16"

# =========================================================================== #
# Public API
# =========================================================================== #

def testlab_checkout_add_exec():
    """Tests checkout_add_exec with every parameter and dependency ordering."""

    # --- parameter coverage ------------------------------------------------ #
    _test_minimal()
    _test_help()
    _test_args()
    _test_env()
    _test_working_directory()
    _test_platforms()
    _test_redirect_stdout()
    _test_timeout()
    _test_expect_success()
    _test_expect_failure()
    _test_expect_any()
    _test_visibility_public()
    _test_visibility_private()
    _test_all_parameters()

    # --- dependency graph ordering ----------------------------------------- #
    _test_deps_on_asset()
    _test_deps_on_repo()
    _test_deps_on_exec()
    _test_diamond_dependency_graph()
    _test_linear_chain()

# =========================================================================== #
# Parameter coverage tests
# =========================================================================== #

# --------------------------------------------------------------------------- #
# Minimal – only required arguments
# --------------------------------------------------------------------------- #

def _test_minimal():
    checkout_add_exec(
        "{}/minimal".format(_PREFIX),
        command = "echo",
        args = ["checkout_add_exec minimal"],
    )

# --------------------------------------------------------------------------- #
# help
# --------------------------------------------------------------------------- #

def _test_help():
    checkout_add_exec(
        "{}/help".format(_PREFIX),
        command = "echo",
        args = ["help test"],
        help = "Verifies the help parameter is accepted by checkout_add_exec",
    )

# --------------------------------------------------------------------------- #
# args
# --------------------------------------------------------------------------- #

def _test_args():
    checkout_add_exec(
        "{}/args".format(_PREFIX),
        command = "echo",
        args = ["-n", "hello", "from", "checkout_add_exec"],
    )

# --------------------------------------------------------------------------- #
# env
# --------------------------------------------------------------------------- #

def _test_env():
    checkout_add_exec(
        "{}/env".format(_PREFIX),
        command = "bash",
        args = ["-c", "echo $TESTLAB_EXEC_VAR1:$TESTLAB_EXEC_VAR2"],
        env = {
            "TESTLAB_EXEC_VAR1": "alpha",
            "TESTLAB_EXEC_VAR2": "bravo",
        },
    )

# --------------------------------------------------------------------------- #
# working_directory
# --------------------------------------------------------------------------- #

def _test_working_directory():
    checkout_add_exec(
        "{}/working_directory".format(_PREFIX),
        command = "pwd",
        working_directory = "//spaces-e2e-testlab",
    )

# --------------------------------------------------------------------------- #
# platforms
# --------------------------------------------------------------------------- #

def _test_platforms():
    checkout_add_exec(
        "{}/platforms".format(_PREFIX),
        command = "echo",
        args = ["platform specific"],
        platforms = ["macos-aarch64", "macos-x86_64", "linux-x86_64", "linux-aarch64"],
    )

# --------------------------------------------------------------------------- #
# redirect_stdout
# --------------------------------------------------------------------------- #

def _test_redirect_stdout():
    _redirect_path = "{}/redirect_stdout.txt".format(_PREFIX)
    checkout_add_exec(
        "{}/redirect_stdout".format(_PREFIX),
        command = "echo",
        args = ["redirected from checkout_add_exec"],
        redirect_stdout = _redirect_path,
    )

# --------------------------------------------------------------------------- #
# timeout
# --------------------------------------------------------------------------- #

def _test_timeout():
    checkout_add_exec(
        "{}/timeout".format(_PREFIX),
        command = "echo",
        args = ["with timeout"],
        timeout = 30.0,
    )

# --------------------------------------------------------------------------- #
# expect – Success (default, explicit)
# --------------------------------------------------------------------------- #

def _test_expect_success():
    checkout_add_exec(
        "{}/expect_success".format(_PREFIX),
        command = "true",
        expect = "Success",
    )

# --------------------------------------------------------------------------- #
# expect – Failure
# --------------------------------------------------------------------------- #

def _test_expect_failure():
    checkout_add_exec(
        "{}/expect_failure".format(_PREFIX),
        command = "false",
        expect = CHECKOUT_EXPECT_FAILURE,
    )

# --------------------------------------------------------------------------- #
# expect – Any
# --------------------------------------------------------------------------- #

def _test_expect_any():
    checkout_add_exec(
        "{}/expect_any".format(_PREFIX),
        command = "true",
        expect = CHECKOUT_EXPECT_ANY,
    )

# --------------------------------------------------------------------------- #
# visibility – Public
# --------------------------------------------------------------------------- #

def _test_visibility_public():
    checkout_add_exec(
        "{}/visibility_public".format(_PREFIX),
        command = "echo",
        args = ["public rule"],
        visibility = visibility_public(),
    )

# --------------------------------------------------------------------------- #
# visibility – Private
# --------------------------------------------------------------------------- #

def _test_visibility_private():
    checkout_add_exec(
        "{}/visibility_private".format(_PREFIX),
        command = "echo",
        args = ["private rule"],
        visibility = visibility_private(),
    )

# --------------------------------------------------------------------------- #
# All parameters combined
# --------------------------------------------------------------------------- #

def _test_all_parameters():
    checkout_add_exec(
        "{}/all_parameters".format(_PREFIX),
        command = "bash",
        args = ["-c", "echo all:$TESTLAB_ALL_EXEC"],
        help = "Test with every parameter specified",
        env = {"TESTLAB_ALL_EXEC": "everything"},
        deps = [":{}/minimal".format(_PREFIX)],
        working_directory = "//spaces-e2e-testlab",
        platforms = ["macos-aarch64", "macos-x86_64", "linux-x86_64", "linux-aarch64"],
        timeout = 60.0,
        visibility = visibility_public(),
        expect = "Success",
    )

# =========================================================================== #
# Dependency graph ordering tests
#
# All ordering is enforced within the checkout phase. Each checkout_add_exec
# step reads output from its predecessor — if the predecessor hasn't
# completed, the command fails because the expected file is missing.
#
# Run-phase test_assert_* calls verify the final artefacts exist and contain
# the right content. They use no deps because all checkout tasks are
# guaranteed to be complete before any run task executes.
# =========================================================================== #

# --------------------------------------------------------------------------- #
# Exec depends on an asset
#
# An asset writes a seed file; the exec rule depends on it and reads the
# file to prove it exists, then writes its own marker.
# --------------------------------------------------------------------------- #

_ASSET_DEP_MARKER = "{}/asset_dep_marker.txt".format(_PREFIX)

def _test_deps_on_asset():
    # Checkout creates the seed asset
    checkout_add_asset(
        "{}/seed_asset".format(_PREFIX),
        content = _ASSET_BODY,
        destination = _ASSET_FILE,
    )

    # Exec depends on the asset and proves the file is available
    checkout_add_exec(
        "{}/after_asset".format(_PREFIX),
        command = "bash",
        args = [
            "-c",
            # Read the asset to prove it exists, then write our marker
            "cat {} && echo 'asset_dep_ok' > {}".format(_ASSET_FILE, _ASSET_DEP_MARKER),
        ],
        deps = [":{}/seed_asset".format(_PREFIX)],
    )

    # Run-phase: all checkout tasks done, just verify the marker file
    test_assert_path_exists(_ASSET_DEP_MARKER)
    test_assert_file_contains(
        "{}/asset_dep_marker_body".format(_PREFIX),
        _ASSET_DEP_MARKER,
        "asset_dep_ok",
    )

# --------------------------------------------------------------------------- #
# Exec depends on a repo
#
# A repo is cloned; the exec rule depends on it and verifies the clone
# directory exists before writing its marker.
# --------------------------------------------------------------------------- #

_REPO_DEP_MARKER = "{}/repo_dep_marker.txt".format(_PREFIX)

def _test_deps_on_repo():
    checkout_add_repo(
        _REPO_PATH,
        url = _REPO_URL,
        rev = _REPO_REV,
        clone = checkout_clone_blobless(),
        is_evaluate_spaces_modules = False,
    )

    # Exec depends on the repo and verifies the clone is present
    checkout_add_exec(
        "{}/after_repo".format(_PREFIX),
        command = "bash",
        args = [
            "-c",
            "ls {}/star/checkout.star && echo 'repo_dep_ok' > {}".format(
                _REPO_PATH,
                _REPO_DEP_MARKER,
            ),
        ],
        deps = [":{}".format(_REPO_PATH)],
    )

    # Run-phase: all checkout tasks done, just verify the marker file
    test_assert_path_exists(_REPO_DEP_MARKER)
    test_assert_file_contains(
        "{}/repo_dep_marker_body".format(_PREFIX),
        _REPO_DEP_MARKER,
        "repo_dep_ok",
    )

# --------------------------------------------------------------------------- #
# Exec depends on another exec
#
# exec_a writes a file; exec_b depends on exec_a and reads that file,
# proving the ordering is honoured.
# --------------------------------------------------------------------------- #

_EXEC_A_OUTPUT = "{}/exec_a_output.txt".format(_PREFIX)
_EXEC_B_OUTPUT = "{}/exec_b_output.txt".format(_PREFIX)

def _test_deps_on_exec():
    checkout_add_exec(
        "{}/exec_chain_a".format(_PREFIX),
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo 'step_a' > {}".format(
            _EXEC_A_OUTPUT,
            _EXEC_A_OUTPUT,
        )],
    )

    checkout_add_exec(
        "{}/exec_chain_b".format(_PREFIX),
        command = "bash",
        args = ["-c", "cat {} > {} && echo 'step_b' >> {}".format(
            _EXEC_A_OUTPUT,
            _EXEC_B_OUTPUT,
            _EXEC_B_OUTPUT,
        )],
        deps = [":{}/exec_chain_a".format(_PREFIX)],
    )

    # Run-phase: exec_b_output must contain both step_a (copied from a) and step_b
    test_assert_path_exists(_EXEC_B_OUTPUT)
    test_assert_file_contains(
        "{}/exec_chain_b_has_a".format(_PREFIX),
        _EXEC_B_OUTPUT,
        "step_a",
    )
    test_assert_file_contains(
        "{}/exec_chain_b_has_b".format(_PREFIX),
        _EXEC_B_OUTPUT,
        "step_b",
    )

# --------------------------------------------------------------------------- #
# Diamond dependency graph
#
# Tests fan-out / fan-in ordering:
#
#        asset (seed)
#        /          \
#    left_exec    right_exec
#        \          /
#        join_exec
#
# Each branch reads the seed to prove it exists and writes its own marker.
# The join step reads both branch markers and combines them. Run-phase
# assertions verify the join output contains all three markers.
# --------------------------------------------------------------------------- #

_DIAMOND_LEFT = "{}/diamond/left.txt".format(_PREFIX)
_DIAMOND_RIGHT = "{}/diamond/right.txt".format(_PREFIX)
_DIAMOND_JOIN = "{}/diamond/join.txt".format(_PREFIX)

def _test_diamond_dependency_graph():
    # Root: asset creates the directory and seed marker
    checkout_add_asset(
        "{}/diamond_seed".format(_PREFIX),
        content = "diamond_seed",
        destination = "{}/diamond/seed.txt".format(_PREFIX),
    )

    # Left branch
    checkout_add_exec(
        "{}/diamond_left".format(_PREFIX),
        command = "bash",
        args = ["-c", " && ".join([
            "cat {}/diamond/seed.txt".format(_PREFIX),
            "echo 'diamond_left' > {}".format(_DIAMOND_LEFT),
        ])],
        deps = [":{}/diamond_seed".format(_PREFIX)],
    )

    # Right branch
    checkout_add_exec(
        "{}/diamond_right".format(_PREFIX),
        command = "bash",
        args = ["-c", " && ".join([
            "cat {}/diamond/seed.txt".format(_PREFIX),
            "echo 'diamond_right' > {}".format(_DIAMOND_RIGHT),
        ])],
        deps = [":{}/diamond_seed".format(_PREFIX)],
    )

    # Join: depends on both left and right
    checkout_add_exec(
        "{}/diamond_join".format(_PREFIX),
        command = "bash",
        args = ["-c", " && ".join([
            "cat {}".format(_DIAMOND_LEFT),
            "cat {}".format(_DIAMOND_RIGHT),
            "cat {} {} > {}".format(_DIAMOND_LEFT, _DIAMOND_RIGHT, _DIAMOND_JOIN),
            "echo 'diamond_join' >> {}".format(_DIAMOND_JOIN),
        ])],
        deps = [
            ":{}/diamond_left".format(_PREFIX),
            ":{}/diamond_right".format(_PREFIX),
        ],
    )

    # Run-phase: verify the join output contains markers from both branches and itself
    test_assert_path_exists(_DIAMOND_JOIN)
    test_assert_file_contains(
        "{}/diamond_join_has_left".format(_PREFIX),
        _DIAMOND_JOIN,
        "diamond_left",
    )
    test_assert_file_contains(
        "{}/diamond_join_has_right".format(_PREFIX),
        _DIAMOND_JOIN,
        "diamond_right",
    )
    test_assert_file_contains(
        "{}/diamond_join_has_join".format(_PREFIX),
        _DIAMOND_JOIN,
        "diamond_join",
    )

# --------------------------------------------------------------------------- #
# Linear chain: asset → exec1 → exec2 → exec3 → verify
#
# Each step appends its name to a shared log file. A final checkout_add_exec
# verification step reads the log and checks that all four markers appear
# in the correct line order (step0 on line 1, step1 on line 2, etc.).
# The verification writes a result file that is checked in the run phase.
#
# The asset writes "step0\n" as the first line. Each subsequent exec
# appends "stepN\n" using printf to avoid extra trailing newlines.
# The verify step uses awk to confirm each stepN appears on line N+1.
# --------------------------------------------------------------------------- #

_CHAIN_LOG = "{}/chain_log.txt".format(_PREFIX)
_CHAIN_VERIFY = "{}/chain_verify.txt".format(_PREFIX)

def _test_linear_chain():
    # Step 0: asset creates the log file with the first marker
    checkout_add_asset(
        "{}/chain_step0".format(_PREFIX),
        content = "step0\n",
        destination = _CHAIN_LOG,
    )

    # Step 1: exec appends marker, depends on asset
    checkout_add_exec(
        "{}/chain_step1".format(_PREFIX),
        command = "bash",
        args = ["-c", "printf 'step1\\n' >> {}".format(_CHAIN_LOG)],
        deps = [":{}/chain_step0".format(_PREFIX)],
    )

    # Step 2: exec appends marker, depends on step1
    checkout_add_exec(
        "{}/chain_step2".format(_PREFIX),
        command = "bash",
        args = ["-c", "printf 'step2\\n' >> {}".format(_CHAIN_LOG)],
        deps = [":{}/chain_step1".format(_PREFIX)],
    )

    # Step 3: exec appends marker, depends on step2
    checkout_add_exec(
        "{}/chain_step3".format(_PREFIX),
        command = "bash",
        args = ["-c", "printf 'step3\\n' >> {}".format(_CHAIN_LOG)],
        deps = [":{}/chain_step2".format(_PREFIX)],
    )

    # Verification step (still checkout phase): reads the log and asserts
    # line ordering using awk. Each "stepN" must appear on line N+1.
    # On success writes "chain_order_ok" to the verify file; on failure
    # prints diagnostics and exits non-zero.
    _verify_script = " && ".join([
        # Check line 1 is step0
        "awk 'NR==1 && $0!=\"step0\" {{ print \"FAIL line 1: expected step0 got \" $0 > \"/dev/stderr\"; exit 1 }}' {}".format(_CHAIN_LOG),
        # Check line 2 is step1
        "awk 'NR==2 && $0!=\"step1\" {{ print \"FAIL line 2: expected step1 got \" $0 > \"/dev/stderr\"; exit 1 }}' {}".format(_CHAIN_LOG),
        # Check line 3 is step2
        "awk 'NR==3 && $0!=\"step2\" {{ print \"FAIL line 3: expected step2 got \" $0 > \"/dev/stderr\"; exit 1 }}' {}".format(_CHAIN_LOG),
        # Check line 4 is step3
        "awk 'NR==4 && $0!=\"step3\" {{ print \"FAIL line 4: expected step3 got \" $0 > \"/dev/stderr\"; exit 1 }}' {}".format(_CHAIN_LOG),
        # All checks passed
        "echo 'chain_order_ok' > {}".format(_CHAIN_VERIFY),
    ])

    checkout_add_exec(
        "{}/chain_verify".format(_PREFIX),
        command = "bash",
        args = ["-c", _verify_script],
        deps = [":{}/chain_step3".format(_PREFIX)],
    )

    # Run-phase: all checkout done, just verify the result file
    test_assert_path_exists(_CHAIN_VERIFY)
    test_assert_file_contains(
        "{}/chain_verify_body".format(_PREFIX),
        _CHAIN_VERIFY,
        "chain_order_ok",
    )

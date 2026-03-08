"""
Tests for run_add_exec defined in @star/sdk/star/run.star.

Exercises every parameter of run_add_exec to verify that the function
accepts each combination without error and produces working run rules.
"""

load(
    "//@star/sdk/star/deps.star",
    "deps",
    "deps_glob",
)
load(
    "//@star/sdk/star/run.star",
    "run_add_exec",
    "run_expect_any",
    "run_expect_failure",
    "run_expect_success",
    "run_log_level_app",
    "run_log_level_passthrough",
    "run_type_all",
    "run_type_precommit",
    "run_type_setup",
    "run_type_test",
)
load(
    "//@star/sdk/star/visibility.star",
    "visibility_private",
    "visibility_public",
    "visibility_rules",
)
load(
    "../test.star",
    "test_assert_file_contains",
    "test_assert_path_exists",
)

_PREFIX = "testlab/run_add_exec"

def _build_path(rule_name, filename = None):
    """Returns a unique path under build/ for the given rule name.

    All paths are workspace-root-relative. Commands run at the workspace
    root by default, so these paths work for both target declarations
    and command arguments.

    Args:
        rule_name: The short rule name (without _PREFIX).
        filename: Optional filename to append. When None the path is a directory.

    Returns:
        A string like "build/testlab/run_add_exec/<rule_name>" or
        "build/testlab/run_add_exec/<rule_name>/<filename>".
    """
    base = "build/{}/{}".format(_PREFIX, rule_name)
    if filename:
        return "{}/{}".format(base, filename)
    return base

def testlab_run_add_exec():
    """Tests the run_add_exec function with all parameter combinations."""

    _test_minimal()
    _test_help()
    _test_args()
    _test_env()
    _test_deps()
    _test_deps_with_glob()
    _test_type_all()
    _test_type_test()
    _test_type_setup()
    _test_type_precommit()
    _test_type_none_defaults_to_optional()
    _test_working_directory()
    _test_platforms()
    _test_log_level_app()
    _test_log_level_passthrough()
    _test_redirect_stdout()
    _test_timeout()
    _test_expect_success()
    _test_expect_failure()
    _test_expect_any()
    _test_visibility_public()
    _test_visibility_private()
    _test_visibility_rules()
    _test_target_files()
    _test_target_dirs()
    _test_all_parameters()

# --------------------------------------------------------------------------- #
# Minimal – only required arguments
# --------------------------------------------------------------------------- #

def _test_minimal():
    run_add_exec(
        "{}/minimal".format(_PREFIX),
        command = "echo",
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# help
# --------------------------------------------------------------------------- #

def _test_help():
    run_add_exec(
        "{}/help".format(_PREFIX),
        command = "echo",
        args = ["help test"],
        help = "Verifies the help parameter is accepted",
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# args
# --------------------------------------------------------------------------- #

def _test_args():
    run_add_exec(
        "{}/args".format(_PREFIX),
        command = "echo",
        args = ["-n", "hello", "world"],
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# env
# --------------------------------------------------------------------------- #

def _test_env():
    run_add_exec(
        "{}/env".format(_PREFIX),
        command = "env",
        env = {
            "TESTLAB_ADD_EXEC_VAR1": "value1",
            "TESTLAB_ADD_EXEC_VAR2": "value2",
        },
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# deps
# --------------------------------------------------------------------------- #

def _test_deps():
    run_add_exec(
        "{}/deps".format(_PREFIX),
        command = "echo",
        args = ["after minimal"],
        deps = deps(rules = [":{}/minimal".format(_PREFIX)]),
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# deps with glob – exercises deps() with deps_glob()
# --------------------------------------------------------------------------- #

def _test_deps_with_glob():
    target_file = _build_path("deps_with_glob", "output.txt")
    rule_name = "{}/deps_with_glob".format(_PREFIX)
    dep = [":{}".format(rule_name)]
    run_add_exec(
        rule_name,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo 'glob deps test' > {}".format(target_file, target_file)],
        deps = deps(
            rules = [":{}/minimal".format(_PREFIX)],
            globs = [deps_glob(
                includes = ["spaces-e2e-testlab/**/*.star"],
                excludes = ["spaces-e2e-testlab/**/test_rcache.star"],
            )],
        ),
        target_files = ["//{}".format(target_file)],
        type = run_type_all(),
    )
    test_assert_path_exists(target_file, deps = dep)
    test_assert_file_contains(
        "{}/deps_with_glob_body".format(_PREFIX),
        target_file,
        "glob deps test",
        deps = dep,
    )

# --------------------------------------------------------------------------- #
# type – Run (all)
# --------------------------------------------------------------------------- #

def _test_type_all():
    run_add_exec(
        "{}/type_all".format(_PREFIX),
        command = "echo",
        args = ["type all"],
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# type – Test
# --------------------------------------------------------------------------- #

def _test_type_test():
    run_add_exec(
        "{}/type_test".format(_PREFIX),
        command = "echo",
        args = ["type test"],
        type = run_type_test(),
    )

# --------------------------------------------------------------------------- #
# type – Setup
# --------------------------------------------------------------------------- #

def _test_type_setup():
    run_add_exec(
        "{}/type_setup".format(_PREFIX),
        command = "echo",
        args = ["type setup"],
        type = run_type_setup(),
    )

# --------------------------------------------------------------------------- #
# type – PreCommit
# --------------------------------------------------------------------------- #

def _test_type_precommit():
    run_add_exec(
        "{}/type_precommit".format(_PREFIX),
        command = "echo",
        args = ["type precommit"],
        type = run_type_precommit(),
    )

# --------------------------------------------------------------------------- #
# type – None (defaults to Optional)
# --------------------------------------------------------------------------- #

def _test_type_none_defaults_to_optional():
    run_add_exec(
        "{}/type_none".format(_PREFIX),
        command = "echo",
        args = ["type none defaults to optional"],
    )

# --------------------------------------------------------------------------- #
# working_directory
# --------------------------------------------------------------------------- #

def _test_working_directory():
    run_add_exec(
        "{}/working_directory".format(_PREFIX),
        command = "pwd",
        working_directory = "//spaces-e2e-testlab",
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# platforms
# --------------------------------------------------------------------------- #

def _test_platforms():
    run_add_exec(
        "{}/platforms".format(_PREFIX),
        command = "echo",
        args = ["platform specific"],
        platforms = ["macos-aarch64", "macos-x86_64", "linux-x86_64", "linux-aarch64"],
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# log_level – App
# --------------------------------------------------------------------------- #

def _test_log_level_app():
    run_add_exec(
        "{}/log_level_app".format(_PREFIX),
        command = "echo",
        args = ["log level app"],
        log_level = run_log_level_app(),
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# log_level – Passthrough
# --------------------------------------------------------------------------- #

def _test_log_level_passthrough():
    run_add_exec(
        "{}/log_level_passthrough".format(_PREFIX),
        command = "echo",
        args = ["log level passthrough"],
        log_level = run_log_level_passthrough(),
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# redirect_stdout
# --------------------------------------------------------------------------- #

def _test_redirect_stdout():
    # redirect_stdout is a plain path; spaces automatically places it
    # under the build/ folder.
    redirect_arg = "{}/redirect_stdout/output.txt".format(_PREFIX)
    redirect_actual = "build/{}".format(redirect_arg)
    rule_name = "{}/redirect_stdout".format(_PREFIX)
    dep = [":{}".format(rule_name)]
    run_add_exec(
        rule_name,
        command = "echo",
        args = ["redirected content"],
        redirect_stdout = redirect_arg,
        type = run_type_all(),
    )
    test_assert_path_exists(redirect_actual, deps = dep)
    test_assert_file_contains(
        "{}/redirect_stdout_body".format(_PREFIX),
        redirect_actual,
        "redirected content",
        deps = dep,
    )

# --------------------------------------------------------------------------- #
# timeout
# --------------------------------------------------------------------------- #

def _test_timeout():
    run_add_exec(
        "{}/timeout".format(_PREFIX),
        command = "echo",
        args = ["with timeout"],
        timeout = 30.0,
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# expect – Success
# --------------------------------------------------------------------------- #

def _test_expect_success():
    run_add_exec(
        "{}/expect_success".format(_PREFIX),
        command = "true",
        expect = run_expect_success(),
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# expect – Failure
# --------------------------------------------------------------------------- #

def _test_expect_failure():
    run_add_exec(
        "{}/expect_failure".format(_PREFIX),
        command = "false",
        expect = run_expect_failure(),
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# expect – Any
# --------------------------------------------------------------------------- #

def _test_expect_any():
    run_add_exec(
        "{}/expect_any".format(_PREFIX),
        command = "true",
        expect = run_expect_any(),
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# visibility – Public
# --------------------------------------------------------------------------- #

def _test_visibility_public():
    run_add_exec(
        "{}/visibility_public".format(_PREFIX),
        command = "echo",
        args = ["public rule"],
        visibility = visibility_public(),
        type = run_type_all(),
    )

# --------------------------------------------------------------------------- #
# visibility – Private
# --------------------------------------------------------------------------- #

def _test_visibility_private():
    run_add_exec(
        "{}/visibility_private".format(_PREFIX),
        command = "echo",
        args = ["private rule"],
        visibility = visibility_private(),
    )

# --------------------------------------------------------------------------- #
# visibility – Rules
# --------------------------------------------------------------------------- #

def _test_visibility_rules():
    run_add_exec(
        "{}/visibility_rules".format(_PREFIX),
        command = "echo",
        args = ["rules visibility"],
        visibility = visibility_rules([":{}/minimal".format(_PREFIX)]),
    )

# --------------------------------------------------------------------------- #
# target_files
# --------------------------------------------------------------------------- #

def _test_target_files():
    target_file = _build_path("target_files", "output.txt")
    rule_name = "{}/target_files".format(_PREFIX)
    dep = [":{}".format(rule_name)]
    run_add_exec(
        rule_name,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo 'target file content' > {}".format(target_file, target_file)],
        target_files = ["//{}".format(target_file)],
        type = run_type_all(),
    )
    test_assert_path_exists(target_file, deps = dep)
    test_assert_file_contains(
        "{}/target_files_body".format(_PREFIX),
        target_file,
        "target file content",
        deps = dep,
    )

# --------------------------------------------------------------------------- #
# target_dirs – directory whose contents are unknown to the rule
# --------------------------------------------------------------------------- #

def _test_target_dirs():
    target_dir = _build_path("target_dirs", "discovered")
    rule_name = "{}/target_dirs".format(_PREFIX)
    dep = [":{}".format(rule_name)]
    run_add_exec(
        rule_name,
        command = "bash",
        args = ["-c", "mkdir -p {}   && echo 'file in target dir' > {}/listing.txt".format(target_dir, target_dir)],
        target_dirs = [target_dir],
        log_level = "Passthrough",
        type = run_type_all(),
    )
    test_assert_path_exists(target_dir, deps = dep)

# --------------------------------------------------------------------------- #
# All parameters combined
# --------------------------------------------------------------------------- #

def _test_all_parameters():
    all_file = _build_path("all_parameters", "result.txt")
    rule_name = "{}/all_parameters".format(_PREFIX)
    dep = [":{}".format(rule_name)]
    run_add_exec(
        rule_name,
        command = "bash",
        args = ["-c", "mkdir -p $(dirname {}) && echo \"all:$TESTLAB_ALL_PARAMS\" > {}".format(
            all_file,
            all_file,
        )],
        help = "Test with every parameter specified",
        env = {"TESTLAB_ALL_PARAMS": "everything"},
        deps = deps(rules = [":{}/minimal".format(_PREFIX)]),
        target_files = ["//{}".format(all_file)],
        type = run_type_all(),
        platforms = ["macos-aarch64", "macos-x86_64", "linux-x86_64", "linux-aarch64"],
        log_level = run_log_level_app(),
        timeout = 60.0,
        visibility = visibility_public(),
        expect = run_expect_success(),
    )
    test_assert_path_exists(all_file, deps = dep)
    test_assert_file_contains(
        "{}/all_parameters_body".format(_PREFIX),
        all_file,
        "all:everything",
        deps = dep,
    )

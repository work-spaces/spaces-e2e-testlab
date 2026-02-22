load("//@star/sdk/star/run.star", "run_add_exec", "run_expect_failure", "run_type_all")
load("//@star/sdk/star/shell.star", "shell")

def test_assert_path_exists(path):
    run_add_exec(
        "{}_exists".format(path),
        command = "ls",
        args = [path],
        type = run_type_all(),
    )

def test_assert_path_not_exists(path):
    run_add_exec(
        "{}_not_exists".format(path),
        command = "ls",
        args = [path],
        expect = run_expect_failure(),
        type = run_type_all(),
    )

def test_git_is_blobless_clone(path):
    run_add_exec(
        "{}_is_blobless_clone".format(path),
        command = "git",
        args = ["config", "--get", "remote.origin.promisor"],
        type = run_type_all(),
        working_directory = "//{}".format(path),
    )

def test_git_is_shallow_clone(path):
    run_add_exec(
        "{}_is_shallow_clone".format(path),
        command = "git",
        args = ["rev-parse", "--is-shallow-repository"],
        working_directory = "//{}".format(path),
        type = run_type_all(),
    )

def test_assert_file_contains(name, path, expected):
    """Asserts that the file at path contains the expected string."""
    shell(
        name = name,
        script = "grep -qF '{}' '{}'".format(expected, path),
        type = run_type_all(),
    )

def test_assert_file_not_contains(name, path, unexpected):
    """Asserts that the file at path does not contain the unexpected string."""
    shell(
        name = name,
        script = "grep -qF '{}' '{}'".format(unexpected, path),
        expect = run_expect_failure(),
        type = run_type_all(),
    )

"""
Functions for testing sdk/checkout.star
"""

load(
    "//@star/sdk/star/checkout.star",
    "checkout_add_repo",
    "checkout_clone_blobless",
    "checkout_clone_default",
    "checkout_clone_shallow",
    "checkout_clone_worktree",
    "checkout_sparse_mode_cone",
    "checkout_sparse_mode_no_cone",
    "checkout_type_optional",
)
load(
    "//@star/sdk/star/info.star",
    "info_is_platform_linux",
    "info_is_platform_macos",
    "info_is_platform_windows",
)
load(
    "../test.star",
    "test_assert_path_exists",
    "test_assert_path_not_exists",
    "test_git_is_blobless_clone",
    "test_git_is_shallow_clone",
)

_TEST_URL = "https://github.com/work-spaces/install-spaces"
_TEST_REV = "v0.15.26"

def testlab_checkout_add_repo():
    """Tests checkout_add_repo with various parameter combinations."""

    # Test: Minimal arguments (name, url, rev) - uses defaults for everything else
    test_checkout_path = "testlab/checkout_add_repo_minimal"
    checkout_add_repo(
        test_checkout_path,
        url = _TEST_URL,
        rev = _TEST_REV,
    )
    test_assert_path_exists(test_checkout_path)

    # Test: Explicit clone mode - checkout_clone_blobless
    test_checkout_path = "testlab/checkout_add_repo_clone_blobless"
    checkout_add_repo(
        test_checkout_path,
        url = _TEST_URL,
        rev = _TEST_REV,
        clone = checkout_clone_blobless(),
    )
    test_git_is_blobless_clone(test_checkout_path)

    # Test 4: Clone mode shallow (rev must be a branch)
    test_checkout_path = "testlab/checkout_add_repo_clone_shallow"
    checkout_add_repo(
        test_checkout_path,
        url = _TEST_URL,
        rev = _TEST_REV,
        clone = checkout_clone_shallow(),
    )
    test_git_is_shallow_clone(test_checkout_path)

    # Test 6: is_evaluate_spaces_modules explicitly set to True
    test_checkout_path = "testlab/checkout_add_repo_evaluate_modules"
    checkout_add_repo(
        test_checkout_path,
        url = _TEST_URL,
        rev = _TEST_REV,
        is_evaluate_spaces_modules = True,
        type = checkout_type_optional(),
    )

    # Test 7: Sparse checkout with cone mode
    test_checkout_path = "testlab/checkout_add_repo_sparse_cone"
    checkout_add_repo(
        test_checkout_path,
        url = _TEST_URL,
        rev = _TEST_REV,
        sparse_mode = checkout_sparse_mode_no_cone(),
        sparse_list = ["README.md"],
        is_evaluate_spaces_modules = False,
    )
    test_assert_path_exists("{}/README.md".format(test_checkout_path))
    test_assert_path_not_exists("{}/action.yml".format(test_checkout_path))

    # Test 8: type = checkout_type_optional() to skip checkout
    test_checkout_path = "testlab/checkout_add_repo_optional"
    checkout_add_repo(
        test_checkout_path,
        url = _TEST_URL,
        rev = _TEST_REV,
        type = checkout_type_optional(),
    )
    test_assert_path_not_exists(test_checkout_path)

    # Test: With deps (depends on one of the earlier test rules)
    test_checkout_path = "testlab/checkout_add_repo_with_deps"
    checkout_add_repo(
        test_checkout_path,
        url = _TEST_URL,
        rev = _TEST_REV,
        deps = [":testlab/checkout_add_repo_minimal"],
        is_evaluate_spaces_modules = False,
        type = checkout_type_optional(),
    )
    test_assert_path_not_exists(test_checkout_path)

    # Test 10: With platforms set (use optional type so it doesn't fail on non-matching platforms)
    test_checkout_path = "testlab/checkout_add_repo_platforms"
    checkout_add_repo(
        test_checkout_path,
        url = _TEST_URL,
        rev = _TEST_REV,
        platforms = ["macos-aarch64"],
        is_evaluate_spaces_modules = False,
    )
    if info_is_platform_macos():
        test_assert_path_exists(test_checkout_path)
    else:
        test_assert_path_not_exists(test_checkout_path)

    # Test: With working_directory
    test_checkout_path = "testlab/checkout_add_repo_working_dir"
    checkout_add_repo(
        test_checkout_path,
        url = _TEST_URL,
        rev = _TEST_REV,
        working_directory = "testlab_checkout_add_repo_working_dir_parent",
        is_evaluate_spaces_modules = False,
        type = checkout_type_optional(),
    )

"""
Tests for workspace member path functions defined in @star/sdk/star/ws.star.

During checkout, the same repository (install-spaces) is cloned multiple times
at different tags to different workspace locations. During the run phase, the
workspace_*_member functions are used to look up those clones by URL, revision,
and semver — verifying round-trip correctness of the member registry.
"""

load(
    "//@star/sdk/star/checkout.star",
    "checkout_add_repo",
)
load(
    "//@star/sdk/star/run.star",
    "run_type_all",
)
load(
    "//@star/sdk/star/shell.star",
    "shell",
)
load(
    "//@star/sdk/star/ws.star",
    "workspace_check_member_semver",
    "workspace_get_path_to_member",
    "workspace_get_path_to_member_or_none",
    "workspace_get_path_to_member_with_rev",
    "workspace_get_path_to_member_with_semver",
    "workspace_is_path_to_member_available",
)

_PREFIX = "testlab/workspace_member"
_URL = "https://github.com/work-spaces/install-spaces"

# Two distinct tags used as revisions in checkout_add_repo.
# The workspace member registry stores the rev string exactly as passed,
# so lookups must use the tag name, not the resolved commit SHA.
# NOTE: These tags must NOT overlap with tags used by add_repo.star (v0.15.26)
# or any other test that checks out the same repo, otherwise the workspace
# member functions won't work (duplicate repo+rev across different paths).
_TAG_A = "v0.15.20"
_PATH_A = "{}/install_spaces_a".format(_PREFIX)

_TAG_B = "v0.15.21"
_PATH_B = "{}/install_spaces_b".format(_PREFIX)

# A tag that is NOT checked out — used for negative tests.
_TAG_MISSING = "v0.9.7"

# --------------------------------------------------------------------------- #
# Checkout phase: clone install-spaces at two different tags
# --------------------------------------------------------------------------- #

def testlab_checkout_workspace_member():
    """Clones install-spaces at two tags so member lookup functions can be tested."""
    checkout_add_repo(
        _PATH_A,
        url = _URL,
        rev = _TAG_A,
        is_evaluate_spaces_modules = False,
    )
    checkout_add_repo(
        _PATH_B,
        url = _URL,
        rev = _TAG_B,
        is_evaluate_spaces_modules = False,
    )

# --------------------------------------------------------------------------- #
# Run phase: verify every workspace member lookup function
# --------------------------------------------------------------------------- #

def testlab_run_workspace_member():
    """Creates run rules that assert workspace member path lookups are correct."""

    _test_is_path_to_member_available()
    _test_is_path_to_member_available_with_rev()
    _test_is_path_to_member_available_with_semver()
    _test_is_path_to_member_available_missing()
    _test_get_path_to_member()
    _test_get_path_to_member_with_rev()
    _test_get_path_to_member_with_semver()
    _test_get_path_to_member_or_none_found()
    _test_get_path_to_member_or_none_missing()
    _test_check_member_semver()

# --------------------------------------------------------------------------- #
# workspace_is_path_to_member_available — URL only
# --------------------------------------------------------------------------- #

def _test_is_path_to_member_available():
    result = workspace_is_path_to_member_available(url = _URL)
    _assert_equal(
        "{}/is_available_url_only".format(_PREFIX),
        result,
        True,
        "workspace_is_path_to_member_available(url) should be True",
    )

# --------------------------------------------------------------------------- #
# workspace_is_path_to_member_available — URL + rev
# --------------------------------------------------------------------------- #

def _test_is_path_to_member_available_with_rev():
    result_a = workspace_is_path_to_member_available(url = _URL, rev = _TAG_A)
    _assert_equal(
        "{}/is_available_rev_a".format(_PREFIX),
        result_a,
        True,
        "is_path_to_member_available with tag A should be True",
    )

    result_b = workspace_is_path_to_member_available(url = _URL, rev = _TAG_B)
    _assert_equal(
        "{}/is_available_rev_b".format(_PREFIX),
        result_b,
        True,
        "is_path_to_member_available with tag B should be True",
    )

# --------------------------------------------------------------------------- #
# workspace_is_path_to_member_available — URL + semver
# --------------------------------------------------------------------------- #

def _test_is_path_to_member_available_with_semver():
    result = workspace_is_path_to_member_available(url = _URL, semver = ">=0.15.20")
    _assert_equal(
        "{}/is_available_semver".format(_PREFIX),
        result,
        True,
        "is_path_to_member_available with semver >=0.15.20 should be True",
    )

# --------------------------------------------------------------------------- #
# workspace_is_path_to_member_available — missing member
# --------------------------------------------------------------------------- #

def _test_is_path_to_member_available_missing():
    result = workspace_is_path_to_member_available(url = _URL, rev = _TAG_MISSING)
    _assert_equal(
        "{}/is_available_missing".format(_PREFIX),
        result,
        False,
        "is_path_to_member_available with unchecked-out tag should be False",
    )

# --------------------------------------------------------------------------- #
# workspace_get_path_to_member — URL only (returns one of the clones)
# --------------------------------------------------------------------------- #

def _test_get_path_to_member():
    path = workspace_get_path_to_member(url = _URL)

    # With two clones of the same URL, either path is acceptable.
    _assert_one_of(
        "{}/get_path_url_only".format(_PREFIX),
        path,
        [_PATH_A, _PATH_B],
        "workspace_get_path_to_member(url) should return one of the clone paths",
    )

# --------------------------------------------------------------------------- #
# workspace_get_path_to_member_with_rev
# --------------------------------------------------------------------------- #

def _test_get_path_to_member_with_rev():
    path_a = workspace_get_path_to_member_with_rev(url = _URL, rev = _TAG_A)
    _assert_equal(
        "{}/get_path_rev_a".format(_PREFIX),
        path_a,
        _PATH_A,
        "get_path_to_member_with_rev for tag A should return PATH_A",
    )

    path_b = workspace_get_path_to_member_with_rev(url = _URL, rev = _TAG_B)
    _assert_equal(
        "{}/get_path_rev_b".format(_PREFIX),
        path_b,
        _PATH_B,
        "get_path_to_member_with_rev for tag B should return PATH_B",
    )

# --------------------------------------------------------------------------- #
# workspace_get_path_to_member_with_semver
# --------------------------------------------------------------------------- #

def _test_get_path_to_member_with_semver():
    # Exact match on tag A's version
    path_exact = workspace_get_path_to_member_with_semver(url = _URL, semver = "=0.15.20")
    _assert_equal(
        "{}/get_path_semver_exact_a".format(_PREFIX),
        path_exact,
        _PATH_A,
        "get_path_to_member_with_semver =0.15.20 should return PATH_A",
    )

    # Exact match on tag B's version
    path_exact_b = workspace_get_path_to_member_with_semver(url = _URL, semver = "=0.15.21")
    _assert_equal(
        "{}/get_path_semver_exact_b".format(_PREFIX),
        path_exact_b,
        _PATH_B,
        "get_path_to_member_with_semver =0.15.21 should return PATH_B",
    )

# --------------------------------------------------------------------------- #
# workspace_get_path_to_member_or_none — found
# --------------------------------------------------------------------------- #

def _test_get_path_to_member_or_none_found():
    path = workspace_get_path_to_member_or_none(url = _URL, rev = _TAG_A)
    _assert_equal(
        "{}/get_path_or_none_found".format(_PREFIX),
        path,
        _PATH_A,
        "get_path_to_member_or_none with tag A should return PATH_A",
    )

# --------------------------------------------------------------------------- #
# workspace_get_path_to_member_or_none — missing (should return None)
# --------------------------------------------------------------------------- #

def _test_get_path_to_member_or_none_missing():
    path = workspace_get_path_to_member_or_none(url = _URL, rev = _TAG_MISSING)
    _assert_equal(
        "{}/get_path_or_none_missing".format(_PREFIX),
        path,
        None,
        "get_path_to_member_or_none with unchecked-out tag should return None",
    )

# --------------------------------------------------------------------------- #
# workspace_check_member_semver
# --------------------------------------------------------------------------- #

def _test_check_member_semver():
    # Should match: we have 0.15.20 and 0.15.21
    result_match = workspace_check_member_semver(url = _URL, semver = ">=0.15.20")
    _assert_equal(
        "{}/check_semver_match".format(_PREFIX),
        result_match,
        True,
        "check_member_semver >=0.15.20 should be True",
    )

    # Should match with caret range
    result_caret = workspace_check_member_semver(url = _URL, semver = "^0.15.20")
    _assert_equal(
        "{}/check_semver_caret".format(_PREFIX),
        result_caret,
        True,
        "check_member_semver ^0.15.20 should be True",
    )

    # Should not match: we don't have anything >= 1.0.0
    result_no_match = workspace_check_member_semver(url = _URL, semver = ">=1.0.0")
    _assert_equal(
        "{}/check_semver_no_match".format(_PREFIX),
        result_no_match,
        False,
        "check_member_semver >=1.0.0 should be False",
    )

# --------------------------------------------------------------------------- #
# Assertion helpers
# --------------------------------------------------------------------------- #

def _assert_equal(rule_name, actual, expected, message):
    """Creates a run rule that passes if actual == expected, fails otherwise."""
    if actual == expected:
        script = "echo 'PASS: {}'".format(message)
    else:
        script = "echo 'FAIL: {} — expected: {} got: {}' >&2 && exit 1".format(
            message,
            expected,
            actual,
        )
    shell(
        name = rule_name,
        script = script,
        type = run_type_all(),
    )

def _assert_one_of(rule_name, actual, allowed, message):
    """Creates a run rule that passes if actual is in the allowed list."""
    if actual in allowed:
        script = "echo 'PASS: {}'".format(message)
    else:
        script = "echo 'FAIL: {} — got: {} not in {}' >&2 && exit 1".format(
            message,
            actual,
            allowed,
        )
    shell(
        name = rule_name,
        script = script,
        type = run_type_all(),
    )

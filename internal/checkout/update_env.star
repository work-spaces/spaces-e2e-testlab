"""
Checkout Update Env Testing
"""

load("//@star/sdk/star/checkout.star", "checkout_update_env")
load(
    "//@star/sdk/star/ws.star",
    "workspace_get_env_var",
    "workspace_get_env_var_or",
    "workspace_get_env_var_or_none",
    "workspace_is_env_var_set",
    "workspace_is_env_var_set_to",
)

_TESTLAB_ENV_VAR1 = "TESTLAB_ENV_VAR1"
_TESTLAB_ENV_VAR1_VALUE = "hello"
_TESTLAB_ENV_VAR2 = "TESTLAB_ENV_VAR2"
_TESTLAB_ENV_VAR2_VALUE = "world"
_TESTLAB_ENV_NONEXISTENT = "TESTLAB_ENV_NONEXISTENT_VAR_THAT_SHOULD_NEVER_EXIST"

_EXPECTED_PATHS = [
    "testlab/env_test_bin",
    "testlab/combined_bin",
]

_EXPECTED_SYSTEM_PATHS = [
    "/usr/bin",
    "/bin",
    "/usr/local/bin",
]

def _find_part_index(parts, expected):
    """Returns the index of the first PATH part that ends with expected, or -1."""
    for i in range(len(parts)):
        if parts[i] == expected or parts[i].endswith("/{}".format(expected)):
            return i
    return -1

def testlab_checkout_update_env():
    """Sets up environment variables to be validated by testlab_run_update_env_tests."""

    # Test: vars with simple key-value pairs
    checkout_update_env(
        "testlab_update_env_vars",
        vars = {
            _TESTLAB_ENV_VAR1: _TESTLAB_ENV_VAR1_VALUE,
            _TESTLAB_ENV_VAR2: _TESTLAB_ENV_VAR2_VALUE,
        },
    )

    # Test: paths added to PATH
    checkout_update_env(
        "testlab_update_env_paths",
        paths = [_EXPECTED_PATHS[0]],
    )

    # Test: system_paths added to PATH
    checkout_update_env(
        "testlab_update_env_system_paths",
        system_paths = [_EXPECTED_SYSTEM_PATHS[0], _EXPECTED_SYSTEM_PATHS[1]],
    )

    # Test: inherited_vars from calling environment
    checkout_update_env(
        "testlab_update_env_inherited",
        inherited_vars = ["HOME"],
    )

    # Test: optional_inherited_vars that may or may not exist
    checkout_update_env(
        "testlab_update_env_optional_inherited",
        optional_inherited_vars = ["TESTLAB_OPTIONAL_VAR_MAYBE_SET"],
    )

    # Test: all parameter types combined
    checkout_update_env(
        "testlab_update_env_combined",
        vars = {"TESTLAB_COMBINED_VAR": "combined_value"},
        paths = [_EXPECTED_PATHS[1]],
        system_paths = [_EXPECTED_SYSTEM_PATHS[2]],
        inherited_vars = ["USER"],
        optional_inherited_vars = ["EDITOR"],
    )

def testlab_run_update_env_tests():
    """Validates env vars set by testlab_checkout_update_env using ws.star functions."""

    # Validate workspace_is_env_var_set returns True for vars we set
    if not workspace_is_env_var_set(_TESTLAB_ENV_VAR1):
        checkout.abort("workspace_is_env_var_set('{}') returned False, expected True".format(_TESTLAB_ENV_VAR1))

    if not workspace_is_env_var_set(_TESTLAB_ENV_VAR2):
        checkout.abort("workspace_is_env_var_set('{}') returned False, expected True".format(_TESTLAB_ENV_VAR2))

    # Validate workspace_is_env_var_set returns False for a var we never set
    if workspace_is_env_var_set(_TESTLAB_ENV_NONEXISTENT):
        checkout.abort("workspace_is_env_var_set('{}') returned True, expected False".format(_TESTLAB_ENV_NONEXISTENT))

    # Validate workspace_get_env_var returns the correct values
    actual1 = workspace_get_env_var(_TESTLAB_ENV_VAR1)
    if actual1 != _TESTLAB_ENV_VAR1_VALUE:
        checkout.abort("workspace_get_env_var('{}') returned '{}', expected '{}'".format(
            _TESTLAB_ENV_VAR1,
            actual1,
            _TESTLAB_ENV_VAR1_VALUE,
        ))

    actual2 = workspace_get_env_var(_TESTLAB_ENV_VAR2)
    if actual2 != _TESTLAB_ENV_VAR2_VALUE:
        checkout.abort("workspace_get_env_var('{}') returned '{}', expected '{}'".format(
            _TESTLAB_ENV_VAR2,
            actual2,
            _TESTLAB_ENV_VAR2_VALUE,
        ))

    # Validate workspace_is_env_var_set_to with correct value returns True
    if not workspace_is_env_var_set_to(_TESTLAB_ENV_VAR1, _TESTLAB_ENV_VAR1_VALUE):
        checkout.abort("workspace_is_env_var_set_to('{}', '{}') returned False, expected True".format(
            _TESTLAB_ENV_VAR1,
            _TESTLAB_ENV_VAR1_VALUE,
        ))

    # Validate workspace_is_env_var_set_to with wrong value returns False
    if workspace_is_env_var_set_to(_TESTLAB_ENV_VAR1, "wrong_value"):
        checkout.abort("workspace_is_env_var_set_to('{}', 'wrong_value') returned True, expected False".format(
            _TESTLAB_ENV_VAR1,
        ))

    # Validate workspace_is_env_var_set_to with nonexistent var returns False
    if workspace_is_env_var_set_to(_TESTLAB_ENV_NONEXISTENT, "any_value"):
        checkout.abort("workspace_is_env_var_set_to('{}', 'any_value') returned True, expected False".format(
            _TESTLAB_ENV_NONEXISTENT,
        ))

    # Validate workspace_get_env_var_or returns the actual value when var exists
    or_result = workspace_get_env_var_or(_TESTLAB_ENV_VAR1, "fallback")
    if or_result != _TESTLAB_ENV_VAR1_VALUE:
        checkout.abort("workspace_get_env_var_or('{}', 'fallback') returned '{}', expected '{}'".format(
            _TESTLAB_ENV_VAR1,
            or_result,
            _TESTLAB_ENV_VAR1_VALUE,
        ))

    # Validate workspace_get_env_var_or returns fallback when var does not exist
    or_fallback = workspace_get_env_var_or(_TESTLAB_ENV_NONEXISTENT, "fallback_value")
    if or_fallback != "fallback_value":
        checkout.abort("workspace_get_env_var_or('{}', 'fallback_value') returned '{}', expected 'fallback_value'".format(
            _TESTLAB_ENV_NONEXISTENT,
            or_fallback,
        ))

    # Validate workspace_get_env_var_or_none returns the actual value when var exists
    or_none_result = workspace_get_env_var_or_none(_TESTLAB_ENV_VAR1)
    if or_none_result != _TESTLAB_ENV_VAR1_VALUE:
        checkout.abort("workspace_get_env_var_or_none('{}') returned '{}', expected '{}'".format(
            _TESTLAB_ENV_VAR1,
            or_none_result,
            _TESTLAB_ENV_VAR1_VALUE,
        ))

    # Validate workspace_get_env_var_or_none returns None when var does not exist
    or_none_missing = workspace_get_env_var_or_none(_TESTLAB_ENV_NONEXISTENT)
    if or_none_missing != None:
        checkout.abort("workspace_get_env_var_or_none('{}') returned '{}', expected None".format(
            _TESTLAB_ENV_NONEXISTENT,
            or_none_missing,
        ))

    # Validate the combined var was set
    if not workspace_is_env_var_set_to("TESTLAB_COMBINED_VAR", "combined_value"):
        checkout.abort("workspace_is_env_var_set_to('TESTLAB_COMBINED_VAR', 'combined_value') returned False, expected True")

    # Validate inherited HOME var is available
    if not workspace_is_env_var_set("HOME"):
        checkout.abort("workspace_is_env_var_set('HOME') returned False, expected True (inherited var)")

    # Split PATH and verify all paths and system_paths are present with correct ordering
    path_value = workspace_get_env_var_or_none("PATH")
    if path_value == None:
        checkout.abort("PATH is not set")

    parts = path_value.split(":")

    # Verify every expected path entry is present and record its index
    max_path_index = -1
    for expected in _EXPECTED_PATHS:
        index = _find_part_index(parts, expected)
        if index < 0:
            checkout.abort("PATH is missing expected paths entry '{}'. PATH={}".format(expected, path_value))
        if index > max_path_index:
            max_path_index = index

    # Verify every expected system_path entry is present and record its index
    min_system_path_index = len(parts)
    for expected in _EXPECTED_SYSTEM_PATHS:
        index = _find_part_index(parts, expected)
        if index < 0:
            checkout.abort("PATH is missing expected system_paths entry '{}'. PATH={}".format(expected, path_value))
        if index < min_system_path_index:
            min_system_path_index = index

    # All system_paths must come after all paths
    if max_path_index >= min_system_path_index:
        checkout.abort(
            "system_paths are not all after paths in PATH. " +
            "Last paths entry at index {}, first system_paths entry at index {}. PATH={}".format(
                max_path_index,
                min_system_path_index,
                path_value,
            ),
        )

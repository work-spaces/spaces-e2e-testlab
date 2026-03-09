"""
Tests for checkout_store_value defined in @star/sdk/star/checkout.star
and workspace_load_value defined in @star/sdk/star/ws.star.

During checkout, values of various types are stored using checkout_store_value.
During the run phase, workspace_load_value retrieves each value and assertions
verify the stored data survived the round-trip.
"""

load(
    "//@star/sdk/star/checkout.star",
    "checkout_store_value",
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
    "workspace_load_value",
)

_PREFIX = "testlab/store_value"

# --------------------------------------------------------------------------- #
# Values to store during checkout
# --------------------------------------------------------------------------- #

_STRING_KEY = "{}/string".format(_PREFIX)
_STRING_VALUE = "hello from store"

_INT_KEY = "{}/int".format(_PREFIX)
_INT_VALUE = 42

_FLOAT_KEY = "{}/float".format(_PREFIX)
_FLOAT_VALUE = 3.14

_BOOL_KEY = "{}/bool".format(_PREFIX)
_BOOL_VALUE = True

_LIST_KEY = "{}/list".format(_PREFIX)
_LIST_VALUE = ["alpha", "bravo", "charlie"]

_DICT_KEY = "{}/dict".format(_PREFIX)
_DICT_VALUE = {"name": "spaces", "version": 1, "enabled": True}

_NONE_KEY = "{}/none".format(_PREFIX)
_NONE_VALUE = None

_NESTED_KEY = "{}/nested".format(_PREFIX)
_NESTED_VALUE = {
    "outer": {
        "inner": [1, 2, 3],
        "flag": False,
    },
    "tags": ["a", "b"],
}

# --------------------------------------------------------------------------- #
# Checkout phase: store all values
# --------------------------------------------------------------------------- #

def testlab_checkout_store_value():
    """Stores values of every supported type during the checkout phase."""
    checkout_store_value(_STRING_KEY, _STRING_VALUE)
    checkout_store_value(_INT_KEY, _INT_VALUE)
    checkout_store_value(_FLOAT_KEY, _FLOAT_VALUE)
    checkout_store_value(_BOOL_KEY, _BOOL_VALUE)
    checkout_store_value(_LIST_KEY, _LIST_VALUE)
    checkout_store_value(_DICT_KEY, _DICT_VALUE)
    checkout_store_value(_NONE_KEY, _NONE_VALUE)
    checkout_store_value(_NESTED_KEY, _NESTED_VALUE)

# --------------------------------------------------------------------------- #
# Run phase: load and verify all values
# --------------------------------------------------------------------------- #

def testlab_run_store_value():
    """Loads stored values and asserts they match what was stored during checkout."""

    _assert_value("{}/string_roundtrip".format(_PREFIX), _STRING_KEY, _STRING_VALUE)
    _assert_value("{}/int_roundtrip".format(_PREFIX), _INT_KEY, _INT_VALUE)
    _assert_value("{}/float_roundtrip".format(_PREFIX), _FLOAT_KEY, _FLOAT_VALUE)
    _assert_value("{}/bool_roundtrip".format(_PREFIX), _BOOL_KEY, _BOOL_VALUE)
    _assert_value("{}/list_roundtrip".format(_PREFIX), _LIST_KEY, _LIST_VALUE)
    _assert_value("{}/dict_roundtrip".format(_PREFIX), _DICT_KEY, _DICT_VALUE)
    _assert_value("{}/none_roundtrip".format(_PREFIX), _NONE_KEY, _NONE_VALUE)
    _assert_value("{}/nested_roundtrip".format(_PREFIX), _NESTED_KEY, _NESTED_VALUE)

def _assert_value(rule_name, key, expected):
    """Creates a run rule that loads a stored value and asserts it matches expected."""
    actual = workspace_load_value(key)
    shell(
        name = rule_name,
        script = _build_assert_script(key, actual, expected),
        type = run_type_all(),
    )

def _build_assert_script(key, actual, expected):
    """Builds a shell script that checks actual == expected and prints diagnostics on failure."""
    if actual == expected:
        return "echo 'PASS: {} round-trip matched'".format(key)
    return "echo 'FAIL: {} expected: {} got: {}' >&2 && exit 1".format(
        key,
        expected,
        actual,
    )

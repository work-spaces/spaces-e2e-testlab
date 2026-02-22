"""
Tests for checkout_add_env_vars defined in @star/sdk/star/checkout.star
using the env helper functions from @star/sdk/star/env.star.
"""

load(
    "//@star/sdk/star/checkout.star",
    "checkout_add_env_vars",
    "checkout_type_optional",
)
load(
    "//@star/sdk/star/env.star",
    "env_append",
    "env_assign",
    "env_inherit",
    "env_prepend",
)
load(
    "//@star/sdk/star/visibility.star",
    "visibility_private",
    "visibility_public",
)
load(
    "//@star/sdk/star/ws.star",
    "workspace_get_env_var",
    "workspace_get_env_var_or",
    "workspace_get_env_var_or_none",
    "workspace_is_env_var_set",
    "workspace_is_env_var_set_to",
)

_PREFIX = "testlab/add_env_vars"

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #

_ASSIGN_VAR = "TESTLAB_ADD_ENV_ASSIGN"
_ASSIGN_VALUE = "assigned_value"

_PREPEND_VAR = "TESTLAB_ADD_ENV_PREPEND"
_PREPEND_VALUE_BASE = "base"
_PREPEND_VALUE_FRONT = "front"

_APPEND_VAR = "TESTLAB_ADD_ENV_APPEND"
_APPEND_VALUE_BASE = "base"
_APPEND_VALUE_BACK = "back"

_CUSTOM_SEP_VAR = "TESTLAB_ADD_ENV_CUSTOM_SEP"
_CUSTOM_SEP_VALUE_BASE = "first"
_CUSTOM_SEP_VALUE_EXTRA = "second"
_CUSTOM_SEPARATOR = ";"

_INHERIT_VAR = "HOME1"

_MULTI_ASSIGN_VAR1 = "TESTLAB_ADD_ENV_MULTI1"
_MULTI_ASSIGN_VAR1_VALUE = "multi_one"
_MULTI_ASSIGN_VAR2 = "TESTLAB_ADD_ENV_MULTI2"
_MULTI_ASSIGN_VAR2_VALUE = "multi_two"

_DEPS_VAR = "TESTLAB_ADD_ENV_DEPS"
_DEPS_VALUE = "deps_value"
_DEPS_LINK_VAR = "TESTLAB_ADD_ENV_DEPS_LINK"
_DEPS_LINK_VALUE = "deps_link_value"

_PLATFORM_VAR = "TESTLAB_ADD_ENV_PLATFORM"
_PLATFORM_VALUE = "platform_value"

_PUBLIC_VAR = "TESTLAB_ADD_ENV_PUBLIC"
_PUBLIC_VALUE = "public_value"
_PRIVATE_VAR = "TESTLAB_ADD_ENV_PRIVATE"
_PRIVATE_VALUE = "private_value"

_OPTIONAL_VAR = "TESTLAB_ADD_ENV_OPTIONAL_SHOULD_NOT_EXIST"

_INHERIT_DEFAULT_VAR = "TESTLAB_ADD_ENV_INHERIT_DEFAULT"
_INHERIT_DEFAULT_VALUE = "default_fallback"

# --------------------------------------------------------------------------- #
# Setup – called during checkout phase
# --------------------------------------------------------------------------- #

def testlab_checkout_add_env_vars():
    """Exercises checkout_add_env_vars with all env.star helper functions."""

    _test_assign()
    _test_prepend()
    _test_append()
    _test_custom_separator()
    _test_inherit()
    _test_inherit_with_default()
    _test_multiple_vars()
    _test_optional_type()
    _test_deps()
    _test_platforms()
    _test_visibility()

# --------------------------------------------------------------------------- #
# env_assign
# --------------------------------------------------------------------------- #

def _test_assign():
    checkout_add_env_vars(
        "{}/assign".format(_PREFIX),
        vars = [
            env_assign(
                name = _ASSIGN_VAR,
                value = _ASSIGN_VALUE,
                help = "Test env_assign via checkout_add_env_vars",
            ),
        ],
    )

# --------------------------------------------------------------------------- #
# env_prepend
# --------------------------------------------------------------------------- #

def _test_prepend():
    checkout_add_env_vars(
        "{}/prepend_base".format(_PREFIX),
        vars = [
            env_prepend(
                name = _PREPEND_VAR,
                value = _PREPEND_VALUE_BASE,
                help = "Base value for prepend test",
            ),
        ],
    )
    checkout_add_env_vars(
        "{}/prepend_front".format(_PREFIX),
        vars = [
            env_prepend(
                name = _PREPEND_VAR,
                value = _PREPEND_VALUE_FRONT,
                help = "Prepended value for prepend test",
            ),
        ],
        deps = [":{}/prepend_base".format(_PREFIX)],
    )

# --------------------------------------------------------------------------- #
# env_append
# --------------------------------------------------------------------------- #

def _test_append():
    checkout_add_env_vars(
        "{}/append_base".format(_PREFIX),
        vars = [
            env_append(
                name = _APPEND_VAR,
                value = _APPEND_VALUE_BASE,
                help = "Base value for append test",
            ),
        ],
    )
    checkout_add_env_vars(
        "{}/append_back".format(_PREFIX),
        vars = [
            env_append(
                name = _APPEND_VAR,
                value = _APPEND_VALUE_BACK,
                help = "Appended value for append test",
            ),
        ],
        deps = [":{}/append_base".format(_PREFIX)],
    )

# --------------------------------------------------------------------------- #
# env_append / env_prepend with custom separator
# --------------------------------------------------------------------------- #

def _test_custom_separator():
    checkout_add_env_vars(
        "{}/custom_sep_base".format(_PREFIX),
        vars = [
            env_append(
                name = _CUSTOM_SEP_VAR,
                value = _CUSTOM_SEP_VALUE_BASE,
                help = "Base value for custom separator test",
            ),
        ],
    )
    checkout_add_env_vars(
        "{}/custom_sep_append".format(_PREFIX),
        vars = [
            env_append(
                name = _CUSTOM_SEP_VAR,
                value = _CUSTOM_SEP_VALUE_EXTRA,
                help = "Appended value with custom separator",
                separator = _CUSTOM_SEPARATOR,
            ),
        ],
        deps = [":{}/custom_sep_base".format(_PREFIX)],
    )

# --------------------------------------------------------------------------- #
# env_inherit
# --------------------------------------------------------------------------- #

def _test_inherit():
    checkout_add_env_vars(
        "{}/inherit".format(_PREFIX),
        vars = [
            env_inherit(
                name = _INHERIT_VAR,
                is_required = True,
                assign_as_default = "myhome",
                is_secret = True,
                help = "Inherit HOME from calling environment",
            ),
        ],
    )

# --------------------------------------------------------------------------- #
# env_inherit with assign_as_default
# --------------------------------------------------------------------------- #

def _test_inherit_with_default():
    checkout_add_env_vars(
        "{}/inherit_default".format(_PREFIX),
        vars = [
            env_inherit(
                name = _INHERIT_DEFAULT_VAR,
                help = "Inherit with a default fallback",
                assign_as_default = _INHERIT_DEFAULT_VALUE,
            ),
        ],
    )

# --------------------------------------------------------------------------- #
# Multiple vars in a single call
# --------------------------------------------------------------------------- #

def _test_multiple_vars():
    checkout_add_env_vars(
        "{}/multiple".format(_PREFIX),
        vars = [
            env_assign(
                name = _MULTI_ASSIGN_VAR1,
                value = _MULTI_ASSIGN_VAR1_VALUE,
                help = "First var in multi-var test",
            ),
            env_assign(
                name = _MULTI_ASSIGN_VAR2,
                value = _MULTI_ASSIGN_VAR2_VALUE,
                help = "Second var in multi-var test",
            ),
        ],
    )

# --------------------------------------------------------------------------- #
# checkout_type_optional – rules that should be skipped
# --------------------------------------------------------------------------- #

def _test_optional_type():
    checkout_add_env_vars(
        "{}/optional".format(_PREFIX),
        vars = [
            env_assign(
                name = _OPTIONAL_VAR,
                value = "this should never be set",
                help = "Optional var that should be skipped",
            ),
        ],
        type = checkout_type_optional(),
    )

# --------------------------------------------------------------------------- #
# deps – verify dependent rule ordering
# --------------------------------------------------------------------------- #

def _test_deps():
    checkout_add_env_vars(
        "{}/deps_source".format(_PREFIX),
        vars = [
            env_assign(
                name = _DEPS_VAR,
                value = _DEPS_VALUE,
                help = "Source var for deps test",
            ),
        ],
    )
    checkout_add_env_vars(
        "{}/deps_link".format(_PREFIX),
        vars = [
            env_assign(
                name = _DEPS_LINK_VAR,
                value = _DEPS_LINK_VALUE,
                help = "Dependent var for deps test",
            ),
        ],
        deps = [":{}/deps_source".format(_PREFIX)],
    )

# --------------------------------------------------------------------------- #
# platforms
# --------------------------------------------------------------------------- #

def _test_platforms():
    checkout_add_env_vars(
        "{}/platform".format(_PREFIX),
        vars = [
            env_assign(
                name = _PLATFORM_VAR,
                value = _PLATFORM_VALUE,
                help = "Platform-specific env var",
            ),
        ],
        platforms = ["macos-aarch64", "macos-x86_64", "linux-x86_64", "linux-aarch64"],
    )

# --------------------------------------------------------------------------- #
# visibility
# --------------------------------------------------------------------------- #

def _test_visibility():
    checkout_add_env_vars(
        "{}/public".format(_PREFIX),
        vars = [
            env_assign(
                name = _PUBLIC_VAR,
                value = _PUBLIC_VALUE,
                help = "Public env var",
            ),
        ],
        visibility = visibility_public(),
    )
    checkout_add_env_vars(
        "{}/private".format(_PREFIX),
        vars = [
            env_assign(
                name = _PRIVATE_VAR,
                value = _PRIVATE_VALUE,
                help = "Private env var",
            ),
        ],
        visibility = visibility_private(),
    )

# --------------------------------------------------------------------------- #
# Validation – called in a later checkout phase
# --------------------------------------------------------------------------- #

def testlab_run_add_env_vars_tests():
    """Validates env vars set by testlab_checkout_add_env_vars."""

    # ---- env_assign --------------------------------------------------------
    _assert_var_equals(_ASSIGN_VAR, _ASSIGN_VALUE)

    # ---- env_prepend -------------------------------------------------------
    prepend_result = workspace_get_env_var(_PREPEND_VAR)
    expected_prepend = "{}:{}".format(_PREPEND_VALUE_FRONT, _PREPEND_VALUE_BASE)
    if prepend_result != expected_prepend:
        checkout.abort("env_prepend: {} = '{}', expected '{}'".format(
            _PREPEND_VAR,
            prepend_result,
            expected_prepend,
        ))

    # ---- env_append --------------------------------------------------------
    append_result = workspace_get_env_var(_APPEND_VAR)
    expected_append = "{}:{}".format(_APPEND_VALUE_BASE, _APPEND_VALUE_BACK)
    if append_result != expected_append:
        checkout.abort("env_append: {} = '{}', expected '{}'".format(
            _APPEND_VAR,
            append_result,
            expected_append,
        ))

    # ---- custom separator --------------------------------------------------
    custom_sep_result = workspace_get_env_var(_CUSTOM_SEP_VAR)
    expected_custom_sep = "{}{}{}".format(_CUSTOM_SEP_VALUE_BASE, _CUSTOM_SEPARATOR, _CUSTOM_SEP_VALUE_EXTRA)
    if custom_sep_result != expected_custom_sep:
        checkout.abort("custom separator: {} = '{}', expected '{}'".format(
            _CUSTOM_SEP_VAR,
            custom_sep_result,
            expected_custom_sep,
        ))

    # ---- env_inherit (HOME) ------------------------------------------------
    if not workspace_is_env_var_set(_INHERIT_VAR):
        checkout.abort("env_inherit: {} is not set (expected inherited from calling env)".format(_INHERIT_VAR))

    # ---- env_inherit with assign_as_default --------------------------------
    inherit_default_result = workspace_get_env_var_or_none(_INHERIT_DEFAULT_VAR)
    if inherit_default_result == None:
        checkout.abort("env_inherit with default: {} is not set, expected '{}'".format(
            _INHERIT_DEFAULT_VAR,
            _INHERIT_DEFAULT_VALUE,
        ))

    # ---- multiple vars in one call -----------------------------------------
    _assert_var_equals(_MULTI_ASSIGN_VAR1, _MULTI_ASSIGN_VAR1_VALUE)
    _assert_var_equals(_MULTI_ASSIGN_VAR2, _MULTI_ASSIGN_VAR2_VALUE)

    # ---- optional type should NOT be set -----------------------------------
    if workspace_is_env_var_set(_OPTIONAL_VAR):
        checkout.abort("optional type: {} should not be set but is".format(_OPTIONAL_VAR))

    # ---- deps --------------------------------------------------------------
    _assert_var_equals(_DEPS_VAR, _DEPS_VALUE)
    _assert_var_equals(_DEPS_LINK_VAR, _DEPS_LINK_VALUE)

    # ---- platforms ---------------------------------------------------------
    _assert_var_equals(_PLATFORM_VAR, _PLATFORM_VALUE)

    # ---- visibility --------------------------------------------------------
    _assert_var_equals(_PUBLIC_VAR, _PUBLIC_VALUE)
    _assert_var_equals(_PRIVATE_VAR, _PRIVATE_VALUE)

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def _assert_var_equals(name, expected):
    """Asserts that the workspace env var `name` equals `expected`."""
    if not workspace_is_env_var_set(name):
        checkout.abort("{} is not set, expected '{}'".format(name, expected))
    actual = workspace_get_env_var(name)
    if actual != expected:
        checkout.abort("{} = '{}', expected '{}'".format(name, actual, expected))

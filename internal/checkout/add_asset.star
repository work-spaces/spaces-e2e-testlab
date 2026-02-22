"""
Tests for the checkout asset function family defined in @star/sdk/star/checkout.star
"""

load(
    "//@star/sdk/star/asset.star",
    "asset_content",
    "asset_hard_link",
    "asset_soft_link",
)
load(
    "//@star/sdk/star/checkout.star",
    "checkout_add_any_assets",
    "checkout_add_asset",
    "checkout_add_hard_link_asset",
    "checkout_add_soft_link_asset",
    "checkout_add_which_asset",
    "checkout_type_optional",
    "checkout_update_asset",
)
load(
    "//@star/sdk/star/visibility.star",
    "visibility_private",
    "visibility_public",
)
load(
    "../test.star",
    "test_assert_file_contains",
    "test_assert_file_not_contains",
    "test_assert_path_exists",
    "test_assert_path_not_exists",
)

_PREFIX = "testlab/add_asset"

def testlab_checkout_add_asset():
    """Tests the full checkout asset function family."""

    _test_add_asset()
    _test_update_asset()
    _test_hard_link_asset()
    _test_soft_link_asset()
    _test_any_assets()
    _test_optional_type()
    _test_deps()
    _test_platforms()
    _test_visibility()

# --------------------------------------------------------------------------- #
# checkout_add_asset
# --------------------------------------------------------------------------- #

_CONTENT_TXT_PATH = "{}/content.txt".format(_PREFIX)
_CONTENT_TXT_BODY = "hello from checkout_add_asset"

_CONTENT_MULTI_PATH = "{}/multiline.txt".format(_PREFIX)
_CONTENT_MULTI_BODY = "line one\nline two\nline three"

_JSON_SEED_PATH = "{}/data.json".format(_PREFIX)
_JSON_SEED_BODY = '{"base_key": "base_value"}'

def _test_add_asset():
    # Simple text file
    checkout_add_asset(
        "{}/content_txt".format(_PREFIX),
        content = _CONTENT_TXT_BODY,
        destination = _CONTENT_TXT_PATH,
    )
    test_assert_path_exists(_CONTENT_TXT_PATH)
    test_assert_file_contains(
        "{}/content_txt_body".format(_PREFIX),
        _CONTENT_TXT_PATH,
        _CONTENT_TXT_BODY,
    )

    # Multiline content
    checkout_add_asset(
        "{}/multiline_txt".format(_PREFIX),
        content = _CONTENT_MULTI_BODY,
        destination = _CONTENT_MULTI_PATH,
    )
    test_assert_path_exists(_CONTENT_MULTI_PATH)
    test_assert_file_contains(
        "{}/multiline_line_one".format(_PREFIX),
        _CONTENT_MULTI_PATH,
        "line one",
    )
    test_assert_file_contains(
        "{}/multiline_line_three".format(_PREFIX),
        _CONTENT_MULTI_PATH,
        "line three",
    )

    # JSON seed file used later by checkout_update_asset
    checkout_update_asset(
        "{}/json_seed".format(_PREFIX),
        value = {
            "base_key": "base_value",
        },
        destination = _JSON_SEED_PATH,
    )
    test_assert_path_exists(_JSON_SEED_PATH)

# --------------------------------------------------------------------------- #
# checkout_update_asset
# --------------------------------------------------------------------------- #

def _test_update_asset():
    # Merge a new key into the seed JSON created above
    checkout_update_asset(
        "{}/update_json".format(_PREFIX),
        destination = _JSON_SEED_PATH,
        value = {"added_key": "added_value"},
        deps = [":{}/json_seed".format(_PREFIX)],
    )
    test_assert_file_contains(
        "{}/update_json_has_added".format(_PREFIX),
        _JSON_SEED_PATH,
        "added_key",
    )
    test_assert_file_contains(
        "{}/update_json_has_base".format(_PREFIX),
        _JSON_SEED_PATH,
        "base_key",
    )

    # Update with explicit format
    _TOML_PATH = "{}/config.toml".format(_PREFIX)
    checkout_add_asset(
        "{}/toml_seed".format(_PREFIX),
        content = "[section]\nkey = \"original\"",
        destination = _TOML_PATH,
    )
    checkout_update_asset(
        "{}/update_toml".format(_PREFIX),
        destination = _TOML_PATH,
        format = "toml",
        value = {"new_section": {"new_key": "new_value"}},
        deps = [":{}/toml_seed".format(_PREFIX)],
    )
    test_assert_path_exists(_TOML_PATH)

# --------------------------------------------------------------------------- #
# checkout_add_hard_link_asset
# --------------------------------------------------------------------------- #

_HARD_LINK_DEST = "{}/hard_link.txt".format(_PREFIX)

def _test_hard_link_asset():
    checkout_add_hard_link_asset(
        "{}/hard_link".format(_PREFIX),
        source = _CONTENT_TXT_PATH,
        destination = _HARD_LINK_DEST,
        deps = [":{}/content_txt".format(_PREFIX)],
    )
    test_assert_path_exists(_HARD_LINK_DEST)
    test_assert_file_contains(
        "{}/hard_link_body".format(_PREFIX),
        _HARD_LINK_DEST,
        _CONTENT_TXT_BODY,
    )

# --------------------------------------------------------------------------- #
# checkout_add_soft_link_asset
# --------------------------------------------------------------------------- #

_SOFT_LINK_DEST = "{}/soft_link.txt".format(_PREFIX)

def _test_soft_link_asset():
    checkout_add_soft_link_asset(
        "{}/soft_link".format(_PREFIX),
        source = "content.txt",
        destination = _SOFT_LINK_DEST,
        deps = [":{}/content_txt".format(_PREFIX)],
    )
    test_assert_path_exists(_SOFT_LINK_DEST)
    test_assert_file_contains(
        "{}/soft_link_body".format(_PREFIX),
        _SOFT_LINK_DEST,
        _CONTENT_TXT_BODY,
    )

# --------------------------------------------------------------------------- #
# checkout_add_which_asset
# --------------------------------------------------------------------------- #

_WHICH_DEST = "{}/which_bash".format(_PREFIX)

# --------------------------------------------------------------------------- #
# checkout_add_any_assets
# --------------------------------------------------------------------------- #

_ANY_CONTENT_DEST = "{}/any/content_file.txt".format(_PREFIX)
_ANY_CONTENT_BODY = "created via asset_content"
_ANY_HARD_LINK_DEST = "{}/any/hard_link.txt".format(_PREFIX)
_ANY_SOFT_LINK_DEST = "{}/any/soft_link.txt".format(_PREFIX)

def _test_any_assets():
    checkout_add_any_assets(
        "{}/any_assets".format(_PREFIX),
        assets = [
            asset_content(
                content = _ANY_CONTENT_BODY,
                destination = _ANY_CONTENT_DEST,
            ),
            asset_hard_link(
                source = _CONTENT_TXT_PATH,
                destination = _ANY_HARD_LINK_DEST,
            ),
            asset_soft_link(
                source = "../content.txt",
                destination = _ANY_SOFT_LINK_DEST,
            ),
        ],
        deps = [":{}/content_txt".format(_PREFIX)],
    )
    test_assert_path_exists(_ANY_CONTENT_DEST)
    test_assert_file_contains(
        "{}/any_content_body".format(_PREFIX),
        _ANY_CONTENT_DEST,
        _ANY_CONTENT_BODY,
    )
    test_assert_path_exists(_ANY_HARD_LINK_DEST)
    test_assert_file_contains(
        "{}/any_hard_link_body".format(_PREFIX),
        _ANY_HARD_LINK_DEST,
        _CONTENT_TXT_BODY,
    )
    test_assert_path_exists(_ANY_SOFT_LINK_DEST)
    test_assert_file_contains(
        "{}/any_soft_link_body".format(_PREFIX),
        _ANY_SOFT_LINK_DEST,
        _CONTENT_TXT_BODY,
    )

# --------------------------------------------------------------------------- #
# checkout_type_optional – asset rules that should be skipped
# --------------------------------------------------------------------------- #

_OPTIONAL_DEST = "{}/optional_should_not_exist.txt".format(_PREFIX)

def _test_optional_type():
    checkout_add_asset(
        "{}/optional_asset".format(_PREFIX),
        content = "this should never be written",
        destination = _OPTIONAL_DEST,
        type = checkout_type_optional(),
    )
    test_assert_path_not_exists(_OPTIONAL_DEST)

    checkout_add_hard_link_asset(
        "{}/optional_hard_link".format(_PREFIX),
        source = _CONTENT_TXT_PATH,
        destination = "{}/optional_hard_link.txt".format(_PREFIX),
        type = checkout_type_optional(),
    )
    test_assert_path_not_exists("{}/optional_hard_link.txt".format(_PREFIX))

    checkout_add_soft_link_asset(
        "{}/optional_soft_link".format(_PREFIX),
        source = "content.txt",
        destination = "{}/optional_soft_link.txt".format(_PREFIX),
        type = checkout_type_optional(),
    )
    test_assert_path_not_exists("{}/optional_soft_link.txt".format(_PREFIX))

    checkout_add_any_assets(
        "{}/optional_any".format(_PREFIX),
        assets = [
            asset_content(
                content = "skip me",
                destination = "{}/optional_any_file.txt".format(_PREFIX),
            ),
        ],
        type = checkout_type_optional(),
    )
    test_assert_path_not_exists("{}/optional_any_file.txt".format(_PREFIX))

# --------------------------------------------------------------------------- #
# deps – verify a dependent asset sees its prerequisite
# --------------------------------------------------------------------------- #

_DEPS_SOURCE_DEST = "{}/deps_source.txt".format(_PREFIX)
_DEPS_LINK_DEST = "{}/deps_link.txt".format(_PREFIX)

def _test_deps():
    checkout_add_asset(
        "{}/deps_source".format(_PREFIX),
        content = "deps source content",
        destination = _DEPS_SOURCE_DEST,
    )
    checkout_add_hard_link_asset(
        "{}/deps_link".format(_PREFIX),
        source = _DEPS_SOURCE_DEST,
        destination = _DEPS_LINK_DEST,
        deps = [":{}/deps_source".format(_PREFIX)],
    )
    test_assert_path_exists(_DEPS_LINK_DEST)
    test_assert_file_contains(
        "{}/deps_link_body".format(_PREFIX),
        _DEPS_LINK_DEST,
        "deps source content",
    )

# --------------------------------------------------------------------------- #
# platforms – exercise the platforms parameter
# --------------------------------------------------------------------------- #

def _test_platforms():
    checkout_add_asset(
        "{}/platform_asset".format(_PREFIX),
        content = "platform specific content",
        destination = "{}/platform_file.txt".format(_PREFIX),
        platforms = ["macos-aarch64", "macos-x86_64", "linux-x86_64", "linux-aarch64"],
    )
    test_assert_path_exists("{}/platform_file.txt".format(_PREFIX))

# --------------------------------------------------------------------------- #
# visibility – exercise the visibility parameter
# --------------------------------------------------------------------------- #

def _test_visibility():
    checkout_add_asset(
        "{}/public_asset".format(_PREFIX),
        content = "public",
        destination = "{}/public_file.txt".format(_PREFIX),
        visibility = visibility_public(),
    )
    test_assert_path_exists("{}/public_file.txt".format(_PREFIX))

    checkout_add_asset(
        "{}/private_asset".format(_PREFIX),
        content = "private",
        destination = "{}/private_file.txt".format(_PREFIX),
        visibility = visibility_private(),
    )
    test_assert_path_exists("{}/private_file.txt".format(_PREFIX))

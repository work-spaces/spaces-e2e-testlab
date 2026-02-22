"""
Checkout the SDK and packages repositories.
"""

if not workspace.is_env_var_set("SPACES_E2E_TESTLAB_SKIP_SDK"):
    checkout.add_repo(
        rule = {"name": "@star/sdk"},
        repo = {
            "url": "https://github.com/work-spaces/sdk",
            "rev": "v0.3.24",
            "checkout": "Revision",
            "clone": "Default",
        },
    )

    checkout.add_repo(
        rule = {"name": "@star/packages"},
        repo = {
            "url": "https://github.com/work-spaces/packages",
            "rev": "v0.2.38",
            "checkout": "Revision",
            "clone": "Default",
        },
    )

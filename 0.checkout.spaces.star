"""
Checkout the SDK and packages repositories.
"""

if not workspace.is_env_var_set("SPACES_E2E_TESTLAB_SKIP_SDK"):
    checkout.add_repo(
        rule = {"name": "@star/sdk"},
        repo = {
            "url": "https://github.com/work-spaces/sdk",
            "rev": "main",
            "checkout": "Revision",
            "clone": "Default",
        },
    )

    checkout.add_repo(
        rule = {"name": "@star/packages"},
        repo = {
            "url": "https://github.com/work-spaces/packages",
            "rev": "main",
            "checkout": "Revision",
            "clone": "Default",
        },
    )

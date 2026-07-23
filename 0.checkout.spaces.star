"""
Checkout the SDK and packages repositories.
"""

load("//@star/prelude/rules/checkout.star", "checkout_add_repo")

if workspace.load_value("SPACES_E2E_TESTLAB_SKIP_SDK") != True:
    checkout_add_repo(
        "@star/sdk",
        url = "https://github.com/work-spaces/sdk",
        rev = "main",
    )

    checkout_add_repo(
        "@star/packages",
        url = "https://github.com/work-spaces/packages",
        rev = "main",
    )

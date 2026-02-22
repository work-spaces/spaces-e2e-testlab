"""
Test checkout SDK wrapper functions.
"""

load("//spaces-e2e-testlab/internal/checkout/add_asset.star", "testlab_checkout_add_asset")
load("//spaces-e2e-testlab/internal/checkout/add_env_vars.star", "testlab_checkout_add_env_vars")
load("//spaces-e2e-testlab/internal/checkout/add_repo.star", "testlab_checkout_add_repo")
load("//spaces-e2e-testlab/internal/checkout/update_env.star", "testlab_checkout_update_env")

testlab_checkout_add_repo()
testlab_checkout_update_env()
testlab_checkout_add_env_vars()
testlab_checkout_add_asset()

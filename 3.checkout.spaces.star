"""
Validate env vars set by testlab_checkout_update_env and
testlab_checkout_add_env_vars in 2.checkout.spaces.star.
"""

load(
    "//spaces-e2e-testlab/internal/checkout/add_env_vars.star",
    "testlab_run_add_env_vars_tests",
)
load(
    "//spaces-e2e-testlab/internal/checkout/update_env.star",
    "testlab_run_update_env_tests",
)

testlab_run_update_env_tests()
testlab_run_add_env_vars_tests()

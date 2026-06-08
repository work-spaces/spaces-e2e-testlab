"""
Test checkout SDK wrapper functions.
"""

load("internal/checkout/add_asset.star", "testlab_checkout_add_asset")
load("internal/checkout/add_env_vars.star", "testlab_checkout_add_env_vars")
load("internal/checkout/add_exec.star", "testlab_checkout_add_exec")
load("internal/checkout/add_repo.star", "testlab_checkout_add_repo")
load("internal/checkout/store.star", "testlab_checkout_store_value")
load("internal/checkout/update_env.star", "testlab_checkout_update_env")
load("internal/packages/package_test.star", "testlab_checkout_all_packages")
load("internal/run/add_exec_deps.star", "testlab_run_add_exec_deps_checkout")
load("internal/run/test_rcache.star", "testlab_rcache_checkout")
load("internal/workspace/member.star", "testlab_checkout_workspace_member")

testlab_checkout_add_repo()
testlab_checkout_update_env()
testlab_checkout_add_env_vars()
testlab_checkout_add_asset()
testlab_checkout_add_exec()
testlab_checkout_all_packages()
testlab_checkout_store_value()
testlab_checkout_workspace_member()
testlab_run_add_exec_deps_checkout()
testlab_rcache_checkout()

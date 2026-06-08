"""
Run tests
"""

load("internal/checkout/store.star", "testlab_run_store_value")
load("internal/run/add_exec.star", "testlab_run_add_exec")
load("internal/run/add_exec_deps.star", "testlab_run_add_exec_deps")
load("internal/run/test_rcache.star", "testlab_rcache_run")
load("internal/workspace/member.star", "testlab_run_workspace_member")

testlab_run_add_exec()
testlab_run_add_exec_deps()
testlab_run_store_value()
testlab_run_workspace_member()
testlab_rcache_run()

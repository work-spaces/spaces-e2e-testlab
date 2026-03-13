"""
Run tests
"""

load("//spaces-e2e-testlab/internal/checkout/store.star", "testlab_run_store_value")
load("//spaces-e2e-testlab/internal/run/add_exec.star", "testlab_run_add_exec")
load("//spaces-e2e-testlab/internal/run/add_exec_deps.star", "testlab_run_add_exec_deps")
load("//spaces-e2e-testlab/internal/run/test_rcache.star", "testlab_rcache_run")
load("//spaces-e2e-testlab/internal/workspace/member.star", "testlab_run_workspace_member")

testlab_run_add_exec()
testlab_run_add_exec_deps()
testlab_run_store_value()
testlab_run_workspace_member()
testlab_rcache_run()

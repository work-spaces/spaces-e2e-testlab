"""
Run tests
"""

load("//spaces-e2e-testlab/internal/run/add_exec.star", "testlab_run_add_exec")
load("//spaces-e2e-testlab/internal/run/test_rcache.star", "testlab_rcache_run")

testlab_run_add_exec()
testlab_rcache_run()

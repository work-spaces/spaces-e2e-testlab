"""
Tests for package_add defined in @star/packages/star/package.star.

Iterates every package in the @star/packages registry and checks out
each one with a unique add_prefix so that no two packages collide.

Packages listed in the whitelist are skipped. After all tests complete,
a run rule generates an updated whitelist file containing both previously
whitelisted and newly tested packages.
"""

load("//@star/packages/star/package.star", "package_add", "package_is_platform_supported")
load("//@star/packages/star/packages.star", "packages")
load("//@star/sdk/star/run.star", "run_add_exec", "run_type_all")
load("package_whitelist.star", "WHITELIST")

_PREFIX = "testlab/packages"
_WHITELIST_OUTPUT = "whitelist.star"

def testlab_checkout_all_packages():
    """Checks out every package version in the registry under its own prefix.

    Skips packages present in the whitelist. After checkout, adds a run
    rule that writes an updated whitelist covering all passed packages.
    """

    tested = []

    for domain in packages:
        owners = packages[domain]
        for owner in owners:
            repos = owners[owner]
            for repo in repos:
                versions = repos[repo]
                for version in versions:
                    key = "{}/{}/{}/{}".format(domain, owner, repo, version)
                    if key.startswith("github.com/llvm"):
                        continue
                    if key.startswith("nodejs.org"):
                        continue
                    if key.startswith("github.com/xpack-dev-tools"):
                        continue
                    if key.startswith("github.com/Kitware"):
                        continue
                    if key.startswith("github.com/protocolbuffers"):
                        continue
                    if key.startswith("arm.developer.com"):
                        continue
                    if key in WHITELIST:
                        continue
                    if not package_is_platform_supported(domain, owner, repo, version):
                        continue
                    add_prefix = "{}/{}/{}/{}/{}".format(
                        _PREFIX,
                        domain,
                        owner,
                        repo,
                        version,
                    )
                    package_add(
                        domain,
                        owner,
                        repo,
                        version,
                        add_prefix = add_prefix,
                    )
                    tested.append(key)

    # Merge previously whitelisted keys with newly tested keys
    all_keys = sorted(list(WHITELIST.keys()) + tested)

    # Build the starlark file content for the updated whitelist
    lines = []
    lines.append('"""Whitelist of packages that have already passed testing."""')
    lines.append("")
    lines.append("WHITELIST = {")
    for key in all_keys:
        lines.append('    "{}": True,'.format(key))
    lines.append("}")
    lines.append("")

    content = "\n".join(lines)

    # Use a bash heredoc so no escaping is needed inside the starlark content
    script = "cat <<'WHITELIST_EOF'\n" + content + "\nWHITELIST_EOF"

    run_add_exec(
        "{}/generate_whitelist".format(_PREFIX),
        command = "bash",
        args = ["-c", script],
        redirect_stdout = _WHITELIST_OUTPUT,
        type = run_type_all(),
        help = "Generate updated package whitelist from tested packages",
    )

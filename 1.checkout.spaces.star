"""
Spaces starlark checkout/run script to make changes to spaces, printer, and archiver.
With VSCode/Zed integration
"""

load("//@star/packages/star/coreutils.star", "coreutils_add_rs_tools")
load("//@star/packages/star/rust.star", "rust_add")
load("//@star/packages/star/sccache.star", "sccache_add")
load("//@star/packages/star/spaces-cli.star", "spaces_add_star_formatter", "spaces_isolate_workspace")
load("//@star/packages/star/starship.star", "starship_add_bash")
load(
    "//@star/sdk/star/checkout.star",
    "checkout_add_hard_link_asset",
    "checkout_add_repo",
    "checkout_update_asset",
    "checkout_update_env",
)
load(
    "//@star/sdk/star/info.star",
    "info_get_path_to_store",
)
load(
    "//@star/sdk/star/ws.star",
    "workspace_get_absolute_path",
    "workspace_get_path_to_checkout",
)

# Configure the top level workspace

SPACES_CHECKOUT_PATH = workspace_get_path_to_checkout()

SHORTCUTS = {
    "inspect": "spaces inspect",
    "install_dev": "spaces run //spaces:install_dev",
    "install_dev_lsp": "spaces run //spaces:install_dev_lsp",
    "install_release": "spaces run //spaces:install_release",
    "clippy": "spaces run //spaces:clippy",
    "format": "spaces run //spaces:format",
}

starship_add_bash("starship0", shortcuts = SHORTCUTS)

spaces_isolate_workspace("spaces0", "v0.15.26", system_paths = ["/usr/bin", "/bin"])
spaces_add_star_formatter("star_formatter", configure_zed = True, deps = [":spaces0"])

rust_add(
    "rust_toolchain",
    version = "1.80",
    deps = [":spaces0"],
)

coreutils_add_rs_tools("coreutils0", deps = ["rust_toolchain"])

spaces_store = info_get_path_to_store()

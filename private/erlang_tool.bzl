load(
    "//tools:erlang_toolchain.bzl",
    "erlang_dirs",
    "maybe_install_erlang",
)

DEFAULT_PATH = "bin/erl"

def _impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)

    # Use short_path=True since this script runs at runtime (in runfiles)
    (erlang_home, _, runfiles) = erlang_dirs(ctx, short_path = True)

    ctx.actions.write(
        output = out,
        content = """#!/usr/bin/env bash
set -euo pipefail

# Find the runfiles directory
if [[ -n "${{RUNFILES_DIR:-}}" ]]; then
    RUNFILES="${{RUNFILES_DIR}}"
elif [[ -d "$0.runfiles" ]]; then
    RUNFILES="$0.runfiles"
elif [[ -d "${{BASH_SOURCE[0]}}.runfiles" ]]; then
    RUNFILES="${{BASH_SOURCE[0]}}.runfiles"
else
    echo "ERROR: Cannot find runfiles directory" >&2
    exit 1
fi

{maybe_install_erlang}

exec "${{RUNFILES}}/{erlang_home}"/{path} $@
""".format(
            maybe_install_erlang = maybe_install_erlang(ctx, short_path = True),
            erlang_home = erlang_home,
            path = ctx.attr.path,
        ),
    )

    return [
        DefaultInfo(
            executable = out,
            runfiles = runfiles,
        ),
    ]

erlang_tool = rule(
    implementation = _impl,
    attrs = {
        "path": attr.string(default = DEFAULT_PATH),
    },
    toolchains = ["//tools:toolchain_type"],
    executable = True,
)

load(
    "//tools:erlang_toolchain.bzl",
    "erlang_dirs",
    "maybe_install_erlang",
    "runfiles_path",
    "version_file",
    "version_file_path",
)

def _impl(ctx):
    # Use short_path=True since this script runs at runtime (in runfiles)
    (erlang_home, _, runfiles) = erlang_dirs(ctx, short_path = True)

    # The script needs to find its runfiles directory first, since the short_path
    # is relative to the runfiles root, not the cwd where Bazel invokes the tool.
    script = """#!/usr/bin/env bash
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

# Resolve ERLANG_HOME to an absolute path for consistent path matching
ABS_ERLANG_HOME=$(cd "${{RUNFILES}}/{erlang_home}" && pwd)

exec \\
    env ERLANG_HOME="${{ABS_ERLANG_HOME}}" \\
        VERSION_FILE="${{RUNFILES}}/{version_file}" \\
    "${{ABS_ERLANG_HOME}}"/bin/escript "${{RUNFILES}}/{escript}" $@
""".format(
        maybe_install_erlang = maybe_install_erlang(ctx),
        erlang_home = erlang_home,
        version_file = version_file_path(ctx, short_path = True),
        escript = runfiles_path(ctx.file.escript),
    )

    ctx.actions.write(
        output = ctx.outputs.out,
        content = script,
        is_executable = True,
    )

    runfiles = runfiles.merge(
        ctx.runfiles(files = ctx.files.escript),
    )

    return [
        DefaultInfo(
            runfiles = runfiles,
            executable = ctx.outputs.out,
        ),
    ]

escript_wrapper = rule(
    implementation = _impl,
    attrs = {
        "escript": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "out": attr.output(
            mandatory = True,
        ),
    },
    toolchains = ["//tools:toolchain_type"],
    executable = True,
)

load("//:erlang_app_info.bzl", "ErlangAppInfo")
load(
    "//:util.bzl",
    "path_join",
)
load(":ct.bzl", "code_paths")
load(
    ":util.bzl",
    "to_erlang_atom_list",
    "to_erlang_string_list",
)
load(
    "//tools:erlang_toolchain.bzl",
    "erlang_dirs",
    "maybe_install_erlang",
    "runfiles_path",
)

def _impl(ctx):
    lib_info = ctx.attr.target[ErlangAppInfo]

    extra_paths = []
    dirs = [path_join(ctx.attr.target.label.package, "ebin")]
    for dep in lib_info.deps + ctx.attr.additional_libs:
        if dep.label.workspace_root != "":
            extra_paths.extend(code_paths(dep))
        else:
            dirs.append(path_join(dep.label.package, "ebin"))

    xref_config = "[{xref, ["
    xref_config = xref_config + "{config, #{"
    xref_config = xref_config + "extra_paths => " + to_erlang_string_list(extra_paths)
    xref_config = xref_config + ", "
    xref_config = xref_config + "dirs => " + to_erlang_string_list(dirs)
    xref_config = xref_config + "}}"
    xref_config = xref_config + ", "
    xref_config = xref_config + "{checks, " + to_erlang_atom_list(ctx.attr.checks) + "}"
    xref_config = xref_config + "]}]."
    xref_config = xref_config + "\n"

    config_file = ctx.actions.declare_file("xref.config")
    ctx.actions.write(
        output = config_file,
        content = xref_config,
    )

    # Use short_path=True since this script runs at runtime (in runfiles)
    (erlang_home, _, runfiles) = erlang_dirs(ctx, short_path = True)

    xrefr = ctx.attr.xrefr
    xrefr_path = runfiles_path(xrefr[DefaultInfo].files_to_run.executable)
    config_path = runfiles_path(config_file)

    output = ctx.actions.declare_file(ctx.label.name)
    script = """\
#!/usr/bin/env bash
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

export HOME=${{TEST_TMPDIR}}

"${{RUNFILES}}/{erlang_home}"/bin/erl \\
    -eval '{{ok, [C]}} = file:consult("${{RUNFILES}}/{config_path}"), io:format("~p~n", [C]), halt().' \\
    -noshell

set -x
"${{RUNFILES}}/{erlang_home}"/bin/escript "${{RUNFILES}}/{xrefr}" \\
    --config "${{RUNFILES}}/{config_path}"
""".format(
        maybe_install_erlang = maybe_install_erlang(ctx, short_path = True),
        erlang_home = erlang_home,
        xrefr = xrefr_path,
        config_path = config_path,
    )

    ctx.actions.write(
        output = output,
        content = script,
    )

    runfiles = ctx.runfiles([
        config_file,
    ]).merge_all([
        runfiles,
        xrefr[DefaultInfo].default_runfiles,
        ctx.attr.target[DefaultInfo].default_runfiles,
    ] + [
        dep[DefaultInfo].default_runfiles
        for dep in ctx.attr.additional_libs
    ])
    return [DefaultInfo(
        runfiles = runfiles,
        executable = output,
    )]

xref_test = rule(
    implementation = _impl,
    attrs = {
        "xrefr": attr.label(
            mandatory = True,
            executable = True,
            cfg = "target",
        ),
        "target": attr.label(
            providers = [ErlangAppInfo],
            mandatory = True,
        ),
        "checks": attr.string_list(
            default = [
                "undefined_function_calls",
                "locals_not_used",
                "deprecated_function_calls",
            ],
        ),
        "additional_libs": attr.label_list(
            providers = [ErlangAppInfo],
        ),
    },
    toolchains = ["//tools:toolchain_type"],
    test = True,
)

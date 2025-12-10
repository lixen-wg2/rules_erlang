load(
    "//:erlang_app_info.bzl",
    "ErlangAppInfo",
)
load(
    "//:util.bzl",
    "windows_path",
)
load(
    "//tools:erlang_toolchain.bzl",
    "erlang_dirs",
    "maybe_install_erlang",
    "runfiles_path",
)

def _impl(ctx):
    app_info = ctx.attr.app[ErlangAppInfo]
    app_file = None
    dot_app_file_name = app_info.app_name + ".app"
    for f in app_info.beam:
        if f.basename == dot_app_file_name:
            app_file = f
            break
    if app_file == None:
        fail("{} not found in {}".format(dot_app_file_name, app_info.beam))

    expected_apps = ["kernel", "stdlib"] + app_info.extra_apps + [
        dep[ErlangAppInfo].app_name
        for dep in app_info.direct_deps
    ]

    # Use short_path=True since this script runs at runtime (in runfiles)
    (erlang_home, _, runfiles) = erlang_dirs(ctx, short_path = True)

    assert_applications = ctx.attr.assert_applications
    assert_applications_path = runfiles_path(assert_applications[DefaultInfo].files_to_run.executable)

    if not ctx.attr.is_windows:
        output = ctx.actions.declare_file(ctx.label.name)
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

"${{RUNFILES}}/{erlang_home}"/bin/escript "${{RUNFILES}}/{assert_applications}" \\
    "${{RUNFILES}}/{app_file}" \\
    {expected}
""".format(
            maybe_install_erlang = maybe_install_erlang(ctx, short_path = True),
            erlang_home = erlang_home,
            assert_applications = assert_applications_path,
            app_file = runfiles_path(app_file),
            expected = " ".join(expected_apps),
        )
    else:
        output = ctx.actions.declare_file(ctx.label.name + ".bat")
        script = """@echo off

"{erlang_home}\\bin\\erl" ^
    -eval "halt(1)."
""".format(
            erlang_home = windows_path(erlang_home),
        )

    ctx.actions.write(
        output = output,
        content = script,
    )

    runfiles = runfiles.merge_all([
        ctx.runfiles(files = [app_file]),
        assert_applications[DefaultInfo].default_runfiles,
    ])

    return [DefaultInfo(
        runfiles = runfiles,
        executable = output,
    )]

# this test asserts that the deps and extra apps in the ErlangAppInfo
# actually match whats inside the .app file
extract_app_test = rule(
    implementation = _impl,
    attrs = {
        "is_windows": attr.bool(mandatory = True),
        "app": attr.label(
            mandatory = True,
            providers = [ErlangAppInfo],
        ),
        "assert_applications": attr.label(
            mandatory = True,
            executable = True,
            cfg = "target",
        ),
    },
    toolchains = ["//tools:toolchain_type"],
    test = True,
)

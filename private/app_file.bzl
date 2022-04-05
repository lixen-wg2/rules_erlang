load("//:erlang_home.bzl", "ErlangHomeProvider")
load("//:erlang_app_info.bzl", "ErlangAppInfo")
load("//:util.bzl", "path_join")

def _module_name(f):
    return "'{}'".format(f.basename.replace(".beam", "", 1))

def _impl(ctx):
    app_file = ctx.actions.declare_file(
        path_join("ebin", "{}.app".format(ctx.attr.app_name)),
    )

    if len(ctx.files.app_src) > 1:
        fail("Multiple .app.src files ({}) are not supported".format(
            ctx.files.app_src,
        ))
    elif len(ctx.files.app_src) == 1:
        src = ctx.files.app_src[0].path
    else:
        src = ""

    app_module = ctx.attr.app_module if ctx.attr.app_module != "" else ctx.attr.app_name + "_app"
    if len([m for m in ctx.files.modules if m.basename == app_module + ".beam"]) != 1:
        app_module = ""

    modules = "[" + ",".join([_module_name(m) for m in ctx.files.modules]) + "]"

    registered_list = "[" + ",".join([ctx.attr.app_name + "_sup"] + ctx.attr.app_registered) + "]"

    applications = ["kernel", "stdlib"] + ctx.attr.extra_apps
    for dep in ctx.attr.deps:
        applications.append(dep[ErlangAppInfo].app_name)
    applications_list = "[" + ",".join(applications) + "]"

    app_extra_keys_list = ""
    if len(ctx.attr.app_extra_keys) > 0:
        app_extra_keys_list = "[" + ",".join(ctx.attr.app_extra_keys) + "]"

    stamp = ctx.attr.stamp == 1 or (ctx.attr.stamp == -1 and
                                    ctx.attr.private_stamp_detect)

    script = """set -euo pipefail

if [ -n "{src}" ]; then
    cp {src} {out}
else
    echo "{{application,'{name}',[]}}." > {out}
fi

if [ -n "{description}" ]; then
    "{erlang_home}"/bin/escript {app_file_tool} \\
        description '"{description}"' \\
        {out} > {out}.tmp && mv {out}.tmp {out}
fi

# set the version env var from the stable-status.txt
# if stamping...
if [ -n "{stamp_version_key}" ]; then
    if [ -f "{info_file}" ]; then
        while IFS=' ' read -r key val ; do
            if [ "$key" == "STABLE_{stamp_version_key}" ]; then
                VSN=$val
            fi
        done < {info_file}
    else
        echo "Stamping requested but {info_file} is not available"
        exit 1
    fi
else
    VSN={version}
fi
if [ -n "$VSN" ]; then
    "{erlang_home}"/bin/escript {app_file_tool} \\
        vsn "\\"$VSN\\"" \\
        {out} > {out}.tmp && mv {out}.tmp {out}
fi

"{erlang_home}"/bin/escript {app_file_tool} \\
    modules '{modules}' \\
    {out} > {out}.tmp && mv {out}.tmp {out}

if [ -n "{registered}" ]; then
    "{erlang_home}"/bin/escript {app_file_tool} \\
        registered '{registered}' \\
        {out} > {out}.tmp && mv {out}.tmp {out}
fi

if [ -n "{applications}" ]; then
    "{erlang_home}"/bin/escript {app_file_tool} \\
        applications '{applications}' \\
        {out} > {out}.tmp && mv {out}.tmp {out}
fi

if [ -n "{app_module}" ]; then
    "{erlang_home}"/bin/escript {app_file_tool} \\
        mod '{{{app_module}, []}}' \\
        {out} > {out}.tmp && mv {out}.tmp {out}
fi

if [ -n "{env}" ]; then
    "{erlang_home}"/bin/escript {app_file_tool} \\
        env '{env}' \\
        {out} > {out}.tmp && mv {out}.tmp {out}
fi

if [ -n "{extra_tuples}" ]; then
    "{erlang_home}"/bin/escript {app_file_tool} \\
        '{extra_tuples}' \\
        {out} > {out}.tmp && mv {out}.tmp {out}
fi
""".format(
        erlang_home = ctx.attr._erlang_home[ErlangHomeProvider].path,
        app_file_tool = ctx.file._app_file_tool_escript.path,
        info_file = ctx.info_file.path,
        name = ctx.attr.app_name,
        description = ctx.attr.app_description,
        stamp_version_key = ctx.attr.stamp_version_key if stamp else "",
        version = ctx.attr.app_version,
        modules = modules,
        registered = registered_list,
        applications = applications_list,
        app_module = app_module,
        env = ctx.attr.app_env,
        extra_tuples = app_extra_keys_list,
        src = src,
        out = app_file.path,
    )

    inputs = [ctx.file._app_file_tool_escript] + ctx.files.app_src
    if stamp:
        inputs.append(ctx.info_file)

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = [app_file],
        command = script,
        mnemonic = "APP",
    )

    return [
        DefaultInfo(files = depset([app_file])),
    ]

app_file_private = rule(
    implementation = _impl,
    attrs = {
        "_erlang_home": attr.label(default = Label("//:erlang_home")),
        "_erlang_version": attr.label(default = Label("//:erlang_version")),
        "_app_file_tool_escript": attr.label(
            default = Label("//app_file_tool:escript"),
            allow_single_file = True,
        ),
        "app_name": attr.string(mandatory = True),
        "app_version": attr.string(),
        "app_description": attr.string(),
        "app_module": attr.string(),
        "app_registered": attr.string_list(),
        "app_env": attr.string(default = "[]"),
        "app_extra_keys": attr.string_list(),
        "extra_apps": attr.string_list(),
        "app_src": attr.label_list(allow_files = [".app.src"]),
        "modules": attr.label_list(allow_files = [".beam"]),
        "deps": attr.label_list(providers = [ErlangAppInfo]),
        "stamp": attr.int(default = -1),
        "stamp_version_key": attr.string(
            default = "GIT_COMMIT",
            doc = """This will inject the value with this key from
stable-status.txt as the app version if the build is stamped""",
        ),
        # Is --stamp set on the command line?
        # TODO(https://github.com/bazelbuild/rules_pkg/issues/340): Remove this.
        "private_stamp_detect": attr.bool(default = False),
    },
)

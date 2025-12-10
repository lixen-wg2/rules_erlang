load(
    "//private:erlang_build.bzl",
    "OtpInfo",
)

def _impl(ctx):
    otpinfo = ctx.attr.otp[OtpInfo]
    vars = {
        "OTP_VERSION": otpinfo.version,
        "ERLANG_HOME": otpinfo.erlang_home,
    }
    if otpinfo.release_dir != None:
        vars["ERLANG_RELEASE_DIR_PATH"] = otpinfo.release_dir.path
        vars["ERLANG_RELEASE_DIR_SHORT_PATH"] = otpinfo.release_dir.short_path
    return [
        platform_common.ToolchainInfo(otpinfo = otpinfo),
        platform_common.TemplateVariableInfo(vars),
    ]

erlang_toolchain = rule(
    implementation = _impl,
    attrs = {
        "otp": attr.label(
            mandatory = True,
            providers = [OtpInfo],
        ),
    },
    provides = [
        platform_common.ToolchainInfo,
        # Instead of using this toolchain for a genrule,
        # since toolchain resolution won't yet have applied,
        # use @rules_erlang//tools:erlang_vars as a
        # toolchain for genrule rules
        platform_common.TemplateVariableInfo,
    ],
)

def _build_info(ctx):
    return ctx.toolchains["//tools:toolchain_type"].otpinfo

def runfiles_path(file_or_path):
    """Convert a file's short_path to a runfiles-relative path.

    short_path for external repos is like '../repo_name/path/to/file'
    but runfiles are structured as 'repo_name/path/to/file' (no ../)

    Args:
        file_or_path: Either a File object or a string path.

    Returns:
        A path relative to the runfiles root.
    """
    if type(file_or_path) == "string":
        sp = file_or_path
    else:
        sp = file_or_path.short_path
    if sp.startswith("../"):
        # External repo: strip the ../ prefix
        return sp[3:]
    else:
        # Main workspace: prefix with _main/
        return "_main/" + sp

# Keep internal alias for backwards compatibility within this file
_runfiles_path = runfiles_path

def erlang_dirs(ctx, short_path = False):
    """Returns erlang_home path, release_dir, and runfiles.

    Args:
        ctx: The rule context.
        short_path: If True, return runfiles-relative path (for runtime scripts).
                   If False, return path (for build-time actions).

    Returns:
        A tuple of (erlang_home, release_dir, runfiles).
    """
    info = _build_info(ctx)
    if info.release_dir != None:
        runfiles = ctx.runfiles([info.release_dir, info.version_file])
        if short_path:
            erlang_home = _runfiles_path(info.release_dir)
        else:
            erlang_home = info.release_dir.path
    else:
        runfiles = ctx.runfiles([info.version_file])
        erlang_home = info.erlang_home
    return (erlang_home, info.release_dir, runfiles)

def maybe_install_erlang(ctx, short_path = False):
    # No-op: Erlang is now extracted at build time into a directory artifact.
    # This function is kept for backwards compatibility but does nothing.
    return ""

def version_file(ctx):
    info = _build_info(ctx)
    return info.version_file

def version_file_path(ctx, short_path = False):
    """Returns the path to the version file.

    Args:
        ctx: The rule context.
        short_path: If True, return runfiles-relative path.
                   If False, return path (for build-time actions).

    Returns:
        The path to the version file.
    """
    info = _build_info(ctx)
    if short_path:
        return _runfiles_path(info.version_file)
    else:
        return info.version_file.path

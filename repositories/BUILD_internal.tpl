# This file is generated by rules_erlang via the erlang_config macro

load(
    "%{RULES_ERLANG_WORKSPACE}//private:erlang_build.bzl",
    "erlang_build",
)
load(
    "%{RULES_ERLANG_WORKSPACE}//tools:erlang_toolchain.bzl",
    "erlang_toolchain",
)

erlang_build(
    name = "otp",
    version = "%{ERLANG_VERSION}",
    url = "%{URL}",
    strip_prefix = "%{STRIP_PREFIX}",
    sha256 = "%{SHA_256}",
)

erlang_toolchain(
    name = "erlang",
    otp = ":otp",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "toolchain",
    exec_compatible_with = [
        "//:erlang_internal",
    ],
    target_compatible_with = [
        "//:erlang_%{ERLANG_MAJOR}",
    ],
    toolchain = ":erlang",
    toolchain_type = "%{RULES_ERLANG_WORKSPACE}//tools:toolchain_type",
    visibility = ["//visibility:public"],
)

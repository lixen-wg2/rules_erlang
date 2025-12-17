# rules_erlang

Bazel rules for building Erlang applications.

## Setup

Add rules_erlang to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_erlang", version = "4.0.0")
```

### Configure Erlang

Configure an Erlang installation using the `erlang_config` extension:

```starlark
erlang_config = use_extension(
    "@rules_erlang//bzlmod:extensions.bzl",
    "erlang_config",
)
use_repo(erlang_config, "erlang_config")

# Build Erlang from source (GitHub release)
erlang_config.internal_erlang_from_github_release(
    name = "28.1",
    version = "28.1",
    sha256 = "c7c6fe06a3bf0031187d4cb10d30e11de119b38bdba7cd277898f75d53bdb218",
    extra_configure_opts = ["--enable-sctp"],
)

register_toolchains(
    "@erlang_config//28.1:toolchain_major",
    "@erlang_config//28.1:toolchain_major_minor",
)
```

### Erlang Packages

Add hex.pm or git packages using the `erlang_package` extension:

```starlark
erlang_package = use_extension(
    "@rules_erlang//bzlmod:extensions.bzl",
    "erlang_package",
)

# Hex packages
erlang_package.hex_package(
    name = "cowboy",
    version = "2.13.0",
    sha256 = "e724d3a70995025d654c1992c7b11dbfea95205c047d86ff9bf1cda92ddc5614",
)

# Git packages
erlang_package.git_package(
    name = "grpcbox",
    repository = "tsloughter/grpcbox",
    commit = "6075bf18acb20aac74499744749dea4928a3f927",
    depends_on = ["chatterbox", "acceptor_pool", "gproc", "ctx"],
)

use_repo(erlang_package, "erlang_packages")
```

## Building Applications

### erlang_app_sources

Define application sources:

```starlark
load("@rules_erlang//:erlang_app_sources.bzl", "erlang_app_sources")

erlang_app_sources(
    name = "srcs",
    app_name = "my_app",
    erlc_opts_file = ":erlc_opts_file",
)
```

### compile_many

Compile multiple applications together:

```starlark
load("@rules_erlang//:compile_many.bzl", "compile_many")

compile_many(
    name = "beams",
    apps = [":srcs"],
    erl_libs = ["@erlang_packages//:deps"],
)
```

### extract_app

Extract a compiled application:

```starlark
load("@rules_erlang//:extract_app.bzl", "extract_app")

extract_app(
    name = "my_app",
    app_name = "my_app",
    erl_libs = ":beams",
    deps = ["@erlang_packages//cowboy"],
)
```

## Testing

### EUnit

```starlark
load("@rules_erlang//:eunit2.bzl", "eunit")

eunit(
    name = "eunit",
    target = ":my_app",
    eunit_opts = ["verbose"],
)
```

### Common Test

```starlark
load("@rules_erlang//:ct.bzl", "ct_test")

ct_test(
    name = "my_SUITE",
    compiled_suites = [":test_my_SUITE_beam"],
    target = ":my_app",
)
```

## Static Analysis

### Dialyzer

```starlark
load("@rules_erlang//:dialyze.bzl", "dialyze", "plt", "DEFAULT_PLT_APPS")

plt(
    name = "base_plt",
    apps = DEFAULT_PLT_APPS + ["crypto", "ssl"],
)

plt(
    name = "deps_plt",
    for_target = ":my_app",
    plt = ":base_plt",
)

dialyze(
    name = "dialyze_my_app",
    target = ":my_app",
    plt = ":deps_plt",
)
```

### Xref

```starlark
load("@rules_erlang//:xref2.bzl", "xref")

xref(
    name = "xref",
    target = ":my_app",
)
```

## Other Rules

### Shell

Start an interactive Erlang shell with dependencies:

```starlark
load("@rules_erlang//:shell.bzl", "shell")

shell(
    name = "repl",
    deps = [":my_app"],
)
```

Run with: `bazel run //:repl`

### Escript

```starlark
load("@rules_erlang//:escript.bzl", "escript_archive")

escript_archive(
    name = "my_escript",
    app = ":my_app",
)
```

### Compiler Options

```starlark
load("@rules_erlang//:erlc_opts_file.bzl", "erlc_opts_file")

erlc_opts_file(
    name = "erlc_opts_file",
    values = ["+debug_info", "+warnings_as_errors"],
)
```

## Running Tests

```shell
# Run all tests
bazel test //...

# Run a specific test suite
bazel test //:my_SUITE

# Run a specific test case
bazel test //:my_SUITE --test_env FOCUS="-group my_group -case my_case"

# Run with coverage
bazel coverage //...
```

## Project Layout

The standard OTP layout is expected:

```
my_app/
├── BUILD.bazel
├── include/
│   └── my_header.hrl
├── priv/
│   └── ...
├── src/
│   ├── my_app.app.src
│   └── my_app.erl
└── test/
    └── my_SUITE.erl
```

## Copyright and License

(c) 2020-2025 Broadcom. All Rights Reserved. The term "Broadcom" refers to Broadcom Inc. and/or its subsidiaries. All rights reserved.

Dual licensed under the Apache License Version 2.0 and Mozilla Public License Version 2.0.

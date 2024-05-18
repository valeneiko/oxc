#!/usr/bin/env -S just --justfile

set windows-shell := ["pwsh.exe", "-c"]

_default:
  @just --list -u

alias r := ready
alias c := coverage

# Make sure you have cargo-binstall installed.
# You can download the pre-compiled binary from <https://github.com/cargo-bins/cargo-binstall#installation>
# or install via `cargo install cargo-binstall`
# Initialize the project by installing all the necessary tools.
init:
  cargo binstall cargo-watch cargo-insta cargo-edit typos-cli taplo-cli wasm-pack cargo-llvm-cov -y

# When ready, run the same CI commands
ready:
  git diff --exit-code --quiet
  typos
  just fmt
  just check
  just test
  just lint
  just doc
  git status

# Clone or update submodules
submodules:
  just clone-submodule tasks/coverage/test262 git@github.com:tc39/test262.git 17ba9aea47e496f5b2bc6ce7405b3f32e3cfbf7a
  just clone-submodule tasks/coverage/babel git@github.com:babel/babel.git 4bd1b2c2f1bb3f702cfcb50448736e33c7000128
  just clone-submodule tasks/coverage/typescript git@github.com:microsoft/TypeScript.git 64d2eeea7b9c7f1a79edf42cb99f302535136a2e
  just clone-submodule tasks/prettier_conformance/prettier git@github.com:prettier/prettier.git 7142cf354cce2558f41574f44b967baf11d5b603

# --no-vcs-ignores: cargo-watch has a bug loading all .gitignores, including the ones listed in .gitignore
# use .ignore file getting the ignore list
# Run `cargo watch`
watch command:
  cargo watch --no-vcs-ignores -i '*snap*' -x '{{command}}'

# Run the example in `parser`, `formatter`, `linter`
example tool *args='':
  just watch 'run -p oxc_{{tool}} --example {{tool}} -- {{args}}'

# Format all files
fmt:
  cargo fmt
  taplo format

# Run cargo check
check:
  cargo ck

# Run all the tests
test:
  cargo test

# Lint the whole project
lint:
  cargo lint -- --deny warnings

doc:
  RUSTDOCFLAGS='-D warnings' cargo doc --no-deps --document-private-items

# Run all the conformance tests. See `tasks/coverage`, `tasks/transform_conformance`, `tasks/minsize`
coverage:
  cargo coverage
  cargo run -p oxc_transform_conformance -- --exec
  cargo run -p oxc_prettier_conformance
  # cargo minsize

# Get code coverage
codecov:
  cargo codecov --html

# Run the benchmarks. See `tasks/benchmark`
benchmark:
  cargo benchmark

# Removed Unused Dependencies
shear:
  cargo binstall cargo-shear
  cargo shear --fix

# Automatically DRY up Cargo.toml manifests in a workspace.
autoinherit:
  cargo binstall cargo-autoinherit
  cargo autoinherit

# Test Transform
test-transform *args='':
  cargo run -p oxc_transform_conformance -- {{args}}
  cargo run -p oxc_transform_conformance -- --exec  {{args}}

# Build oxlint in release build
oxlint:
  cargo build --release -p oxc_cli --bin oxlint --features allocator

# Generate the JavaScript global variables. See `tasks/javascript_globals`
javascript-globals:
  cargo run -p javascript_globals

# Create a new lint rule by providing the ESLint name. See `tasks/rulegen`
new-rule name:
  cargo run -p rulegen {{name}}

new-jest-rule name:
  cargo run -p rulegen {{name}} jest

new-ts-rule name:
  cargo run -p rulegen {{name}} typescript

new-unicorn-rule name:
  cargo run -p rulegen {{name}} unicorn

new-react-rule name:
  cargo run -p rulegen {{name}} react

new-jsx-a11y-rule name:
  cargo run -p rulegen {{name}} jsx-a11y

new-oxc-rule name:
  cargo run -p rulegen {{name}} oxc

new-nextjs-rule name:
  cargo run -p rulegen {{name}} nextjs

new-jsdoc-rule name:
  cargo run -p rulegen {{name}} jsdoc

new-react-perf-rule name:
    cargo run -p rulegen {{name}} react-perf

new-n-rule name:
    cargo run -p rulegen {{name}} n

# Upgrade all Rust dependencies
upgrade:
  cargo upgrade --incompatible

clone-submodule dir url sha:
  git clone --depth=1 {{url}} {{dir}} || true
  cd {{dir}} && git fetch origin {{sha}} && git reset --hard {{sha}}


ecosystem_dir := "C:/source/ecosystem"
oxlint_bin := "C:/source/rust/oxc/target/release/oxparse.exe"
threads := "12"

pgo_data_dir := "C:/source/rust/oxc/pgo-data"
llvm_profdata_bin := "~/.rustup/toolchains/1.78.0-x86_64-pc-windows-msvc/lib/rustlib/x86_64-pc-windows-msvc/bin/llvm-profdata.exe"

build-pgo:
  just build-pgo-init
  just oxlint_bin=C:/source/rust/oxc/target/x86_64-pc-windows-msvc/release/oxparse.exe ecosystem
  {{llvm_profdata_bin}} merge -o {{pgo_data_dir}}/merged.profdata {{pgo_data_dir}}
  just build-pgo-final

build-pgo-init $RUSTFLAGS="-Cprofile-generate=C:/source/rust/oxc/pgo-data":
  cargo build --release -p oxc_cli --bin oxparse --features allocator --target x86_64-pc-windows-msvc

build-pgo-final $RUSTFLAGS="-Cprofile-use=C:/source/rust/oxc/pgo-data/merged.profdata -Cllvm-args=-pgo-warn-missing-function":
  cargo build --release -p oxc_cli --bin oxparse --features allocator --target x86_64-pc-windows-msvc

ecosystem:
  cd "{{ecosystem_dir}}/DefinitelyTyped" && {{oxlint_bin}} --threads={{threads}}
  cd "{{ecosystem_dir}}/affine" && {{oxlint_bin}} --threads={{threads}}
  cd "{{ecosystem_dir}}/napi-rs" && {{oxlint_bin}} --threads={{threads}} --ignore-path=.oxlintignore
  cd "{{ecosystem_dir}}/preact" && {{oxlint_bin}} --threads={{threads}} oxlint src test debug compat hooks test-utils
  cd "{{ecosystem_dir}}/rolldown" && {{oxlint_bin}} --threads={{threads}} --ignore-path=.oxlintignore
  cd "{{ecosystem_dir}}/vscode" && {{oxlint_bin}} --threads={{threads}}

# Repository Guidelines

## Project Structure & Module Organization

This repository is a learning workspace for Bazel and C++. `learn_guide.md` contains the staged curriculum, from basic targets through toolchains. `README.md` is the minimal project entry point. `Dockerfile` and `compose.yaml` define an Ubuntu 22.04 development environment.

The `exercises/` and `doc/` directories are currently empty; place runnable exercises and supplementary notes there, respectively. Keep each exercise's source files, build definitions, and tests together. No application sources, Bazel modules, test suites, or assets exist yet. When adding an independent exercise, document its module root and run commands from that directory.

## Build, Test, and Development Commands

- `docker compose build bazel-dev`: build the development image.
- `docker compose up -d bazel-dev`: start the persistent development container.
- `docker compose exec bazel-dev bash`: open a shell in `/workspace`, which mounts this repository.
- `docker compose down`: stop and remove the Compose container.
- `docker compose config`: validate and inspect the resolved Compose configuration.

The image includes C/C++ tools, curl, and Bazelisk 1.29.0 as `bazel`. Keep `.bazelversion` and Dockerfile's `USE_BAZEL_FALLBACK_VERSION` aligned at 8.8.1; the fallback covers directories without a module. First use downloads Bazel and requires network access. Verify with `docker compose exec bazel-dev bazel --version`. Within an exercise module, use `bazel build //...`, `bazel test //...`, or `bazel run //:demo`; the last requires a `demo` target.

## Coding Style & Naming Conventions

Match existing files: use two-space YAML indentation and four-space indentation in Bazel/Starlark examples. Use descriptive `snake_case` target names and C++ filenames such as `calculator.cpp`, `calculator.h`, and `calculator_test.cpp`. Keep dependencies explicit in build definitions. No formatter or linter is currently configured.

## Testing Guidelines

There is no configured test framework or coverage threshold. For new C++ exercises, follow the guide's `cc_test` and GoogleTest approach, declaring the dependency in `MODULE.bazel`. Name test targets `<component>_test` and cover normal behavior and relevant edge cases. Run `bazel test //...` within each affected module and report any unavailable prerequisites.

## Commit & Pull Request Guidelines

Git history contains only `Initial commit`, so no established message convention exists. Use short, imperative subjects, for example `Add calculator exercise`. Keep changes focused. Pull requests should explain the learning objective or configuration change, list affected exercises, and record validation commands and results. Link related issues when applicable.

## Local Configuration

Compose defaults to UID/GID 1000. Set `DEV_UID` and `DEV_GID` to your host IDs when needed to keep bind-mounted files writable. Changes under `/workspace` affect the host checkout.

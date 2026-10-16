# 阶段 1：最小 C++ Bazel 项目

阶段 1 的目标是能够独立编写、构建和运行一个最小的 C++ Bazel 项目，先建立对 Bazel 基本结构和依赖关系的直观认识，不深入 Bazel 内部机制。

## 项目结构

一个最小模块可以包含：

```text
stage1_minimal/
├── MODULE.bazel
├── BUILD
├── main.cpp
├── calculator.cpp
└── calculator.h
```

`MODULE.bazel` 声明 Bazel 模块，例如：

```python
module(
    name = "stage1_minimal",
    version = "0.1.0",
)
```

`BUILD` 描述当前 package 中的构建 target：

```python
cc_library(
    name = "calculator",
    srcs = ["calculator.cpp"],
    hdrs = ["calculator.h"],
)

cc_binary(
    name = "demo",
    srcs = ["main.cpp"],
    deps = [":calculator"],
)
```

## 核心概念

`cc_binary` 定义 C++ 可执行程序。`name = "demo"` 定义名为 `demo` 的 target，`srcs` 声明该 target 直接使用的源文件。

`cc_library` 定义可被其他 target 使用的 C++ 库。`srcs` 是实现文件，`hdrs` 是对外提供的头文件。

`deps` 声明 target 之间的依赖关系。`demo` 通过 `deps = [":calculator"]` 依赖当前 package 中的 `calculator`。因此依赖图为：

```text
//:demo
   |
   v
//:calculator
```

`main.cpp` 的 `srcs` 不需要重复列出 `calculator.cpp` 或 `calculator.h`。Bazel 会通过 `deps` 获得 `calculator` 的编译接口和传递依赖，程序可以包含 `calculator.h` 并调用 `add()`。

## Label

```text
//:demo
```

是一个 Label，表示根 package 中名为 `demo` 的 target，不是文件路径。`:calculator` 是当前 package 中 `//:calculator` 的简写。

## 常用命令

命令应在包含 `MODULE.bazel` 的模块目录中执行：

```bash
bazel build //:demo
bazel run //:demo
```

`bazel build` 只构建 target；`bazel run` 会先确保 target 已构建，再执行生成的程序。示例程序的预期输出是：

```text
2 + 3 = 5
```

## 阶段 1 检查清单

- 能说明 `MODULE.bazel` 和 `BUILD` 的职责；
- 能区分 `cc_binary`、`cc_library`、`srcs`、`hdrs` 和 `deps`；
- 能读懂 `//:demo` 和 `:calculator`；
- 能解释 `//:demo` 到 `//:calculator` 的依赖关系；
- 能独立运行 `bazel build //:demo` 和 `bazel run //:demo`。

## 容器环境问题

如果容器使用只有数字 UID/GID 的用户，可能出现 `I have no name!`，并因 `$USER` 未设置导致 Bazel 启动失败。当前项目通过构建参数创建与宿主机 UID/GID 对应的 `bazel` 用户，并设置 `USER=bazel`，因此不需要每次手动执行 `export USER=bazel`。

问题现象和排查过程记录在：[Bazel `$USER` 未设置](../problem_list/bazel_user_unset.md)。

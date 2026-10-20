# 阶段 2：理解 Bazel 工程结构

阶段 2 的目标是从“能写一个 target”提升到“能阅读多目录 Bazel 工程”。核心是区分目录、package、target 和 Label，并用依赖图理解 target 之间的关系。

## 多 package 工程

一个练习模块可以组织为：

```text
stage2_packages/
├── MODULE.bazel
├── app/
│   ├── BUILD
│   └── main.cpp
└── libs/
    └── math/
        ├── BUILD
        ├── math.cpp
        ├── math_extra.cpp
        └── math.h
```

包含 `BUILD` 或 `BUILD.bazel` 的目录是一个 package。因此这里有两个 package：

```text
//app
//libs/math
```

目录本身不是 target。target 是 `BUILD` 中规则实例的名称，例如：

```python
# libs/math/BUILD
cc_library(
    name = "math",
    srcs = glob(["*.cpp"]),
    hdrs = glob(["*.h"]),
    visibility = [
        "//app:__pkg__",
    ],
)
```

这定义了 `//libs/math:math`。`app/BUILD` 中的可执行 target 可以依赖它：

```python
cc_binary(
    name = "app",
    srcs = ["main.cpp"],
    deps = [
        "//libs/math:math",
    ],
)
```

依赖图为：

```text
//app:app
     |
     v
//libs/math:math
```

这与按目录处理 `CMakeLists.txt` 的思路不同。阅读 Bazel 工程时，应先识别 package 和 target，再沿 `deps` 追踪依赖图。

## Label

Label 的一般形式是：

```text
//package:target
```

例如：

```text
//app:app
//libs/math:math
```

其中 `//app:app` 表示 `app` package 中的 `app` target，`//libs/math:math` 表示 `libs/math` package 中的 `math` target。

在 `app/BUILD` 中，`:math` 只会解析为当前 package 的 `//app:math`，不会自动到 `//libs/math` 查找。因此**跨 package 依赖要使用完整 Label**：

```text
//libs/math:math
```

`@xxx//foo:bar` 则表示外部 repository 或模块中的 target。

## visibility

target 存在并不意味着任何 package 都能依赖它。下面的声明只允许 `//app` package 访问 `math`：

```python
visibility = [
    "//app:__pkg__",
]
```

如果把它改为：

```python
visibility = [
    "//libs/math:__pkg__",
]
```

再构建 `//app:app`，Bazel 会在分析阶段报告 visibility error。这个错误说明 Label 和 target 可能都正确，但调用方没有访问权限。

`//visibility:public` 可以开放给所有 package 使用，适合确实需要作为公共接口的 target。

## glob

```python
srcs = glob(["*.cpp"])
hdrs = glob(["*.h"])
```

`glob` 只匹配当前 package 中符合模式的文件。例如 `libs/math` 中的 `math.cpp` 和 `math_extra.cpp` 都会被收集；如果某个子目录包含自己的 `BUILD` 文件，它就是另一个 package，不会被当前 `glob` 跨 package 收集。

可以使用 query 检查 `glob` 的展开结果：

```bash
bazel query 'labels(srcs, //libs/math:math)'
bazel query 'labels(hdrs, //libs/math:math)'
```

## query 与依赖图

列出当前模块的 target：

```bash
bazel query //...
```

查询某个 target 的完整依赖闭包：

```bash
bazel query 'deps(//app:app)'
```

结果除了 `//app:app` 和 `//libs/math:math`，还可能包含源文件 target，以及 Bazel C++ 规则自动引入的工具链 target。工具链依赖属于 Bazel 的隐式构建依赖，初学阶段只需知道它们会出现在完整依赖查询中。

`labels()` 和 `deps()` 的关注点不同：

- `labels(attr, expr)` 查看 `expr` 中每个 target 的指定属性 `attr` 直接引用了哪些 Label。例如：

  ```bash
  bazel query 'labels(srcs, //libs/math:math)'
  ```

  该命令查看 `//libs/math:math` 的 `srcs` 属性，结果可能包含 `//libs/math:math.cpp` 等源文件 target。它只读取这个属性的直接引用，不会递归展开这些文件或 target 的依赖。

- `deps(expr)` 沿构建依赖边遍历，从 `expr` 中的 target 得到直接依赖和传递依赖组成的依赖闭包，通常也包含起始 target 本身。例如 `deps(//app:app)` 会继续展开 `app` 对 `math` 的依赖，以及构建过程中相关的源文件和工具链 target。

因此，`labels()` 适合查看某个规则属性声明了什么，`deps()` 适合查看构建一个 target 需要经过哪些依赖。

## 常用验证命令

在包含 `MODULE.bazel` 的模块根目录执行：

```bash
bazel build //app:app
bazel build //...
bazel run //app:app
```

阶段 2 的练习应验证 `//app:app` 能通过 `//libs/math:math` 构建并运行，并能通过修改 `visibility` 观察权限错误，再恢复正确配置。

## 阶段 2 检查清单

- 能区分目录、package、target 和 Label；
- 能解释 `//package:target` 与 `:target` 的区别；
- 能画出多 package 工程的依赖图；
- 能使用 `visibility` 限制 target 的访问范围；
- 能说明 `glob` 的匹配范围和 package 边界；
- 能使用 `bazel query //...` 和 `deps()` 查看 target 与依赖闭包；
- 能定位 Label 错误、依赖缺失和 visibility 错误的基本原因。

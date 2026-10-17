# 阶段 3：构建、测试和问题定位

本阶段的目标是：能够验证代码行为、查询依赖关系，并根据失败阶段定位 Bazel 构建问题。本次实践沿用 [stage2_packages](../exercises/stage2_packages/) 工程，没有新建独立模块。

## 练习环境与目标

在仓库根目录进入容器，然后切换到练习模块根目录：

```bash
docker compose exec bazel-dev bash
cd /workspace/exercises/stage2_packages
```

下文所有 Bazel 命令都在该目录执行。这里的 `//` 从该模块的主仓库根目录解析，而不是从整个学习仓库或文件系统根目录解析。

练习中的依赖关系：

```text
//app:app ───────────────→ //libs/math:math
                                  ↑
//libs/math:math_test ──────────────┘
          ├─────────────→ @googletest//:gtest
          └─────────────→ @googletest//:gtest_main
```

## 构建、运行与测试

| 命令 | 作用 |
|---|---|
| `bazel build //app:app` | 构建指定目标及其所需依赖 |
| `bazel run //app:app` | 确保构建成功后运行程序 |
| `bazel build //app/...` | 构建 app package 及其子 package 中的目标 |
| `bazel build //...` | 构建当前主仓库所有 package 中的目标 |
| `bazel test //...` | 构建所选目标，并执行测试或复用有效测试结果 |

选择范围不限制依赖的构建范围。即使 `math` 位于 `app/` 之外，构建 `//app:app` 时仍会考虑它。修改 `math.cpp` 后，Bazel 会检查受影响的编译、链接动作；命中缓存时可能直接复用产物。

构建成功不代表行为正确。程序输出一次 `2 + 3 = 5`，也不足以证明负数、零等情况正确，需要自动化测试覆盖。

## 使用 GoogleTest 和 cc_test

在模块根目录的 `MODULE.bazel` 中声明直接依赖，本次练习使用：

```python
bazel_dep(
    name = "googletest",
    version = "1.14.0.bcr.1",
)
```

即使锁文件中已有 GoogleTest 的间接依赖记录，项目自己使用时仍应声明直接依赖。

新建 `libs/math/math_test.cpp`：

```cpp
#include "libs/math/math.h"

#include <gtest/gtest.h>

TEST(AddTest, PositiveNumbers) {
    EXPECT_EQ(add(2, 3), 5);
}

TEST(AddTest, NegativeNumbers) {
    EXPECT_EQ(add(-2, -3), -5);
}

TEST(AddTest, MixedSigns) {
    EXPECT_EQ(add(-2, 3), 1);
}

TEST(AddTest, Zero) {
    EXPECT_EQ(add(0, 0), 0);
    EXPECT_EQ(add(5, 0), 5);
    EXPECT_EQ(add(0, 5), 5);
}
```

`TEST` 的两个参数分别是测试套件名和用例名。`EXPECT_EQ` 检查两个值是否相等，失败后记录错误并继续执行当前测试。`gtest_main` 提供测试入口，因此不需要自己编写 `main()`。

`libs/math/BUILD` 的完整定义：

```python
cc_library(
    name = "math",
    srcs = glob(
        ["*.cpp"],
        exclude = ["*_test.cpp"],
    ),
    hdrs = glob(["*.h"]),
    visibility = [
        "//app:__pkg__",
    ],
)

cc_test(
    name = "math_test",
    size = "small",
    srcs = ["math_test.cpp"],
    deps = [
        ":math",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)
```

必须从库的 `glob` 中排除测试源码，防止 `math_test.cpp` 被编进 `math` 库。`math_test` 与 `math` 位于同一个 package，不需要额外开放 visibility。

```bash
bazel test //libs/math:math_test --test_output=all
bazel test //... --test_output=errors
```

`all` 显示测试输出；`errors` 在测试失败时显示输出。当前有 4 个 GoogleTest 用例，但只有 1 个 Bazel 测试 target。

### 读取测试失败信息

将第一个断言的期望值暂时改为 `6`，会得到：

```text
libs/math/math_test.cpp:6: Failure
Expected equality of these values:
  add(2, 3)
    Which is: 5
  6
```

这表示编译成功，测试执行时发现实际值 `5` 与期望值 `6` 不一致。本次错误在断言，观察后应恢复为 `5`。

一个用例失败会使整个 `math_test` target 失败。日志中的 `Target ... up-to-date` 只表示测试程序已构建就绪，不表示测试通过。

### 理解测试缓存

```text
//libs/math:math_test (cached) PASSED
Executed 0 out of 1 test: 1 test passes.
```

这表示复用了此前成功的测试结果，本次没有重新执行测试程序。相关输入及配置没有发生需要重新测试的变化时，Bazel 可以使用测试缓存。

## 头文件路径与工程约定

`#include` 中填写的是编译器使用的头文件路径，不是 Bazel Label。本练习建议统一使用相对于仓库根目录的路径：

```cpp
#include "libs/math/math.h"
```

这里的仓库根目录是 `exercises/stage2_packages`，不是整个学习仓库。在当前 Bazel C++ 构建配置下，Bazel 设置的搜索路径允许编译器以这种形式查找正确声明并通过依赖提供的头文件。

### 同目录写法与仓库相对路径

对于当前使用的 GCC，双引号 include 会先搜索当前源文件所在目录，再搜索其他配置的头文件目录。因此，`math.cpp` 和 `math_test.cpp` 与 `math.h` 同目录，也可以写：

```cpp
#include "math.h"
```

但在 `app/main.cpp` 中直接写 `"math.h"`，当前配置下通常找不到。声明 `deps` 并不等于自动把每个依赖头文件所在的目录都加入搜索路径。

| 写法 | 工程建议 |
|---|---|
| `"libs/math/math.h"` | 当前工程的默认选择，来源明确，减少重名歧义 |
| `"math.h"` | 同目录实现引用自己的头文件时合理，但应保持团队约定一致 |
| `"../../libs/math/math.h"` | 避免，容易因调用方目录调整而失效 |
| `"/workspace/.../math.h"` | 避免，将源码绑定到具体环境路径 |

统一采用仓库相对路径后，只要头文件位置不变，移动引用它的 `.cpp` 时通常不需要修改 include。不过，目标的 `deps` 和访问权限仍需正确配置。

这是一项工程风格建议，不代表当前所有源码已经统一修改；本次练习中的 `math.cpp` 原先使用 `"math.h"`，该写法同样有效。

### include、hdrs 与 deps 的分工

三个声明需要配合：

- 库的 `hdrs = ["math.h"]`：声明库提供的头文件。
- 调用方的 `deps = ["//libs/math:math"]`：声明对库的构建依赖。
- 源码中的 `#include "libs/math/math.h"`：指定编译器需要包含的头文件。

不要仅通过调整 include 路径掩盖缺失的构建依赖。

### 独立发布库时设计公共路径

如果以后将库独立发布，可以设计稳定的公共 include 路径，例如：

```cpp
#include "myproject/math.h"
```

Bazel 的 `strip_include_prefix` 和 `include_prefix` 可用于移除原有路径前缀、添加公共路径前缀，使调用方不必依赖库在磁盘上的内部目录布局。当前练习尚不需要这些配置，采用仓库相对路径并正确声明 `hdrs`、`deps` 即可。

## 使用 query 阅读依赖关系

| 命令 | 回答的问题 |
|---|---|
| `bazel query //...` | 当前工程有哪些目标？ |
| `bazel query 'deps(//app:app)'` | app 的依赖闭包是什么？ |
| `bazel query 'rdeps(//..., //libs/math:math)'` | 当前工程中哪些目标依赖 math？ |
| `bazel query 'kind("cc_binary rule", //...)'` | 有哪些 C++ 可执行程序目标？ |
| `bazel query 'kind("cc_test rule", //...)'` | 有哪些 C++ 测试目标？ |
| `bazel query '//libs/math:*' --output=label_kind` | math package 有哪些目标及其类型？ |

`deps` 和 `rdeps` 的结果包含起点自身。完整依赖查询也可能包含源文件和隐式工具依赖。

本次反向依赖查询得到以下目标，顺序不固定：

```text
//app:app
//libs/math:math
//libs/math:math_test
```

可以组合查询，缩小修改影响范围：

```bash
# 依赖 math 的 C++ 应用程序
bazel query 'kind("cc_binary rule", rdeps(//..., //libs/math:math))'

# 依赖 math 的 C++ 测试
bazel query 'kind("cc_test rule", rdeps(//..., //libs/math:math))'
```

`//libs/math:*` 不仅包含规则目标，还包括源文件和生成文件目标。查询到生成文件目标，不代表该文件已实际生成。

## 按失败阶段排查问题

| 失败阶段 | 本次现象或常见问题 | 优先检查 |
|---|---|---|
| 分析 | `no such target` | Label 的 package、target 名称及定义 |
| 分析 | `Visibility error` | 被依赖目标的 visibility |
| 编译 | `No such file or directory` | include 路径、deps、库的 hdrs |
| 编译或依赖检查 | `undeclared inclusion` | 头文件是否正确声明并通过依赖提供 |
| 链接 | 未定义符号 | 函数实现及提供实现的库是否参与链接 |
| 测试执行 | 断言失败 | 实际行为与期望是否一致 |

其中链接错误和 `undeclared inclusion` 是补充排查方向，本次没有单独制造这两种错误。

### 实验一：删除 deps

暂时删除 `app/BUILD` 中的 `"//libs/math:math"`，保留源码中的 include 和函数调用。本次观察到：

```text
Compiling app/main.cpp failed
fatal error: libs/math/math.h: No such file or directory
```

头文件存在于仓库中，不等于会作为输入提供给编译动作。`#include` 告诉编译器包含哪个头文件，`deps` 告诉 Bazel 从哪个 target 获取头文件、编译信息和链接产物，两者需要配合。

### 实验二：写错 target 名称

暂时将依赖改成 `//libs/math:math_missing`，观察到：

```text
no such target '//libs/math:math_missing'
Analysis of target '//app:app' failed
```

package 存在，但目标未定义，构建在分析阶段失败，尚未执行 C++ 编译。可用 `query` 检查该 package 中的实际目标。

### 实验三：限制 visibility

恢复正确 Label，再将 `math` 的 visibility 暂时改为：

```python
visibility = ["//visibility:private"],
```

观察结果：

- `bazel build //app:app` 分析失败，因为 app 跨 package 访问私有目标。
- `bazel test //libs/math:math_test` 通过，因为测试与库在同一个 package。

实验结束后恢复 `visibility = ["//app:__pkg__"]`，并恢复所有依赖和正确断言。

## 辅助诊断与清理

```bash
# 显示失败步骤的完整命令
bazel build //app:app --verbose_failures

# 查看工作区和可执行文件输出目录
bazel info workspace
bazel info bazel-bin

# 清理构建输出，需要时再使用
bazel clean
```

`--sandbox_debug` 可用于进一步检查沙箱，并保留沙箱构建目录。普通 Label、deps 或 visibility 错误应先修复声明，`bazel clean` 不会修复这些配置错误。

读日志时，先找失败动作，再看具体诊断，最后结合最近修改定位原因。`BUILD` 中的位置通常指出所属规则，编译器报告的 `.cpp` 行号则指出源码问题位置。

## 补充：模块解析与 Docker 缓存

首次构建时，即使自己的 `MODULE.bazel` 没有声明外部依赖，Bazel 内置模块也会引入构建支持。本次观察到 `bazel_tools` 依赖 `rules_cc`、`rules_java`、`rules_python`、`protobuf` 等模块。

需要区分三个步骤：模块依赖解析、下载源码或工具、编译代码。某个模块出现在 `MODULE.bazel.lock`，不能证明它已经被编译或链接进应用程序。

- `registryFileHashes` 记录解析期间读取的注册表文件及校验值，可能包含同一模块多个版本的元数据。
- `moduleExtensions` 记录模块扩展的计算信息及生成的仓库定义；定义中出现下载地址，不等于该文件已下载。
- 锁文件保存解析信息，不保存依赖源码或编译产物。

查看模块依赖图：

```bash
bazel mod graph
bazel mod graph --include_builtin --depth=2
```

默认隐藏内置模块；显式依赖为空时，默认图可能只有根模块。添加 GoogleTest 后，则可看到显式依赖。`--include_builtin` 用于查看内置模块及其依赖入口。

模块图回答“有哪些外部模块关系”，`bazel query` 的 target 图回答“目标有哪些构建依赖”，两者层次不同。

本次环境设置 `HOME=/tmp`，实际日志中的用户缓存位于 `/tmp/.cache/bazel`。复用或重启同一个容器会保留其文件；`docker compose down` 删除容器后，未持久化的运行时缓存会丢失。镜像预置的 `/opt/bazelisk` 缓存与运行练习时产生的缓存需要区分。

如需跨容器保留用户缓存，可以另行配置命名卷挂载到 `/tmp/.cache/bazel`，并确保运行用户有写权限。这是配置建议，不是本章练习中已实施的变更。普通 `down` 保留命名卷，`down -v` 会删除相关卷。

## 本次验证结果与完成标准

恢复配置后，实际执行：

```bash
bazel build //...
bazel test //...
```

结果：3 个规则目标构建成功，1 个测试 target 通过；最后一次测试复用了成功缓存。

完成本阶段后，应能：

- 区分构建成功、测试通过和缓存复用。
- 编写 cc_test，覆盖正常行为及相关边界情况。
- 用 deps、rdeps 和 kind 查询依赖与修改影响范围。
- 区分分析、编译、链接与测试阶段的失败。
- 根据日志优先检查 Label、deps、hdrs 和 visibility。
- 使用 info 和诊断选项，不把 clean 当作配置错误的通用修复方式。

下一阶段学习 Bzlmod 和第三方依赖，可在本次 GoogleTest 实践的基础上继续接入 fmt、protobuf。

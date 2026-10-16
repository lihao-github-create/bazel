# Bazel 因未设置 `$USER` 导致构建失败

## 现象

在开发容器中执行 Bazel 构建时，出现：

```text
FATAL: $USER is not set, and unable to look up name of current user: (error: 0): Success
```

容器提示符显示为：

```text
I have no name!@<container-id>
```

## 原因

`compose.yaml` 使用宿主机的 UID/GID 运行容器：

```yaml
user: "${DEV_UID:-1000}:${DEV_GID:-1000}"
```

该数字用户可能没有对应的 `/etc/passwd` 用户名，因此 Shell 无法显示用户名，提示为 `I have no name!`。

同时，Compose 当前只设置了 `HOME`，没有设置 `USER` 环境变量。Bazel 在 `$USER` 未设置时尝试查询当前用户名称，但容器中没有可查询的用户记录，最终导致构建在启动阶段失败。

## 临时解决方案

在当前容器 Shell 中设置一个非空的 `$USER`：

```bash
export USER=bazel
```

然后在包含 `MODULE.bazel` 的 Bazel 模块目录中重新执行构建：

```bash
bazel build //:demo
```

## 验证结果

设置 `$USER` 后，构建成功完成，并且：

```bash
bazel run //:demo
```

能够正常输出：

```text
2 + 3 = 5
```

## 注意

如果从模块的父目录执行 Bazel，还会出现找不到 workspace/module 的警告。应先进入包含 `MODULE.bazel` 的目录，例如：

```bash
cd /workspace/exercises/stage1_minimal
```

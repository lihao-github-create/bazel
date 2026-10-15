# Bazel 学习环境

使用 Docker 提供 C/C++ 与 Bazel 学习环境，学习路线见 [learn_guide.md](learn_guide.md)。

## 环境组成

| 项目 | 配置 |
| --- | --- |
| 基础系统 | Ubuntu 22.04 |
| Compose 服务 | `bazel-dev` |
| 镜像 | `bazel-study:ubuntu22.04` |
| 工作目录 | `/workspace`，挂载当前仓库 |
| Bazelisk | 1.29.0，通过 `bazel` 或 `bazelisk` 调用 |
| Bazel | 8.8.1，由 `.bazelversion` 和镜像回退版本固定 |
| 开发工具 | GCC/G++、Clang、GDB、CMake、Ninja、Git、curl、Python 3、pkg-config、Eigen |

镜像支持 amd64 和 arm64。Bazelisk 在构建镜像时安装并校验 SHA-256；Bazel 在首次调用时下载。

## 1. 检查宿主机

需要安装并启动 Docker Engine 或 Docker Desktop，以及 Docker Compose v2。以下命令在宿主机的仓库根目录执行：

```bash
docker version
docker compose version
```

`docker version` 应同时显示 Client 和 Server 信息。若无法连接 Docker daemon，请先启动 Docker 并确认当前用户具有访问权限。

构建和首次运行需要网络访问：Docker Hub、Ubuntu 软件源、GitHub 和 Bazel 官方下载服务。后续练习的外部依赖也可能需要联网下载。

## 2. 构建并启动

Linux 上建议先匹配宿主机用户 ID，避免挂载目录出现写权限问题。以下设置对当前终端有效；默认 UID/GID 均为 1000。

```bash
export DEV_UID="$(id -u)"
export DEV_GID="$(id -g)"
```

校验配置、构建镜像并启动服务：

```bash
docker compose config --quiet
docker compose build bazel-dev
docker compose up -d bazel-dev
docker compose ps
```

配置校验成功时没有输出；`ps` 中的 `bazel-dev` 应显示为运行状态。服务通过 `sleep infinity` 保持运行。

## 3. 检查环境

以下命令仍在宿主机执行：

```bash
# 应输出 /workspace，并显示容器运行用户的 UID/GID。
docker compose exec bazel-dev pwd
docker compose exec bazel-dev id

# 检查仓库挂载和写权限；成功时没有输出。
docker compose exec bazel-dev sh -c 'test -f /workspace/learn_guide.md && test -w /workspace'

# 不下载 Bazel，应输出 Bazelisk version: v1.29.0。
docker compose exec bazel-dev bazelisk bazeliskVersion

# 首次执行会下载 Bazel，完成后应输出 bazel 8.8.1。
docker compose exec bazel-dev bazel --version

# 检查基础开发工具，均应输出版本信息。
docker compose exec bazel-dev sh -c 'gcc --version && g++ --version && clang --version && gdb --version'
docker compose exec bazel-dev sh -c 'cmake --version && ninja --version && git --version && curl --version && python3 --version'
docker compose exec bazel-dev pkg-config --modversion eigen3
```

工具版本以镜像实际安装结果为准；Eigen 检查应输出 `3.4.0`。下载过程中可能长时间没有新输出，需等待命令结束后判断结果。

当前仓库还没有 `MODULE.bazel`、构建目标或测试代码，因此上述检查只验证工具环境。添加练习后，在对应模块根目录执行 `bazel build //...` 和 `bazel test //...` 验证项目。

## 4. 日常使用

进入开发容器：

```bash
docker compose exec bazel-dev bash
```

容器内 `/workspace` 的文件修改会同步到宿主机。输入 `exit` 只退出当前 Shell，服务继续运行。

在宿主机停止或恢复服务：

```bash
docker compose stop bazel-dev
docker compose start bazel-dev
```

修改 Dockerfile 后，重新构建并更新容器：

```bash
docker compose up -d --build bazel-dev
```

移除本项目的容器和默认网络：

```bash
docker compose down
```

源码位于宿主机挂载目录，不随容器删除。当前 `HOME=/tmp`，没有配置持久化缓存卷；删除或重建容器后，Bazelisk 下载缓存和 Bazel 构建缓存可能需要重新生成。`stop` / `start` 会保留原容器中的缓存。

## 常见问题

- **`exec` 提示服务未运行**：先执行 `docker compose up -d bazel-dev`。
- **仓库目录不可写**：检查宿主机目录权限，并设置正确的 `DEV_UID` / `DEV_GID` 后执行 `docker compose up -d --force-recreate bazel-dev`。
- **下载超时**：检查宿主机和容器的网络、DNS 或代理配置；确认网络恢复后重试构建或 `bazel --version`。
- **升级 Bazel**：同步修改 `.bazelversion` 和 Dockerfile 中的 `USE_BAZEL_FALLBACK_VERSION`，然后重新构建。后者保证尚未创建 Bazel 模块时也使用固定版本；构建时会检查两者一致。
- **升级 Bazelisk**：同步更新 Dockerfile 中的下载版本和 amd64/arm64 校验值。

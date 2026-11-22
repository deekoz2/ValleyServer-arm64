# ValleyServer-arm64

**星露谷物语无头专用服务器 · linux-arm64（DSH 修复版）**

本仓库是 [Lixeer/ValleyServer](https://github.com/Lixeer/ValleyServer) v3.0.3 的 **linux-arm64** 移植/修复版：不依赖游戏本体和 Steam，直接在 arm64 设备（手机 / 开发板）上运行星露谷多人专用服务器。

📱 配套手机 APP（检测 Termux + 一键安装）：**[StarDewOpener](https://github.com/deekoz2/StarDewOpener)**

## 一键安装（Termux / ZeroTermux）

```sh
pkg install -y curl
curl -fsSL https://cdn.jsdelivr.net/gh/deekoz2/ValleyServer-arm64@main/install.sh -o install.sh \
  || curl -fsSL https://raw.githubusercontent.com/deekoz2/ValleyServer-arm64/main/install.sh -o install.sh
bash install.sh
```

- 448MB 服务器大包会按 **ghfast.top → gh-proxy.com → ghproxy.net → 直连** 顺序自动尝试，
  带字节数校验与断点续传；想换镜像直接改 install.sh 顶部的 `MIRRORS` 数组即可。

参数：`--server` 跳过容器创建（已有 tmoe 容器）；`--start` 部署完直接后台启动。

脚本会自动完成：

1. 安装 Termux 基础依赖（curl / proot / unzip / aria2 等）；
2. 调用 **tmoe**（[gitee.com/mo2/linux](https://gitee.com/mo2/linux)）向导创建 **Debian arm64 proot 容器**（菜单里选 `新建容器 → Debian → arm64 → proot`）；
3. 从 Releases 下载 `ValleyServer-linux-arm64.zip`（约 448MB，自包含 .NET 运行时，支持断点续传）；
4. 解压部署到容器 `/opt/valleyserver`，执行 `patch-arm64.sh`；
5. 生成 Termux 快捷命令 `valley`。

## 启动与联机

| 命令 | 作用 |
| --- | --- |
| `valley` | 前台启动（控制台输入 `help` 查看指令） |
| `valley start` | 后台启动，日志 `~/valley-server.log` |
| `valley stop` | 停止服务器 |
| `valley log` | 查看最近日志 |
| `valley ip` | 查看局域网 IP |

- 默认端口 **24642/udp**，首次启动生成 `config.json` 可修改；
- 好友联机：同一 Wi-Fi 下填 `你的IP:24642`；外网联机需内网穿透（frp / Tailscale 等）；
- 首次启动较慢（生成世界数据），耐心等待。

## 手动运行

从 [Releases](https://github.com/deekoz2/ValleyServer-arm64/releases) 下载 `ValleyServer-linux-arm64.zip`，解压后：

```sh
chmod +x ValleyServer
./ValleyServer
```

## 致谢与许可

- 服务器本体：[Lixeer/ValleyServer](https://github.com/Lixeer/ValleyServer)（Apache-2.0），感谢原作者！喜欢请去给原项目点 star。
- 本仓库遵循 [Apache-2.0](LICENSE)。
- 如果你喜欢星露谷物语，请支持正版。

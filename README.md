# ValleyServer-arm64

**星露谷物语无头专用服务器 · linux-arm64（DSH 修复版）+ Android 一键开服工具**

本仓库是 [Lixeer/ValleyServer](https://github.com/Lixeer/ValleyServer) v3.0.3 的 **linux-arm64** 移植/修复版：不依赖游戏本体和 Steam，直接在 arm64 设备（手机 / 开发板）上运行星露谷多人专用服务器。在此之上新增了：

- 📱 **Android APP（星露谷开服器）**：检测 Termux / ZeroTermux、验证连通性、一键安装
- ⚡ **一键安装脚本 `install.sh`**：在 Termux/ZeroTermux 里自动完成 容器 + 服务器部署

## 两条安装路线

### 路线 A · 手机 APP（推荐）

1. 手机安装 [Termux](https://github.com/termux/termux-app/releases) 或 ZeroTermux，打开一次；
2. 安装本仓库 [Releases](https://github.com/deekoz2/ValleyServer-arm64/releases) 里的 `valley-launcher.apk`；
3. 打开「星露谷开服器」：
   - 点 **检测连接** —— APP 通过系统 `RUN_COMMAND` intent 调起 Termux 执行测试命令并等待回执，验证链路；
   - 点 **一键安装** —— 在 Termux 里自动执行 `install.sh`；
4. 按提示在 tmoe 菜单选择 `新建容器 → Debian → arm64 → proot`，之后全自动。

> 若连接检测无回执：在 Termux 里执行
> `mkdir -p ~/.termux && echo "allow-external-apps=true" >> ~/.termux/termux.properties`
> 然后重启 Termux，并允许其后台运行（关闭电池优化）。

### 路线 B · 纯命令行

在 Termux / ZeroTermux 里：

```sh
pkg install -y curl
curl -fsSL https://raw.githubusercontent.com/deekoz2/ValleyServer-arm64/main/install.sh -o install.sh
bash install.sh
```

参数：`--server` 跳过容器创建（已有 tmoe 容器）；`--start` 部署完直接启动。

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

## install.sh 做了什么

1. 安装 Termux 基础依赖（curl / proot / unzip 等）；
2. 调用 **tmoe**（[gitee.com/mo2/linux](https://gitee.com/mo2/linux)）向导创建 **Debian arm64 proot 容器**；
3. 从 Releases 下载 `ValleyServer-linux-arm64.zip`（约 448MB，自包含 .NET 运行时，断点续传）；
4. 解压部署到容器 `/opt/valleyserver`，执行 `patch-arm64.sh`；
5. 生成 Termux 快捷命令 `valley`（start / stop / log / ip）。

## 自己构建 APP（无需 Android Studio）

```sh
apt install openjdk-17-jdk-headless aapt dalvik-exchange apksigner zip
curl -L -o /tmp/android.jar \
  https://raw.githubusercontent.com/Sable/android-platforms/master/android-30/android.jar
cd app && SDK_JAR=/tmp/android.jar bash build.sh
# 产物: app/build/valley-launcher.apk
```

APP 实现说明（源码在 [app/src](app/src)）：

- 通过 `PackageManager` 检测 `com.termux` / `com.zerotermux` 是否安装；
- 通过 Termux `RUN_COMMAND` intent（`allow-external-apps`）下发命令，
  用 `PendingIntent` 接收回执验证连通，超时给出排查提示；
- 兼容 Termux 与 ZeroTermux（fork 包名不同但保持同一套 service/action）。

## 致谢与许可

- 服务器本体：[Lixeer/ValleyServer](https://github.com/Lixeer/ValleyServer)（Apache-2.0），感谢原作者！喜欢请去给原项目点 star。
- 本仓库的 APP 与脚本同样遵循 [Apache-2.0](LICENSE)。
- 如果你喜欢星露谷物语，请支持正版。

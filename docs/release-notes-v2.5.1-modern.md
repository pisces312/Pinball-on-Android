# Modernization Release — fexed/Pinball-on-Android

**This release is a full modernization of the upstream project [`fexed/Pinball-on-Android`](https://github.com/fexed/Pinball-on-Android) (3D Pinball Space Cadet Android port, last updated 2023-10-08).**

**本发布是对上游项目 [`fexed/Pinball-on-Android`](https://github.com/fexed/Pinball-on-Android)（3D 弹球 Space Cadet Android 移植，上次更新于 2023-10-08）的完整现代化改造。**

---

## 现代化改造内容 / Modernization Highlights

### 构建工具链升级 / Build Toolchain Upgrade

| 项 / Item | 上游 / Upstream | 现代 / Modern |
|-----------|-----------------|---------------|
| AGP | 7.2.2 | 9.2.0 |
| Gradle | 7.3.3 | 9.4.1 |
| compileSdk / targetSdk | 33 | 36 |
| minSdk | 19 | 21 |
| JDK | — | JBR 21 |
| SDL 子模块 | 2.0.22 | 2.30.12 |

### 依赖清理 / Dependency Cleanup

- ✅ 移除 Firebase Analytics（8 处统计埋点，无功能损失）
- ✅ 移除 jcenter / Jetifier
- ✅ 保留 volley（在线排行榜 API 仍活跃）

### 兼容性修复 / Compatibility Fixes

- ✅ SDL 升级到 2.30.12，修复 NDK 28 下 `ALooper_pollAll` 被废弃导致的编译失败
- ✅ 同步 SDL Java 层到 2.30，修复 JNI 签名不匹配导致的启动闪退
- ✅ 恢复上游竖屏加宽适配与方向锁定，修复画面布局居中 + ANR 无响应

### 构建产物 / Build Artifact

- ✅ 仅 arm64-v8a 单架构（30 MB）
- debug 构建，包名 `com.fexed.spacecadetpinball.debug`

---

## 安装 / Installation

下载下方 APK 直接安装（需允许未知来源）。

Download the APK below and install it directly (allow unknown sources).

## 致谢 / Credits

- 上游项目 / Upstream: [fexed/Pinball-on-Android](https://github.com/fexed/Pinball-on-Android)
- [SDL](https://github.com/libsdl-org/SDL) / [SDL_mixer](https://github.com/libsdl-org/SDL_mixer)

# Pinball-on-Android 构建文档

> 记录本项目从 fork 仓库 clone 到版本对齐、依赖升级、成功构建的全过程，含踩坑与解法。

## 1. 项目来源

| 项 | 值 |
|----|----|
| 上游仓库 | `github.com/fexed/Pinball-on-Android`（3D Pinball Space Cadet Android 移植） |
| Fork 仓库 | `pisces312/Pinball-on-Android` |
| Clone 来源 | **从本人 fork 仓库 clone**（`git@github.com:pisces312/Pinball-on-Android.git`） |
| 本地路径 | `D:\3rd-party-projects\Pinball-on-Android` |
| 当前分支 | `android` |
| 上游最后提交 | `c03e19d`「New version: 13」(2023-10-08) |

原项目最后一次更新停在 2023-10-08，依赖栈严重陈旧（AGP 7.2.2 / Gradle 7.3.3 / SDK 33 / minSdk 19），需整体对齐。

## 2. 版本对齐（已落地）

| 项 | 原值 | 新值 |
|----|------|------|
| AGP | 7.2.2 | 9.2.0 |
| Gradle | 7.3.3 | 9.4.1 |
| compileSdk / targetSdk | 33 | 36 |
| minSdk | 19 | 21 |
| NDK | 未指定 | 28.2.13676358（AGP 9.2 默认，本机已装） |
| JDK | 未明确 | JBR 21（本机 `D:\dev\AndroidStudio\jbr`） |
| appcompat | 1.6.1 | 1.7.1 |
| material | 1.8.0 | 1.13.0 |
| volley | 1.2.1 | 保留 1.2.1 |
| SDL 子模块 | 2.0.22 | 2.30.12 |
| SDL_mixer 子模块 | 2.0.4(旧) | 未动 |

### 变更明细

- **移除**：jcenter()、Jetifier（`android.enableJetifier`）、firebase-bom、google-services 插件。
- **删除 Firebase Analytics**：`MainActivity.java` 中 8 处埋点 + import + `firebaseAnalytics` 字段全部清除（纯统计埋点，无功能损失）。
- **保留 volley**：牵连两个真实功能 —— 在线排行榜 `HighScoreHandler` + GitHub 版本检查 `checkLatestRelease`（榜单后端 AWS Lambda 仍在运行）。
- **新增**：`local.properties`（`sdk.dir=D:\dev\android_sdk`）。
- **BuildConfig**：AGP 9 默认关闭，开启 `buildFeatures.buildConfig true`（`Settings.java` 用到 `BuildConfig.VERSION_NAME/CODE`）。
- **namespace**：manifest 移除 `package` 属性，改用 `android.namespace`。

## 3. 子模块初始化

`.gitmodules` 原 URL 为 GitHub HTTPS，但本环境 GitHub HTTPS 被墙，已改为 SSH：

```ini
[submodule "app/src/main/cpp/SDL"]
	path = app/src/main/cpp/SDL
	url = git@github.com:libsdl-org/SDL.git
[submodule "app/src/main/cpp/SDL_mixer"]
	path = app/src/main/cpp/SDL_mixer
	url = git@github.com:libsdl-org/SDL_mixer.git
```

初始化命令：

```powershell
git submodule sync
git submodule update --init --recursive
```

> ⚠️ `.gitmodules` 改成 SSH URL 会随 git 提交。若需保持上游 HTTPS 原样，可只本地用 SSH 拉取、不提交此改动。

## 4. 遇到的问题与解决方式

### 坑 1：`proguard-android.txt` 已被 AGP 9 移除

**报错**：
```
getDefaultProguardFile('proguard-android.txt') is no longer supported
since it includes -dontoptimize, which prevents R8 from performing many optimizations
```

**原因**：AGP 9 移除旧的 `proguard-android.txt` 默认规则文件。

**解决**：改用 `proguard-android-optimize.txt`：
```groovy
proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
```

### 坑 2：AGP 9 默认关闭 BuildConfig 生成

**报错**：`Settings.java` 编译失败 —— `找不到符号 变量 BuildConfig`。

**原因**：AGP 9 默认 `buildFeatures.buildConfig = false`，不再生成 `BuildConfig` 类。

**解决**：在 `app/build.gradle` 开启：
```groovy
buildFeatures {
    viewBinding true
    buildConfig true
}
```

### 坑 3：SDL 2.0.22 与 NDK 28 不兼容（`ALooper_pollAll` 被标记 unavailable）

**报错**：
```
error: 'ALooper_pollAll' is unavailable: obsoleted in Android 1 - ALooper_pollAll may ignore wakes. Use ALooper_pollOnce instead.
```

**原因**：老 SDL 2.0.22（2022）用了废弃 API，NDK 28 用 `__attribute__((unavailable))` 硬封死，编译选项绕不过。

**解决**：升级 SDL 子模块到 `release-2.30.12`（SDL 2.30 已官方修复所有 NDK 28 兼容问题）：
```powershell
cd app\src\main\cpp\SDL
git checkout release-2.30.12
```

（过程中还暴露了 C99 声明顺序警告，但 2.30 版本自带 `-Wno-error=declaration-after-statement`，无需额外处理。）

### 坑 4：SDL 2.30 生成式 config 头被全局 include 污染

**报错**：
```
SDL_config.h:58:2: error: Wrong SDL_config.h, check your include path?
```

**原因**：SDL 2.30 改用「生成配置头」机制，源码 `SDL/include/SDL_config.h` 只是 stub，真正的 config 由 SDL 的 CMake 在构建目录生成。项目 CMakeLists 里的全局 `include_directories(SDL/include)` 把 stub 目录塞进 SDL 自己所有源文件的 include 路径，导致优先命中 stub。

**解决**：删除全局 `include_directories`，完全依赖 `target_link_libraries` 的 PUBLIC include 传递（SDL2 target 已正确暴露生成的 config 目录）：

```cmake
# 删掉这两行全局 include：
# include_directories(${CMAKE_CURRENT_SOURCE_DIR}/SDL/include
#                     ${CMAKE_CURRENT_SOURCE_DIR}/SDL_mixer/include)

add_library(SpaceCadetPinball SHARED ${SOURCE_FILES})
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/SDL)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/SDL_mixer)
find_library(log-lib log)
# 通过 target 依赖传递 PUBLIC include（含 SDL 2.30 生成的 SDL_config.h）
target_link_libraries(SpaceCadetPinball SDL2 SDL2_mixer ${log-lib})
```

## 5. 构建命令

```powershell
cd D:\3rd-party-projects\Pinball-on-Android
.\gradlew.bat assembleDebug --no-daemon
```

产物：`app\build\outputs\apk\debug\app-debug.apk`（约 30MB，仅 arm64-v8a 单架构，`defaultConfig` 已设 `abiFilters 'arm64-v8a'`；debug 包名 `com.fexed.spacecadetpinball.debug`）。

### Release 签名构建（不开混淆）

```powershell
.\gradlew.bat assembleRelease --no-daemon
```

产物：`app\build\outputs\apk\release\app-release.apk`（约 28MB，V2 签名）。签名环境变量见 TOOLS.md，配置细节与压缩说明见 `docs/ui-and-release-build.md`。

### 后续变更（版本对齐之后）

- **闪退修复 + debug/正式版共存**：见 `docs/sdl-java-layer-sync-fix.md`
- **UI 优化（去标题栏 + 返回退出）+ Release 签名**：见 `docs/ui-and-release-build.md`
- 仅构建 arm64 的脚本：`build_arm64.bat`

## 6. 项目结构要点

- 弹球核心逻辑源码在**根目录 `SpaceCadetPinball/`**（141 个 cpp/h 文件，直接提交、非子模块）。
- `app/src/main/cpp/CMakeLists.txt` 通过相对路径 `../../../../SpaceCadetPinball/` 引用根目录源码。
- native 编译目标：`SpaceCadetPinball`（SHARED），链接 `SDL2` + `SDL2_mixer` + `log`。
- manifest：包名 `com.fexed.spacecadetpinball`，权限仅 VIBRATE + INTERNET，3 个 Activity（MainActivity / LeaderboardActivity / Settings）。

## 7. 环境备忘

- **PowerShell 不支持 `&&`**：多命令用分号或单独执行。
- **git fetch/merge 的 stderr 会让 PowerShell 报 NativeCommandError**，实际可能成功。
- **GitHub HTTPS 被墙**：clone/子模块一律走 SSH（`git@github.com:...`）。
- JDK：`D:\dev\AndroidStudio\jbr`（OpenJDK 21）；SDK：`D:\dev\android_sdk`；Gradle 缓存：`D:\dev\.gradle`（Gradle 9.4.1 已缓存）。

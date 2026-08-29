# 预编译 .so 提交（jniLibs 方案）

## 目的

让仓库 **clone 下来即可直接打包 APK**，无需 NDK、无需拉取 SDL/SDL_mixer submodule，也无需编译 native 代码。

## 方案：jniLibs 预编译 .so

把 release 构建产出的 3 个 stripped `.so` 直接提交进 git，构建时由 AGP 从 `jniLibs` 打包进 APK，跳过 native 编译。

### 涉及的 .so（arm64-v8a）

| 文件 | 大小 | 来源 |
|------|------|------|
| `libSDL2.so` | 1413 KB | SDL 2.30.12 编译产物 |
| `libSDL2_mixer.so` | 69 KB | SDL_mixer 2.0.4 编译产物 |
| `libSpaceCadetPinball.so` | 583 KB | 游戏核心（根目录 SpaceCadetPinball/）编译产物 |

存放路径：`app/src/main/jniLibs/arm64-v8a/`

### 关键改动（`app/build.gradle`）

1. **新增 sourceSets**，声明 jniLibs 目录（其实 AGP 默认就认 `src/main/jniLibs`，这里显式声明便于理解）：
```groovy
sourceSets {
    main {
        jniLibs.srcDirs = ['src/main/jniLibs']
    }
}
```

2. **注释掉 `externalNativeBuild`**，禁用 native 自动编译：
```groovy
// 已改用预编译 .so（jniLibs），注释掉 externalNativeBuild 以跳过 native 编译，
// 使 clone 后无需 NDK / 无需拉取 SDL submodule 即可直接 assembleRelease 打包 APK。
// 如需重新编译 native，取消注释以下块并恢复 NDK + SDL/SDL_mixer submodule。
//externalNativeBuild {
//    cmake {
//        path file('src/main/cpp/CMakeLists.txt')
//        version '3.22.1'
//    }
//}
```

## 为什么能跳过 native 编译

- **SDL Java 层源码**（`app/src/main/java/org/libsdl/app/*.java`，9 个文件）已直接提交进仓库，不依赖 submodule。
- **`.so` 二进制**已提交进 `jniLibs`，AGP 打包时直接复用。
- **`SpaceCadetPinball/`**（游戏核心源码）仍在仓库根目录，但只有重新编译 native 时才需要。

## clone 后构建步骤

```powershell
git clone git@github.com:pisces312/Pinball-on-Android.git
cd Pinball-on-Android
# 无需 git submodule update，无需 NDK
# 签名需要环境变量 KEY_STORE / KEY_ALIAS / KEY_PASSWORD / KEY_STORE_PASSWORD
.\gradlew.bat assembleRelease
```

产物：`app\build\outputs\apk\release\app-release.apk`

## 如需重新编译 native（可选）

1. 取消注释 `externalNativeBuild` 块
2. 恢复 submodule：`git submodule update --init --recursive`（SDL + SDL_mixer，SSH 地址，被墙时需改 HTTPS）
3. 安装 NDK（当前用 NDK 27，与 `minSdk 21` 匹配）
4. 重新 `assembleRelease`，再用新的 stripped `.so` 覆盖 `jniLibs/arm64-v8a/`

## 注意

- 当前仅提交 **arm64-v8a** 单架构 `.so`（`defaultConfig.abiFilters 'arm64-v8a'`）。如需支持其他 ABI，需为每个 ABI 编译并提交对应 `.so`。
- `.so` 是 release 的 stripped 版本（已去除调试符号），体积最小。

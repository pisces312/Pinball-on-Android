# SDL Java 层同步 2.30 后的两个回归修复

## 背景

版本对齐阶段（commit `80d866b`）为修复 NDK 28 下 `ALooper_pollAll` 被弃用的编译错误，将 native 子模块 SDL 从 2.0.22 升级到 2.30.12。

随后为解决闪退（旧版 Java 层缺 `nativeGetVersion()`、有已移除的 `nativeSetComposingText`，JNI 签名不匹配导致 `UnsatisfiedLinkError` 被静默吞掉），用 SDL 2.30 官方 Java 层覆盖了捆绑的 7 个文件（commit `7ca6207`）。

**但 fexed 原作者对 SDL Java 层做过 4 处定制适配（针对竖屏手机），同步官方版时被全部覆盖丢失，引入两个回归：**

1. **布局变化**（积分牌没吸顶、台面整体居中）
2. **ANR 无响应**（系统提示"没有反应要关闭"）

## 根因

### 定制 1：`SDLSurface.surfaceChanged` 竖屏加宽 hack（布局问题）

fexed 在 `surfaceChanged()` 里加了：

```java
if (width < height) {
    width = (int) Math.floor(width * 1.65);
    //setTranslationY((float) (height * 0.2));
} else {
    setTranslationY(0);
}
```

作用：游戏台面是按横屏（800×556）设计的，竖屏手机下把逻辑宽度乘 1.65，让台面在竖屏下正确缩放填充。

丢失后：SDL 用原始竖屏尺寸计算 `DestinationRect`，`fullscrn.cpp` 里的 `OffsetX/OffsetY` 把整张纹理（含积分牌）居中，导致积分牌不再吸顶。

### 定制 2：`SDLActivity.setOrientation` 空实现（ANR 问题）

fexed 把 `setOrientation()` 改成：

```java
public static void setOrientation(int w, int h, boolean resizable, String hint) {
    // do nothing to prevent orientation change
}
```

作用：阻止 SDL 在窗口创建/设置 resizable 时调用 `setOrientationBis` 自动 `setRequestedOrientation` 旋转 Activity。fexed 用 `configChanges="keyboard|keyboardHidden|orientation|screenSize"` 自己处理旋转。

丢失后：stock 2.30 的 `setOrientationBis` 会根据窗口尺寸（800×556 横屏比例）把 Activity 强制设为 `SCREEN_ORIENTATION_SENSOR_LANDSCAPE`，与 AndroidManifest 的 configChanges 处理产生旋转/resize 循环，触发 ANR。

### 定制 3、4（影响小，未恢复）

- `SDLActivity.loadLibraries`：静默吞 `UnsatisfiedLinkError`（本次升级后 stock 2.30 已改为 `SDL.loadLibrary(lib, this)` 带错误处理，无需恢复）
- `HIDDeviceManager`：注释掉蓝牙相关代码（禁用 Steam Controller BLE，本应用用不到）

## 修复

把定制 1、2 移植回 SDL 2.30：

1. `app/src/main/java/org/libsdl/app/SDLSurface.java` — `surfaceChanged()` 恢复竖屏加宽 hack
2. `app/src/main/java/org/libsdl/app/SDLActivity.java` — `setOrientation()` 恢复空实现

## 验证

- `.\gradlew.bat assembleDebug --no-daemon` → BUILD SUCCESSFUL
- 产物 `app-debug.apk` 30.11MB（arm64-v8a）

## 教训

- **升级第三方库（尤其带 Java 层的 SDL）时，必须先 diff 出原项目对该库的所有定制改动，再决定是否保留。** 本次 `git show c03e19d:...SDLActivity.java` 与 stock 2.0.22 对比，发现 4 处定制，其中 2 处是核心功能。
- SDL 官方 Java 层（`android-project/app/src/main/java/org/libsdl/app/`）随版本变化，同步时需逐文件比对 fexed 定制点。

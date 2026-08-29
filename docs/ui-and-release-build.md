# UI 优化与 Release 签名构建

## 本次改动（commit 后记录）

### 1. 设置/排行榜去除固定标题栏

**问题**：进入设置后上下滚动，游戏英文名"Space Cadet Pinball"那一行固定在顶端遮住部分界面。

**根因**：`themes.xml` 的 parent 是 `Theme.MaterialComponents.DayNight.DarkActionBar`（带 ActionBar）。`Settings` 和 `LeaderboardActivity` 都继承 `AppCompatActivity`，顶部渲染固定 ActionBar 标题，且不属于 ScrollView，滚动时一直吸顶。

**修复**：
- `themes.xml` 新增 `Theme.SpaceCadetPinball.NoActionBar`（继承现有主题，`windowActionBar=false` + `windowNoTitle=true`）
- `AndroidManifest.xml` 给 `Settings` 和 `LeaderboardActivity` 两个 activity 加 `android:theme="@style/Theme.SpaceCadetPinball.NoActionBar"`

`MainActivity`（SDL 全屏游戏）不动，本身全屏无标题栏。

### 2. 返回键退出确认

**问题**：游戏中按返回键无法退出。

**根因**：游戏用 SDL 沉浸式粘滞模式（IMMERSIVE_STICKY），首次按返回键被系统拦截用于退出沉浸模式、显示导航栏，Activity 收不到真正的返回事件；`SDLActivity.onBackPressed()` 默认直接 `super.onBackPressed()` 退出，无确认。

**修复**：`MainActivity` 覆写 `onBackPressed()`，弹 `AlertDialog` 确认框（Quit game? / Quit / Cancel），点 Quit 才调 `super.onBackPressed()` 走 SDL 清理流程（`onDestroy` → `nativeQuit()`）。

**坑（targetSdk 36 预测性返回）**：Android 13+ 预测性返回（predictive back）在 targetSdk 33+ 默认启用，系统不再调用 `onBackPressed()`，导致确认框根本不触发、返回键直接走系统 finish 回桌面。修复：`AndroidManifest.xml` 的 `<application>` 加 `android:enableOnBackInvokedCallback="false"` 关闭预测性返回，恢复 `onBackPressed()` 路径。

### 3. Release 签名构建（不开混淆）

**配置**（`app/build.gradle`）：
```groovy
signingConfigs {
    release {
        storeFile file(System.getenv('KEY_STORE'))
        storePassword System.getenv('KEY_STORE_PASSWORD')
        keyAlias System.getenv('KEY_ALIAS')
        keyPassword System.getenv('KEY_PASSWORD')
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled false       // 不开混淆
        shrinkResources false     // 不做资源压缩
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

**签名环境变量**（来自 TOOLS.md 约定）：
- `KEY_STORE` = `D:\my-projects\my-backup\backup-settings\my-android-release.keystore`
- `KEY_ALIAS` = `pisces312`
- `KEY_PASSWORD` / `KEY_STORE_PASSWORD`（已设）

**构建命令**：
```powershell
.\gradlew.bat assembleRelease --no-daemon
```

**产物**：`app\build\outputs\apk\release\app-release.apk`（28.2MB，arm64-v8a，V2 签名，CN=pisces312）

**验证签名**：
```powershell
apksigner verify --print-certs app\build\outputs\apk\release\app-release.apk
```

## 关于压缩/混淆的说明

- **默认不混淆**：`minifyEnabled false` + `shrinkResources false`。游戏是 native（SDL + C++ 弹球核心），Java 层只有 UI 壳，混淆收益小且可能破坏 SDL JNI 回调（`onNativeKeyDown` 等 native 方法映射），故保持关闭。
- 如需开启混淆，需在 `proguard-rules.pro` 为 `org.libsdl.app.*` 和 `com.fexed.spacecadetpinball` 的 native 方法加 keep 规则，收益有限，暂不推荐。

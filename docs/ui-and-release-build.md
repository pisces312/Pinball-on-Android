# UI 优化与 Release 签名构建

## 本次改动（commit 后记录）

### 1. 设置/排行榜去除固定标题栏

**问题**：进入设置后上下滚动，游戏英文名"Space Cadet Pinball"那一行固定在顶端遮住部分界面。

**根因**：`themes.xml` 的 parent 是 `Theme.MaterialComponents.DayNight.DarkActionBar`（带 ActionBar）。`Settings` 和 `LeaderboardActivity` 都继承 `AppCompatActivity`，顶部渲染固定 ActionBar 标题，且不属于 ScrollView，滚动时一直吸顶。

**修复**：
- `themes.xml` 新增 `Theme.SpaceCadetPinball.NoActionBar`（继承现有主题，`windowActionBar=false` + `windowNoTitle=true`）
- `AndroidManifest.xml` 给 `Settings` 和 `LeaderboardActivity` 两个 activity 加 `android:theme="@style/Theme.SpaceCadetPinball.NoActionBar"`

`MainActivity`（SDL 全屏游戏）不动，本身全屏无标题栏。

### 2. Release 签名构建（不开混淆）

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

## 返回键退出（已撤销）

曾尝试为返回键加退出确认框，但遇到两个问题均失败后**整体撤销**：

1. **targetSdk 36 预测性返回（predictive back）**：Android 13+ 默认启用，系统不再调用 `onBackPressed()`，导致确认框不触发、返回键直接 finish 回桌面。
2. **沉浸式粘滞模式（IMMERSIVE_STICKY）**：关闭 predictive back 后暴露 sticky 模式特性——第一次按返回只显示系统栏（系统拦截、不派发事件），系统栏几秒后自动重隐，永远走不到 `onBackPressed`；改成非 sticky `IMMERSIVE` 后仍无法触发。

**最终决定**：保持 SDL 默认行为（返回键直接回桌面），不额外处理返回键。相关改动（`onBackPressed` 覆写、`enableOnBackInvokedCallback=false`、`IMMERSIVE` 改动）已全部还原。

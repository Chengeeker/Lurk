# Lurk 开发说明

仓库根目录是 Android Gradle 工程。应用源码和资源位于 [app/src/main](app/src/main)，宿主测试位于 [app/src/test](app/src/test)。

## 构建与检查

安装 JDK 17 和 Android SDK 37.2。在 Android Studio 打开仓库根目录，或在本地通过 `local.properties` 设置 `sdk.dir`。

```powershell
.\gradlew.bat :app:testDebugUnitTest :app:lintRelease :app:assembleRelease
```

Release APK 生成在 `app/build/outputs/apk/release/`。发行构建只包含 `arm64-v8a`。本地 Release 使用机器上的默认调试签名配置，覆盖安装时签名必须与已安装版本一致。

## 维护

- 版本号和 Android SDK 配置以 [app/build.gradle.kts](app/build.gradle.kts) 为准。
- 更新存储或备份格式时保留旧数据读取路径，并验证失败回滚。
- 宿主测试覆盖部分协议、状态和界面逻辑。播放、系统手势、图形性能和账号相关流程需要真机验证。
- APK、签名文件、SDK 路径、日志、构建缓存及本地回退材料不纳入 Git。

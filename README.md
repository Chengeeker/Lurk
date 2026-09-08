<div align="center">

# 🌌 Lurk

**一款基于 Flutter 打造的现代化、极简的主题论坛与网络社区浏览应用**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Material You](https://img.shields.io/badge/Material%20Design-3.0-7B1FA2?logo=material-design&logoColor=white)](https://m3.material.io/)
[![Platform](https://img.shields.io/badge/Platform-Android%20(arm64--v8a)-3DDC84?logo=android&logoColor=white)](https://github.com/Chengeeker/Lurk)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*专为追求极致流畅体验与沉浸阅读质感的移动端用户精心雕琢。*

---

</div>

## 🌟 核心特性与设计亮点

### 📖 1. 纯净极简，专注内容阅读
- **高效图文浏览**：直连底层数据服务，精简视觉层级，专注于图文内容本身，提供清爽整洁的讨论阅读环境。
- **智能聚合信息流**：涵盖热门推荐、关注版块动态流与全站热门内容，搭配智能平滑预加载机制，消除滑动等待的卡顿感。
- **无图纯文本模式**：使用习惯支持开启无图模式，卡片自动跳过媒体缩略图与额外留白，不留任何占位空隙，享受极简纯文本瀑布流。

### 💬 2. 深度论坛交互与讨论体系
- **多层级楼层与嵌套展开**：完整支持主题贴详情、楼层正文、楼中楼嵌套回复树状查看与分页加载，畅享畅快讨论。
- **自由看帖视图**：支持“只看楼主”、“倒序浏览”、“按发布时间”与“按回复时间”等多种排序视角随心切换。
- **全能社区检索**：推荐页全局搜索解耦为【搜版块】、【搜主题】、【搜用户】三大独立分栏，精准置顶推荐项，贴文支持相关度与新旧时序即时筛选。
- **版块综合主页**：支持版块顶栏自定义分类（精华、热门、综合等）、版块规约弹窗查阅与快捷签到交互。

### 🎨 3. Material Design 3 动态设计与个性化定制
- **悬浮胶囊底栏设计**：遵循现代 MD3 Expressive 规范打造的高拟态胶囊浮动导航栏，兼具大屏单手操控与视觉通透感。
- **动态取色 (Monet Palette)**：完美适配 Android 12+ 动态壁纸取色，应用主题色随系统壁纸实时律动。
- **深色与 OLED 纯黑适配**：提供多款精选主题色，内置针对 OLED/AMOLED 屏幕深度优化的纯黑极致省电模式。
- **全方位使用习惯定制**：支持启动首选页自定义（进版/推荐/消息/我的）、版块默认排序偏好、图片画质按需加载（智能省流/始终高清/无图）、屏幕高刷新率自适应调度等。

### 🛡️ 4. 实用工具与隐私安全管理
- **应用内置浏览器**：支持配置“使用内置浏览器打开所有链接”，集成动态标题获取、加载进度指示、刷新、链接复制与系统浏览器唤醒。
- **双栏足迹记录**：浏览历史划分为【帖子记录】与【经过版块】，智能排重记录访问轨迹，支持单独清空管理，更提供无痕浏览模式开关。
- **收藏双向排序**：收藏夹支持【倒序预览】（最新收藏在前）与【顺序预览】（最早收藏在前）一键切换。
- **账号授权凭据管理**：支持一键导出并复制登录令牌与完整 Cookie 凭据，提供在线安全有效性实时检测功能。

---

## 🛠️ 技术架构与工程实现

本项目采用现代 Flutter 响应式架构分层设计：

- **Core Framework**: Flutter 3.x (Channel stable) + Dart 3.x
- **State Management**: [Riverpod 2.x](https://riverpod.dev/) (结合 `StateNotifier` 与 `family` 构建声明式响应状态流)
- **Network Engine**: [Dio](https://pub.dev/packages/dio) (集成参数自动签名拦截器、防御性单次重试保护与 Cookie 凭据持久化)
- **Image Caching & Media**: [ExtendedImage](https://pub.dev/packages/extended_image) (高品质内存及磁盘多级缓存、多点手势画廊、媒体相册保存)
- **Web Navigation**: [WebView Flutter](https://pub.dev/packages/webview_flutter) + [url_launcher](https://pub.dev/packages/url_launcher)
- **Local Storage**: [SharedPreferences](https://pub.dev/packages/shared_preferences) 高性能键值对存储，管理自定义屏蔽规则与使用习惯配置

详细的协议逆向细节、历史问题复盘与接口避坑指南，请查阅 [🛠️ 开发者文档与协议避坑指南](DEVELOPMENT.md)。

---

## 📄 免责声明

1. 本项目为开源个人作品，仅供个人学习、技术研究与编程交流使用。
2. 本项目不含任何商业盈利行为，所有网络社区内容、版块图文及相关知识产权均归原作者所有。
3. 请合理使用本项目，遵守相关法律法规及社区守则。

---

## 📜 开源协议

本项目基于 [MIT License](LICENSE) 协议开源。

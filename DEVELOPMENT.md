# 🛠️ Lurk 开发者文档与协议避坑指南

本文档汇集了 Lurk 项目在接入百度贴吧底层数据协议、客户端逆向分析、网络鉴权以及状态流转中**踩过的重大技术深坑、错误根因分析与对应的最终解决方案**。供后续维护与二次开发时查阅参考，避免重复踩坑。

---

## 目录
- [一、贴吧接口开发避坑与错误复盘](#一贴吧接口开发避坑与错误复盘)
  - [1. 取消关注贴吧提示“用户未登录”的路由命名陷阱](#1-取消关注贴吧提示用户未登录的路由命名陷阱)
  - [2. 发表回复/评论“发送失败或假成功不可见”的协议陷阱](#2-发表回复评论发送失败或假成功不可见的协议陷阱)
  - [3. 楼层与楼中楼评论删除逻辑与参数差异](#3-楼层与楼中楼评论删除逻辑与参数差异)
  - [4. 贴吧 FID 解析缺失与进吧状态机竞态](#4-贴吧-fid-解析缺失与进吧状态机竞态)
  - [5. TBS (防刷票令牌) 匿名污染与移动端权威获取](#5-tbs-防刷票令牌-匿名污染与移动端权威获取)
  - [6. 请求签名（Sign）与凭据字段大小写敏感差异](#6-请求签名sign与凭据字段大小写敏感差异)
  - [7. 贴吧吧规只显示模板标题无正文的接口缺失陷阱](#7-贴吧吧规只显示模板标题无正文的接口缺失陷阱)
  - [8. 帖子收藏纯本地存储与贴吧官方云端同步](#8-帖子收藏纯本地存储与贴吧官方云端同步)
- [二、构建打包与 Git 历史规范](#二构建打包与-git-历史规范)

---

## 一、贴吧接口开发避坑与错误复盘

### 1. 取消关注贴吧提示“用户未登录”的路由命名陷阱

#### ❌ 曾犯错误与问题表象
- **现象**：在贴吧详情页点击“取消关注”时，客户端频繁报错 `{error_code: 1, error_msg: "用户未登录"}`，导致用户无论怎么刷新、重新登录或完成签到，都无法成功取消关注。
- **排查弯路**：初期误以为是用户登录凭据失效、移动端请求未正确携带 Cookie，或 TBS 令牌过期，多次针对登录态进行刷新重试依然无效。

#### 🔍 根因溯源
1. **废弃端点假未登录**：
   - 原代码中定义的贴吧取消关注接口为 `/c/c/forum/unlike`。
   - 百度贴吧官方移动端在迭代中**早已将 `/c/c/forum/unlike` 废弃**。对于该废弃接口，贴吧后端网关统一返回硬编码的 `{error_code: 1, error_msg: "用户未登录"}`，根本不会进入真实的业务逻辑处理。
2. **端点命名不对称**：
   - 贴吧移动端的关注接口为 `/c/c/forum/like`；
   - 而取消关注的真实端点并非直觉上的 `unlike`，而是 **`/c/c/forum/unfavolike`**（由收藏夹取消关注 `unfavo` 演变而来）！

#### ✅ 正确解决方案
1. **修正路由定义**（`TiebaConstants.pathUnlikeForum`）：
   ```dart
   // 错误：static const String pathUnlikeForum = '/c/c/forum/unlike';
   // 正确：
   static const String pathUnlikeForum = '/c/c/forum/unfavolike';
   ```
2. **参数与签名要求**：
   - 请求方式：`POST`，`Content-Type: application/x-www-form-urlencoded`
   - 请求体必须携带：`fid`（贴吧ID）、`tbs`（有效移动端TBS）、`BDUSS`（以及客户端自动注入的 MD5 `sign` 与设备参数）。

---

### 2. 发表回复/评论“发送失败或假成功不可见”的协议陷阱

#### ❌ 曾犯错误与问题表象
- **现象**：调用接口发表评论后，客户端要么收到“发送失败，请检查网络后重试”；要么接口返回成功，但用官方贴吧客户端或网页版打开帖子时，根本看不到刚刚发布的评论（假发布/被服务端静默丢弃）。

#### 🔍 根因溯源
1. **表单接口已被风控拦截**：
   - 传统的表单接口 `POST /c/c/post/add` 随着百度贴吧反爬与风控体系升级，已被降权或封禁。直接使用普通表单 MD5 签名提交中文内容时，极易被识别为非官方客户端，导致静默吞帖或直接报网络异常。
2. **官方客户端全面采用 Protobuf 二进制协议**：
   - 贴吧官方客户端所有发帖、回帖、楼中楼写操作均已重构为 Google Protocol Buffers 二进制传输格式（`AddPostReqIdl` / `AddPostResponse`）。

#### ✅ 正确解决方案
1. **接入 Protobuf 序列化协议**：
   - 实现了 [add_post_protobuf.dart](file:///d:/App/Lurk/lib/features/detail/data/protobuf/add_post_protobuf.dart)，负责将帖子内容结构化为二进制流。
2. **设置专门的 Protobuf 请求头**：
   ```dart
   final options = Options(
     contentType: 'application/x-www-form-urlencoded',
     headers: {
       'x_bd_data_type': 'protobuf', // 告知网关按 Protobuf 处理
     },
     extra: {
       'skip_sign': true, // Protobuf 请求由其内部结构保障，跳过外层常规 MD5 签名
     },
   );
   ```
3. **内容体层级映射**：
   - 针对文本内容、艾特用户（At）、贴吧原生表情（Emoji），分别构造 `type: 0/1/2` 对应的二进制结构切片，确保全平台展现完全一致且不被风控丢弃。

---

### 3. 楼层与楼中楼评论删除逻辑与参数差异

#### ❌ 曾犯错误与问题表象
- **现象**：支持了发帖回帖后，无法删除刚刚发布的评论，或删除主楼层回复与删除楼中楼回复混用同一套参数导致报错。

#### 🔍 根因溯源
- 贴吧服务端对“楼层回复（Post）”与“楼中楼（SubPost/Comment）”在删除时有着严格区分：
  - **主楼层回复**：仅有 `pid`（Post ID）；
  - **楼中楼子回复**：同时具有所属楼层的 `pid` 以及当前子回复的 `spid`（Sub-Post ID）。如果删除楼中楼时未传递 `spid` 或参数命名不符，服务端会拒绝操作。

#### ✅ 正确解决方案
- 在 `DetailRepository.deletePost` 中规范化区分：
  ```dart
  final data = {
    'fid': forumId,
    'z': threadId,
    'pid': postId,
    if (subPostId != null && subPostId.isNotEmpty) 'spid': subPostId,
    'tbs': tbs,
  };
  ```
- 配合 UI 层长按提供操作项，并在删除成功后精确移除对应的数据模型节点。

---

### 4. 贴吧 FID 解析缺失与进吧状态机竞态

#### ❌ 曾犯错误与问题表象
- **现象 1**：刚点进贴吧，如果在数据尚未加载完毕时快速点击右上角菜单的“取消关注”或“关注”，操作无反应或报错失败。
- **现象 2**：进入未关注贴吧时顶部仍显示“签到”；点击签到失败；关注与已关注状态错乱。

#### 🔍 根因溯源
1. **FID 依赖未加载完成的状态**：
   - 贴吧操作严格依赖数字型的 `fid`（例如 21841105），如果用户直接进吧，在 `getForumPage` 请求回包前，`state.forum.id` 处于默认值 `'0'` 或空，此时发起的取关/关注操作无法定位吧。
2. **状态机缺失**：
   - 原先没有严格区分贴吧的生命周期阶段，导致已关注、未关注、已签到状态混淆。

#### ✅ 正确解决方案
1. **构建贴吧头部三态状态机**：
   - `!isLiked`（未关注） $\rightarrow$ 显示「+ 关注」按钮，点击关注后切换为签到；
   - `isLiked && !isSigned`（已关注未签到） $\rightarrow$ 显示「签到」按钮，点击触发签到；
   - `isLiked && isSigned`（已关注且已签到） $\rightarrow$ 显示置灰的「已签到」按钮。
2. **多层 FID 自动反查兜底机制**：
   - 第一级：从 `currentForum.id` 获取；
   - 第二级：若为 `'0'`，从用户已关注贴吧缓存列表（`myForums`）中按吧名反查；
   - 第三级：从仓库内部的 `_forumIdCache` 获取；
   - 第四级：若均为空，在执行前自动轻量请求一次 `getForumPage(page: 1)` 解析真实 `fid` 并回填缓存。

---

### 5. TBS (防刷票令牌) 匿名污染与移动端权威获取

#### ❌ 曾犯错误与问题表象
- **现象**：偶尔发生关注或发帖提示 TBS 错误，或者在刷新 TBS 时拿到了未登录状态下的游客 TBS，导致后续需要登录态的操作全部失效。

#### 🔍 根因溯源
- 贴吧获取 TBS 的接口有两条途径：
  1. Web 端接口 `https://tieba.baidu.com/dc/common/tbs`：返回 `{tbs: "...", is_login: 0/1}`。若在此接口中 Cookie 携带不完整，会返回匿名 TBS（`is_login: 0`）。若直接把匿名 TBS 当作已登录 TBS 使用，会导致所有写操作全部被拒。
  2. 移动端原生 `/c/s/login` 接口：返回 `anti.tbs`，属于官方移动端强校验的权威令牌。

#### ✅ 正确解决方案
- 在 `AuthProvider.getValidTbs` 中实现双保险策略：
  1. **首选移动端**：优先调用移动端原生 `/c/s/login` 刷新，提取 `anti.tbs`；
  2. **兜底 Web 端校验**：若使用 Web 接口刷新，**必须严格校验 `is_login == 1`**，若 `is_login != 1` 坚决丢弃，防止匿名 TBS 污染有效登录态；
  3. **失效自动重试**：在发帖、关注、取关时，若回包包含“tbs”或“未登录”字样，自动触发 `forceRefresh: true` 刷新一次 TBS 并重试请求。

---

### 6. 请求签名（Sign）与凭据字段大小写敏感差异

#### ❌ 曾犯错误与问题表象
- **现象**：在某些特定接口（如个人主页、取关接口）中，明明登录成功且带了 BDUSS，贴吧服务端仍然偶尔提示缺少登录凭据。

#### 🔍 根因溯源
- 贴吧服务端历史包袱沉重，不同时期的接口对凭据字段名称要求不一致：
  - 部分旧接口读取小写的 `bduss`；
  - 部分接口校验全大写的 `BDUSS`；
  - 还有接口要求 `bdusstoken` 与 `stoken`；
  - 请求头还需携带标准格式的 `Cookie: ka=open; BDUSS=...; STOKEN=...; BAIDUID=...`。

#### ✅ 正确解决方案
- 在 `TiebaDioClient` 请求拦截器中执行**多键值共存注入**：
  ```dart
  if (options.data is Map) {
    final map = options.data as Map;
    map.putIfAbsent('BDUSS', () => account.bduss);
    map.putIfAbsent('bduss', () => account.bduss);
    map.putIfAbsent('bdusstoken', () => account.bduss);
    map.putIfAbsent('stoken', () => account.stoken);
  }
  ```
  这样无论目标服务端读取哪个字段名，均能完美匹配。

---

### 7. 贴吧吧规只显示模板标题无正文的接口缺失陷阱

#### ❌ 曾犯错误与问题表象
- **现象**：进入贴吧后，点击贴吧顶部的“吧规”条目，弹出的对话框中仅仅只有一段简短且模板化的标题（例如“1月12日更新 发帖必读”），没有任何正文规则条款内容，看似只是空壳。
- **排查弯路**：初期以为贴吧进吧主接口 `/c/f/frs/page` 中的 `forum_rule` 对象包含了完整吧规，直接把 `forum_rule['title']` 拿来当作吧规正文展示。

#### 🔍 根因溯源
1. **聚合接口仅下发简略公告**：
   - `/c/f/frs/page` 响应中的 `forum_rule` 仅是一个精简摘要标识，用于在贴吧顶部常驻一条微型提示栏（公告条），其内部只有 `title` 和 `has_forum_rule`，**绝不包含**吧务委员会定制的数十条详尽吧规条款。
2. **官方独立吧规详情接口**：
   - 官方移动端在用户点击吧规栏后，会向独立端点发起请求：
     `POST /c/f/forum/forumRuleDetail`
     参数携带 `forum_id`；
   - 该接口会返回结构化完整的规则数据：
     - `title`：吧规正式全称（如“抗压背锅吧吧规”）；
     - `preface`：吧主引言/前言（如交流导向、吧风指引）；
     - `rules` / `new_rules` / `default_rules`：规则条款清单，每条具备 `title`（如“一、禁违法信息”）与多段细则 `content`（禁言、删帖细则）；
     - `publish_time`、`bazhu`：发布时间与吧主信息。

#### ✅ 正确解决方案
1. **补齐专属接口定义**（`TiebaConstants.pathForumRuleDetail`）：
   ```dart
   static const String pathForumRuleDetail = '/c/f/forum/forumRuleDetail';
   ```
2. **设计完备的数据模型与提取器**（`ForumRuleDetailModel` 与 `ForumRuleItemModel`）：
   递归提取 `content` / `content_list` 中的多段文本与条款标题。
3. **重构交互与展现层**（`_showRuleDetailBottomSheet`）：
   将原有简陋的 `AlertDialog` 升级为 Material 3 风格的抽屉式 `DraggableScrollableSheet`，支持异步拉取与优雅加载中态、吧主发布人与更新时间元信息、高亮前言引用卡片、分段条款列表以及无规则时的优雅空状态。

---

### 8. 帖子收藏纯本地存储与贴吧官方云端同步

#### ❌ 曾犯错误与问题表象
- **现象**：“我的收藏”原本仅通过 `SharedPreferences` 本地存储 JSON 字符串，无法与百度贴吧账号在其他设备或官方 App 上的收藏记录互通。用户重新登录、换机或清理数据后，收藏即永久丢失。

#### 🔍 根因溯源
- 贴吧官方移动端拥有独立的云端收藏体系（`ThreadStore`），具备分页拉取、添加收藏、取消收藏等一系列原生移动网关：
  - 获取收藏列表：`POST /c/f/post/threadstore`，参数为 `rn`（分页大小）、`offset`（分页偏移）、`user_id`；
  - 添加收藏：`POST /c/c/post/addstore`，参数为 `data: jsonEncode([{'pid': postId, 'tid': threadId, 'status': '0', 'type': '0'}])` 与 `tbs`；
  - 取消收藏：`POST /c/c/post/rmstore`，参数为 `tid: threadId` 与 `tbs`。

#### ✅ 正确解决方案
1. **建立专属 `BookmarksRepository` 数据仓储**：
   - 实现 `getOfficialBookmarks`、`addOfficialBookmark`、`removeOfficialBookmark`；
   - 保留 `getLocalBookmarks`、`saveLocalBookmark`、`removeLocalBookmark` 本地离线缓存与 `syncOfficialToLocal` 双向自动合并策略。
2. **在“我的收藏”页面实现无缝降级与云端分页加载**：
   - 未登录时：以优雅的本地缓存模式运行，并提供登录引导与顺序/倒序切换；
   - 已登录时：自动拉取百度贴吧云端收藏，集成 `EasyRefresh` 支持下拉刷新与上拉分页加载，滑动删除时同步向贴吧云端发送 `rmstore` 请求。
3. **在“帖子详情页”收藏按钮打通双向联动**：
   - 点击收藏按钮时，登录状态下自动获取移动端有效 `tbs` 并调用 `addstore` / `rmstore`，同时同步本地缓存，让状态切换即时响应并在重新离线时依旧有效。

---

## 二、构建打包与 Git 历史规范

### 1. 自动化构建与产物归档
- 项目根目录下维护了 [build_apk.ps1](file:///d:/App/Lurk/build_apk.ps1) 脚本：
  - 自动从 `pubspec.yaml` 中提取版本号（如 `1.4.0+5` $\rightarrow$ `1.4`）；
  - 自动清理旧版 APK 垃圾文件；
  - 执行 Release 构建：`flutter build apk --target-platform android-arm64 --release --no-tree-shake-icons`；
  - 复制产物到根目录为命名规范的安装包，如 `Lurk-v1.4.apk`。

### 2. Git 提交历史纯净推送规范
- **原则**：根据交付要求，推送到 GitHub 时需清除之前的调试历史，仅保留干净的单一提交。
- **操作步骤**：
  ```powershell
  # 1. 建立无历史的孤儿分支
  git checkout --orphan temp_branch
  # 2. 暂存所有工作区修改
  git add -A
  # 3. 提交单一初始提交
  git commit -m "Initial commit"
  # 4. 删除本地原 main 分支并重命名孤儿分支为 main
  git branch -D main
  git branch -m main
  # 5. 强推至远程覆盖所有历史记录
  git push -f origin main
  ```

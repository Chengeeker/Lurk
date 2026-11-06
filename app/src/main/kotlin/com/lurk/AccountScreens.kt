package com.lurk

import android.annotation.SuppressLint
import android.content.Intent
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import android.net.Uri
import android.webkit.*
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import coil.compose.AsyncImage
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import kotlinx.coroutines.delay
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

@Composable
fun ProfileScreen(uid: String, back: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current
    var profile by pageState("profile") { JSONObject() }
    Column {
        val user = profile.obj("user")
        val author = Author.parse(user)
        val gallery = LocalMedia.current
        val colors = MaterialTheme.colorScheme
        PageBar(author.name, back, titleSize = 16.sp, titleWeight = FontWeight.Bold)
        if (uid.isEmpty()) LoginPrompt() else PagedContent(identity = uid, emptyMessage = "暂无发帖记录", load = { page ->
            if (page == 1) profile = model.api.post("/c/u/user/profile", mapOf("uid" to uid, "need_post_count" to "1"))
            val j = model.api.post("/c/u/feed/userpost", mapOf("uid" to uid, "pn" to "$page", "rn" to "20", "is_thread" to "1", "need_content" to "1"))
            model.api.threads(j, "post_list") to (j.rows("post_list").size >= 20)
        }, header = {
            Card(Modifier.fillMaxWidth().padding(start = 14.dp, top = 10.dp, end = 14.dp, bottom = 8.dp), shape = RoundedCornerShape(24.dp), colors = CardDefaults.cardColors(containerColor = colors.surfaceContainerLow)) {
            Column(Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.Top) {
                    OriginalAvatar(portraitUrl(author.portrait), "${author.name}的头像", Modifier.size(68.dp).clip(CircleShape).feedbackClickable { if (author.portrait.isNotEmpty()) gallery(listOf(Media(portraitUrl(author.portrait), folderName = author.name)), 0) }); Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) { Text(author.name, Modifier.weight(1f, false), fontSize = 18.sp, fontWeight = FontWeight.Bold, maxLines = 1); if (author.level.isNotEmpty()) LevelBadge(author.level, profile = true) }
                        Spacer(Modifier.height(4.dp)); if (author.ip.isNotEmpty()) Text("IP 属地：${author.ip}", Modifier.padding(bottom = 2.dp), fontSize = 12.sp, color = colors.outline)
                        if (user.s("name").isNotEmpty() && user.s("name") != author.name) Text("贴吧账号：${user.s("name")}", Modifier.padding(bottom = 2.dp), fontSize = 12.sp, color = colors.outline)
                        if (uid != "0") Text("UID: $uid", fontSize = 12.sp, color = colors.outline)
                    }
                    val following = user.flag("has_concerned") || user.flag("has_concern") || user.flag("is_follow")
                    if (uid != model.account?.uid) Surface(shape = RoundedCornerShape(20.dp), color = if (following) colors.surfaceContainerHighest else colors.primary, border = if (following) BorderStroke(1.dp, colors.outlineVariant.copy(alpha = .4f)) else null, enabled = !model.writing, onClick = tapFeedback { model.action { api, _ ->
                        api.write(if (following) "/c/c/user/unfollow" else "/c/c/user/follow", mapOf("portrait" to user.s("portrait")))
                        profile = JSONObject(profile.toString()).put("user", JSONObject(user.toString()).put("has_concerned", if (following) 0 else 1).put("has_concern", if (following) 0 else 1).put("is_follow", if (following) 0 else 1))
                    } }) { Row(Modifier.padding(horizontal = 14.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) { val tint = if (following) colors.onSurfaceVariant else colors.onPrimary; if (model.writing) CircularProgressIndicator(Modifier.size(15.dp), color = tint, strokeWidth = 2.dp) else Icon(if (following) Icons.Rounded.Check else Icons.Rounded.Add, null, Modifier.size(15.dp), tint = tint); Spacer(Modifier.width(3.dp)); Text(if (following) "已关注" else "关注", fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = tint) } }
                }
                if (user.s("intro").isNotEmpty()) Text(plainText(user.s("intro")), Modifier.padding(top = 12.dp), fontSize = 13.sp, lineHeight = 1.45.em, color = colors.onSurfaceVariant)
                Spacer(Modifier.height(14.dp))
                Row(Modifier.fillMaxWidth().background(colors.surfaceContainer, RoundedCornerShape(14.dp)).padding(horizontal = 8.dp, vertical = 10.dp)) {
                    val stats = listOf("关注" to user.s("concern_num").ifEmpty { "0" }, "粉丝" to user.s("fans_num").ifEmpty { "0" }, "发帖" to user.s("post_num").ifEmpty { "0" }) + if ((user.s("tb_age").toIntOrNull() ?: 0) > 0) listOf("吧龄" to "${user.s("tb_age")}年") else emptyList()
                    stats.forEach { (label, value) -> Column(Modifier.weight(1f).feedbackClickable(enabled = uid == model.account?.uid && label == "关注") { open(Route("list", uid, "follow")) }, horizontalAlignment = Alignment.CenterHorizontally) { Text(value, fontSize = 16.sp, fontWeight = FontWeight.Bold); Text(label, fontSize = 11.5.sp, color = colors.outline) } }
                }
            }
            }
            Text(if (uid == model.account?.uid) "我的发帖与动态" else "TA 的发帖与动态", Modifier.padding(start = 24.dp, top = 12.dp, end = 24.dp, bottom = 6.dp), fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }) { ThreadCard(it) }
    }
}

@Composable
fun UserListScreen(uid: String, type: String, back: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current
    var remove by remember { mutableStateOf<JSONObject?>(null) }; val removed = remember { mutableStateListOf<String>() }
    Column {
        PageBar(if (type == "fans") "粉丝" else "关注的吧友", back, titleSize = 17.sp, titleWeight = FontWeight.Bold)
        if (uid.isEmpty()) LoginPrompt() else PagedContent(identity = "$uid:$type", emptyMessage = "暂无关注的吧友", topPadding = 6, emptyState = { loading, error, retry ->
            if (loading) CircularProgressIndicator() else Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Rounded.PeopleOutline, null, Modifier.size(56.dp), tint = MaterialTheme.colorScheme.outlineVariant)
                Spacer(Modifier.height(12.dp)); Text(error ?: "暂无关注的吧友", fontSize = 14.sp, color = MaterialTheme.colorScheme.outline)
                if (error != null) TextButton(onClick = tapFeedback(retry)) { Text("重试") }
            }
        }, load = { page ->
            val j = model.api.post("/c/u/$type/page", mapOf("uid" to uid, "pn" to "$page", "rn" to "20"))
            j.rows("user_list") to (j.rows("user_list").size >= 20)
        }) { row ->
            val author = Author.parse(row); val colors = MaterialTheme.colorScheme
            if (author.id !in removed) Card(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 4.dp).feedbackClickable { open(Route("profile", author.id)) }, shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = colors.surfaceContainerLow)) {
                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    OriginalAvatar(portraitUrl(author.portrait), author.name, Modifier.size(44.dp).clip(CircleShape)); Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) { Text(author.name, fontSize = 14.5.sp, fontWeight = FontWeight.Bold, maxLines = 1); if (row.s("intro").isNotEmpty()) Text(plainText(row.s("intro")), Modifier.padding(top = 3.dp), fontSize = 11.5.sp, color = colors.outline, maxLines = 1) }
                    if (uid == model.account?.uid && type == "follow") Row(Modifier.clip(RoundedCornerShape(12.dp)).background(colors.surfaceContainerLow).border(1.dp, colors.outlineVariant.copy(alpha = .4f), RoundedCornerShape(12.dp)).feedbackClickable { remove = row }.padding(horizontal = 10.dp, vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Rounded.Check, null, Modifier.size(13.dp), tint = colors.onSurfaceVariant); Spacer(Modifier.width(2.dp)); Text("已关注", fontSize = 11.5.sp, color = colors.onSurfaceVariant) }
                }
            }
        }
    }
    remove?.let { row -> AlertDialog(onDismissRequest = { remove = null }, title = { Text("取消关注", fontSize = 17.sp, fontWeight = FontWeight.Bold) }, text = { Text("确定取消关注“${Author.parse(row).name}”吗？") }, confirmButton = { FilledTonalButton(onClick = tapFeedback { model.action { api, _ -> require(row.s("portrait").isNotEmpty()) { "无法获取用户头像特征码" }; api.write("/c/c/user/unfollow", mapOf("portrait" to row.s("portrait"))); removed.add(Author.parse(row).id); remove = null; model.message("已取消关注") } }) { Text("取消关注") } }, dismissButton = { TextButton(onClick = tapFeedback { remove = null }) { Text("取消") } }) }
}

@Composable
fun NotificationScreen() {
    val model = LocalState.current; val open = LocalOpen.current
    var tab by rememberSaveable { mutableIntStateOf(0) }
    Column {
        FrostedHeading {
        PageBar("消息通知", titleSize = 17.sp, titleWeight = FontWeight.Bold)
        OriginalTabBar(tab, listOf("回复我的", "@提到我的"), { tab = it })
        }
        OriginalTabs(tab, 2, { tab = it }) { tab -> key(tab) { PagedContent(identity = tab, emptyMessage = if (tab == 0) "暂无回复消息" else "暂无@消息", topPadding = 6,
            emptyState = { loading, error, retry -> NotificationEmptyState(if (tab == 0) "暂无回复消息" else "暂无@消息", loading, error, retry) }, load = { page ->
            if (model.account == null) return@PagedContent emptyList<JSONObject>() to false
            val j = model.api.post(if (tab == 0) "/c/u/feed/replyme" else "/c/u/feed/atme", mapOf("pn" to "$page"))
            val rows = j.rows(if (tab == 0) "reply_list" else "at_list")
            rows to (rows.size >= 20)
        }) { row ->
            val author = Author.parse(row.optJSONObject("replyer") ?: row.optJSONObject("user") ?: row.optJSONObject("author") ?: JSONObject().put("name", row.s("author")).put("id", row.s("author_id")))
            val colors = MaterialTheme.colorScheme
            Card(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 4.dp), shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = LocalOriginalCardColor.current.takeUnless { it == Color.Unspecified } ?: colors.surfaceContainerLow)) {
            Column(Modifier.fillMaxWidth().feedbackClickable { val tid = row.s("thread_id", "tid", "kz"); if (tid.isEmpty() || tid == "0") model.message("未找到关联贴子") else open(Route("thread", tid, row.s("post_id", "pid"))) }.padding(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OriginalAvatar(portraitUrl(author.portrait), "${author.name}的头像", Modifier.size(38.dp).clip(CircleShape).feedbackClickable { open(Route("profile", author.id)) }); Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) { Text(author.name, Modifier.weight(1f, fill = false).feedbackClickable { open(Route("profile", author.id)) }, fontSize = 13.5.sp, fontWeight = FontWeight.Bold, maxLines = 1); if (row.s("fname").isNotEmpty()) Text("${row.s("fname")}吧", Modifier.padding(start = 6.dp).background(colors.surfaceContainerLow, RoundedCornerShape(4.dp)).padding(horizontal = 5.dp, vertical = 1.5.dp), fontSize = 10.sp, color = colors.outline) }
                        val time = relativeTime(row.s("time")); if (time.isNotEmpty()) Text(if (time.endsWith("秒前")) "刚刚" else time, Modifier.padding(top = 2.dp), fontSize = 11.sp, color = colors.outline)
                    }
                    Icon(Icons.Rounded.ChevronRight, null, Modifier.size(18.dp), tint = colors.outline.copy(alpha = .5f))
                }
                Spacer(Modifier.height(8.dp))
                if (row.s("content").isNotEmpty()) Text(plainText(row.s("content")), fontSize = 13.5.sp, lineHeight = 1.4.em)
                if (row.s("quote_content").isNotEmpty()) Text("原内容：${plainText(row.s("quote_content"))}", Modifier.padding(top = 8.dp).fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(colors.surfaceContainer).drawBehind { drawLine(colors.primary.copy(alpha = .6f), Offset.Zero, Offset(0f, size.height), 3.dp.toPx()) }.padding(horizontal = 10.dp, vertical = 6.dp), fontSize = 12.sp, lineHeight = 1.35.em, color = colors.outline, maxLines = 2, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            }
            }
        } } }
    }
}

@Composable
fun LoginScreen(back: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current
    val colors = MaterialTheme.colorScheme
    // Credentials deliberately do not use saved-instance state.
    var cookie by remember { mutableStateOf("") }
    Column {
        PageBar("登录百度账号", back, titleWeight = FontWeight.Bold)
        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp)) {
            Card(colors = CardDefaults.cardColors(containerColor = colors.primaryContainer.copy(alpha = .35f)), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.background(colors.primary, CircleShape).padding(8.dp)) { Icon(Icons.Rounded.Security, null, Modifier.size(20.dp), tint = Color.White) }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) { Text("官方网页快捷登录", fontSize = 16.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.height(2.dp)); Text("支持手机号验证码 / 账号密码 / 扫码登录", fontSize = 12.sp, color = colors.outline) }
                    }
                    Spacer(Modifier.height(16.dp)); Text("安全打开百度官方授权页面，登录成功后自动完成授权并同步账号，无需手动提取 Cookie。", fontSize = 13.sp, lineHeight = 1.4.em, color = colors.onSurfaceVariant)
                    Spacer(Modifier.height(16.dp))
                    Button(onClick = tapFeedback { open(Route("webLogin")) }, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Rounded.OpenInBrowser, null); Spacer(Modifier.width(8.dp)); Text("打开百度官方登录页", fontWeight = FontWeight.Bold) }
                }
            }
            Spacer(Modifier.height(24.dp)); Row(verticalAlignment = Alignment.CenterVertically) { OriginalDivider(Modifier.weight(1f), color = colors.outlineVariant.copy(alpha = .5f)); Text("或通过 Cookie 导入", Modifier.padding(horizontal = 12.dp), fontSize = 12.sp, color = colors.outline); OriginalDivider(Modifier.weight(1f), color = colors.outlineVariant.copy(alpha = .5f)) }
            Spacer(Modifier.height(20.dp)); Text("Cookie / BDUSS 导入", fontSize = 15.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp)); Text("粘贴完整的百度 Cookie 字符串或单独的 BDUSS 即可完成登录。", fontSize = 12.sp, color = colors.outline)
            Spacer(Modifier.height(12.dp))
            TextField(cookie, { cookie = it }, Modifier.fillMaxWidth(), minLines = 4, maxLines = 4, placeholder = { Text("粘贴 BAIDUID=...; BDUSS=...; STOKEN=...") }, shape = RoundedCornerShape(16.dp), colors = TextFieldDefaults.colors(focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent, focusedContainerColor = colors.surfaceContainerHighest, unfocusedContainerColor = colors.surfaceContainerHighest))
            Spacer(Modifier.height(16.dp))
            FilledTonalButton(enabled = !model.writing, onClick = tapFeedback { model.login(cookie) { cookie = ""; back() } }, modifier = Modifier.fillMaxWidth()) { if (model.writing) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp) else Icon(Icons.Rounded.CheckCircleOutline, null); Spacer(Modifier.width(8.dp)); Text(if (model.writing) "正在验证导入..." else "确认导入并登录") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@SuppressLint("SetJavaScriptEnabled")
@Composable
fun BrowserScreen(url: String, login: Boolean, back: () -> Unit, loggedIn: () -> Unit = back) {
    val model = LocalState.current; val context = LocalContext.current
    var view by remember { mutableStateOf<WebView?>(null) }
    var title by remember { mutableStateOf(if (login) "网页登录" else "浏览器") }
    var canBack by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    var menu by remember { mutableStateOf(false) }; var currentUrl by remember { mutableStateOf(url) }
    var lastAttempt by remember { mutableStateOf("") }
    var alive by remember { mutableStateOf(true) }
    fun syncLogin(manual: Boolean = false) {
        if (!login || model.writing) return
        val cookies = CookieManager.getInstance().getCookie("https://tieba.baidu.com").orEmpty()
        if (!Regex("(?:^|;\\s*)BDUSS(?:_BFESS)?=[^;]+").containsMatchIn(cookies)) { if (manual) model.message("未检测到有效登录 Cookie，请在网页中完成登录"); return }
        if (!manual && cookies == lastAttempt) return
        lastAttempt = cookies
        model.login(cookies) { if (alive) loggedIn() }
    }
    LaunchedEffect(login) { if (login) while (true) { delay(2000); syncLogin() } }
    BackHandler(canBack) { view?.goBack() }
    DisposableEffect(Unit) { onDispose { alive = false; view?.apply { stopLoading(); webChromeClient = null; destroy() }; view = null } }
    Column {
        if (login) PageBar("百度账号网页授权", back, titleSize = 16.sp, titleWeight = FontWeight.Bold, actions = { IconButton(onClick = tapFeedback { view?.reload() }) { Icon(Icons.Rounded.Refresh, "重新加载") } })
        else TopAppBar(title = { Column { Text(title.ifEmpty { "网页浏览" }, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis); Text(currentUrl, fontSize = 11.sp, color = MaterialTheme.colorScheme.outline, maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis) } }, navigationIcon = { IconButton(onClick = tapFeedback { if (canBack) view?.goBack() else back() }) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "返回") } }, actions = {
            IconButton(onClick = tapFeedback { view?.reload() }) { Icon(Icons.Rounded.Refresh, "刷新") }
            Box { IconButton(onClick = tapFeedback { menu = true }) { Icon(Icons.Rounded.MoreVert, "更多") }; DropdownMenu(menu, { menu = false }) {
                DropdownMenuItem(text = { Text("复制链接") }, leadingIcon = { Icon(Icons.Rounded.ContentCopy, null, Modifier.size(18.dp)) }, onClick = tapFeedback { menu = false; (context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager).setPrimaryClip(android.content.ClipData.newPlainText("链接", currentUrl)); model.message("链接已复制到剪贴板") })
                DropdownMenuItem(text = { Text("在浏览器中打开") }, leadingIcon = { Icon(Icons.Rounded.OpenInBrowser, null, Modifier.size(18.dp)) }, onClick = tapFeedback { menu = false; runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(currentUrl))) }.onFailure { model.message("没有可用浏览器") } })
            } }
        }, expandedHeight = 56.dp, windowInsets = WindowInsets.statusBars, colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent), modifier = Modifier.frostedTint(MaterialTheme.colorScheme.background, MaterialTheme.colorScheme.outlineVariant))
        if (failed) Row { Text("网页加载失败", Modifier.padding(12.dp)); TextButton(onClick = tapFeedback { failed = false; view?.reload() }) { Text("重试") } }
        Box(Modifier.weight(1f)) {
        AndroidView(modifier = Modifier.fillMaxSize(), factory = { ctx -> WebView(ctx).apply {
            view = this
            settings.javaScriptEnabled = true; settings.domStorageEnabled = true
            settings.allowFileAccess = false; settings.allowContentAccess = false
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            CookieManager.getInstance().setAcceptCookie(true)
            webChromeClient = object : WebChromeClient() {
                override fun onReceivedTitle(v: WebView?, value: String?) { title = value?.take(60).orEmpty() }
                override fun onProgressChanged(v: WebView?, value: Int) { progress = value / 100f }
            }
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(v: WebView?, request: WebResourceRequest?): Boolean {
                    val target = request?.url ?: return true
                    return target.scheme !in listOf("https", "http")
                }
                override fun onPageFinished(v: WebView?, value: String?) { currentUrl = value ?: url; canBack = v?.canGoBack() == true; syncLogin() }
                override fun onReceivedError(v: WebView?, request: WebResourceRequest?, error: WebResourceError?) { if (request?.isForMainFrame == true) failed = true }
            }
            if (login) {
                settings.userAgentString = "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36"
                CookieManager.getInstance().removeAllCookies { if (alive) loadUrl(url) }
            } else loadUrl(url)
        } }, update = { it.isHapticFeedbackEnabled = model.store.bool("key_enable_haptics", true) })
        if (progress < 1f) LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth().height(3.dp))
        if (login) Button(onClick = tapFeedback { syncLogin(true) }, modifier = Modifier.align(Alignment.BottomCenter).padding(horizontal = 20.dp, vertical = 16.dp).fillMaxWidth(), shape = RoundedCornerShape(16.dp), contentPadding = PaddingValues(vertical = 14.dp)) { Icon(Icons.Rounded.CheckCircleOutline, null); Spacer(Modifier.width(8.dp)); Text("我已登录成功，立即同步授权", fontSize = 15.sp, fontWeight = FontWeight.Bold) }
        if (login && model.writing) Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .54f)), contentAlignment = Alignment.Center) { Card(shape = RoundedCornerShape(20.dp)) { Column(Modifier.padding(horizontal = 28.dp, vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) { CircularProgressIndicator(); Spacer(Modifier.height(16.dp)); Text("正在同步账号信息...", fontSize = 15.sp, fontWeight = FontWeight.Bold) } } }
        }
    }
}

@Composable
fun MyPostsScreen(back: () -> Unit) {
    val model = LocalState.current; val account = model.account
    var profile by pageState("myProfile") { JSONObject() }; val colors = MaterialTheme.colorScheme
    val user = profile.obj("user"); val author = Author.parse(user)
    Column {
        PageBar("个人主页", back, titleWeight = FontWeight.Bold)
        if (account == null) LoginPrompt() else PagedContent(identity = account.uid, emptyMessage = "暂无发帖记录", load = { page ->
            if (page == 1) profile = model.api.post("/c/u/user/profile", mapOf("uid" to account.uid, "need_post_count" to "1"))
            val rows = model.api.threads(model.api.post("/c/u/feed/userpost", mapOf("uid" to account.uid, "pn" to "$page", "rn" to "20", "is_thread" to "1", "need_content" to "1")), "post_list")
            rows to (rows.size >= 20)
        }, header = {
            Card(Modifier.fillMaxWidth().padding(16.dp), shape = RoundedCornerShape(24.dp), colors = CardDefaults.cardColors(containerColor = colors.surfaceContainerLow)) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    OriginalAvatar(portraitUrl(author.portrait.ifEmpty { account.raw.s("portrait") }), "头像", Modifier.size(64.dp).clip(CircleShape)); Spacer(Modifier.width(16.dp))
                    Column { Text(if (user.length() == 0) account.name else author.name, fontSize = 18.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.height(4.dp)); Text("吧龄: ${user.s("tb_age").ifEmpty { "0" }} 年  •  UID: ${account.uid}", fontSize = 12.sp, color = colors.outline); Spacer(Modifier.height(8.dp)); Text("关注 ${user.s("concern_num").ifEmpty { "0" }}   粉丝 ${user.s("fans_num").ifEmpty { "0" }}   帖子 ${user.s("post_num").ifEmpty { "0" }}", fontSize = 13.sp, fontWeight = FontWeight.SemiBold) }
                }
            }
            Text("我的发帖与回帖", Modifier.padding(horizontal = 24.dp, vertical = 8.dp), fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }) { ThreadCard(it) }
    }
}



@Composable
fun NotificationEmptyState(message: String, loading: Boolean, error: String?, retry: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 96.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        if (loading) CircularProgressIndicator(color = colors.primary) else {
            Icon(if (error != null) Icons.Rounded.ErrorOutline else Icons.Rounded.NotificationsNone, null, Modifier.size(48.dp), tint = colors.outline)
            Spacer(Modifier.height(12.dp)); Text(error ?: message, color = colors.outline, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            if (error != null) { Spacer(Modifier.height(16.dp)); FilledTonalButton(onClick = tapFeedback(retry)) { Text("重试") } }
        }
    }
}

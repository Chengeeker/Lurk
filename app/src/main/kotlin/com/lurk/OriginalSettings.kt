package com.lurk

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import androidx.compose.ui.res.painterResource

@Composable
fun OriginalSwitch(title: String, key: String, icon: ImageVector, default: Boolean = false, subtitle: String = "") {
    val model = LocalState.current; val revision = model.revision
    ListItem(headlineContent = { Text(title, style = MaterialTheme.typography.titleMedium.copy(fontSize = 16.sp)) },
        supportingContent = if (subtitle.isEmpty()) null else { { Text(subtitle, fontSize = 13.sp) } },
        leadingContent = { Icon(icon, null, tint = MaterialTheme.colorScheme.onSurfaceVariant) },
        trailingContent = { Box(Modifier.width(60.dp), contentAlignment = Alignment.Center) { val toggle = tapFeedback { model.setting(key, !model.store.bool(key, default)) }; Switch(model.store.bool(key, default), { toggle() }) } },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        modifier = Modifier.feedbackClickable { model.setting(key, !model.store.bool(key, default)) }.padding(end = 8.dp))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OriginalSettingsHome(back: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current; val context = LocalContext.current
    var about by remember { mutableStateOf(false) }
    var export by remember { mutableStateOf(false) }
    var logout by remember { mutableStateOf(false) }
    var checking by remember { mutableStateOf(false) }
    var checked by remember { mutableStateOf<org.json.JSONObject?>(null) }
    Column {
        PageBar("设置", back, titleWeight = FontWeight.SemiBold)
        Column(Modifier.verticalScroll(rememberPageScrollState()).padding(horizontal = 16.dp, vertical = 12.dp)) {
            Text("偏好与功能", Modifier.padding(start = 16.dp, bottom = 12.dp), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SettingsSectionCard {
                SettingsRow("个性化", Icons.Outlined.Palette) { open(Route("settings", "appearance")) }
                SettingsRow("屏蔽设置", Icons.Rounded.Block) { open(Route("settings", "block")) }
                SettingsRow("使用习惯", Icons.Rounded.Tune) { open(Route("settings", "habits")) }
                SettingsRow("存储设置", Icons.Outlined.Folder) { open(Route("settings", "storage")) }
                SettingsRow("WebDAV备份", Icons.Rounded.CloudSync) { open(Route("backup")) }
                SettingsRow("缓存管理", Icons.Outlined.CleaningServices) { open(Route("settings", "cache")) }
                OriginalSwitch("使用内置浏览器", "key_use_internal_browser", Icons.Rounded.Language, true)
            }
            Spacer(Modifier.height(32.dp))
            Text("账号设置", Modifier.padding(start = 16.dp, bottom = 12.dp), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SettingsSectionCard {
                val account = model.account
                if (account != null) {
                    ListItem(headlineContent = { Text(account.name) }, supportingContent = { Text("UID: ${account.uid}", fontSize = 13.sp) },
                        leadingContent = { Icon(Icons.Rounded.AccountCircle, null) }, colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                        trailingContent = { TextButton(onClick = tapFeedback { logout = true }) { Text("退出登录", color = MaterialTheme.colorScheme.error) } })
                    SettingsRow("导出登录凭据 / Cookie", Icons.Rounded.Key) { export = true }
                    SettingsRow("检测账号凭据有效性", Icons.Outlined.VerifiedUser) { model.action { api, generation ->
                        checking = true
                        try { api.tbs(); val result = api.post("/c/u/user/profile", mapOf("uid" to account.uid, "need_post_count" to "1")); if (model.stillCurrent(generation)) checked = result.obj("user") }
                        finally { checking = false }
                    } }
                } else SettingsRow("登录百度账号", Icons.Rounded.Login) { open(Route("login")) }
            }
            Spacer(Modifier.height(32.dp))
            Text("关于与支持", Modifier.padding(start = 16.dp, bottom = 12.dp), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SettingsSectionCard { SettingsRow("关于 Lurk", Icons.Outlined.Info) { about = true } }
        }
    }
    if (checking) androidx.compose.ui.window.Dialog(onDismissRequest = {}) { Card { Row(Modifier.padding(horizontal = 28.dp, vertical = 20.dp), verticalAlignment = Alignment.CenterVertically) { CircularProgressIndicator(); Spacer(Modifier.width(18.dp)); Text("正在检测凭据有效性...", fontSize = 14.sp) } } }
    checked?.let { user ->
        val valid = user.s("id").isNotEmpty() && user.s("id") != "0" && user.s("name", "name_show").isNotEmpty()
        AlertDialog(onDismissRequest = { checked = null }, icon = { Icon(if (valid) Icons.Rounded.CheckCircle else Icons.Rounded.ErrorOutline, null, Modifier.size(48.dp), tint = if (valid) Color(0xFF4CAF50) else Color(0xFFFF9800)) }, title = { Text(if (valid) "账号凭据有效" else "账号凭据可能已失效", fontWeight = FontWeight.Bold) }, text = { Text(if (valid) "检测通过！当前账号【${Author.parse(user).name}】（账号：${user.s("name")}，UID：${user.s("id")}）的 Cookie 与令牌处于有效登录状态。" else "未能获取到有效用户信息，当前 Cookie 或访问令牌可能已过期，请尝试重新登录授权。", fontSize = 13.5.sp) }, confirmButton = { Button(onClick = tapFeedback { checked = null }) { Text(if (valid) "确定" else "我知道了") } })
    }
    if (logout) OriginalConfirmation("退出登录", "确定要退出当前账号吗？", "退出", { logout = false }) { model.account?.let { model.logout(it.uid) }; logout = false }
    if (export) ModalBottomSheet(sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), onDismissRequest = { export = false }, dragHandle = null, shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)) {
        val account = model.account
        if (account != null) Column(Modifier.padding(horizontal = 20.dp, vertical = 16.dp)) {
            Box(Modifier.align(Alignment.CenterHorizontally).size(36.dp, 4.dp).background(MaterialTheme.colorScheme.outline.copy(alpha = .3f), RoundedCornerShape(2.dp)))
            Spacer(Modifier.height(16.dp))
            Row(verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Rounded.Key, null, Modifier.size(22.dp), tint = MaterialTheme.colorScheme.primary); Spacer(Modifier.width(8.dp)); Text("导出登录凭据 / Cookie", fontSize = 17.sp, fontWeight = FontWeight.Bold) }
            Spacer(Modifier.height(16.dp))
            val cookie = "BDUSS=${account.bduss}; ${if (account.stoken.isNotEmpty()) "STOKEN=${account.stoken}; " else ""}"
            val credentials = listOf("UID" to account.uid, "BDUSS" to account.bduss) +
                (if (account.stoken.isNotEmpty()) listOf("STOKEN" to account.stoken) else emptyList()) + ("完整 Cookie" to cookie)
            fun copy(value: String) {
                (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("登录凭据", value))
                model.message("已复制到剪贴板")
            }
            credentials.forEachIndexed { index, (label, value) ->
                if (index > 0) Spacer(Modifier.height(10.dp))
                Surface(shape = RoundedCornerShape(12.dp), color = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = .4f), border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = .1f))) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.Top) {
                        Column(Modifier.weight(1f)) { Text(label, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary); Spacer(Modifier.height(4.dp)); Text(value, fontSize = 12.sp, fontFamily = FontFamily.Monospace, maxLines = if (label == "完整 Cookie") 3 else 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis) }
                        IconButton(onClick = tapFeedback { copy(value) }) { Icon(Icons.Rounded.ContentCopy, "复制 $label", Modifier.size(16.dp)) }
                    }
                }
            }
            Spacer(Modifier.height(18.dp))
            Button(modifier = Modifier.fillMaxWidth(), onClick = tapFeedback { copy("UID: ${account.uid}\nBDUSS: ${account.bduss}\nSTOKEN: ${account.stoken}\nCookie: $cookie"); export = false }) { Icon(Icons.Rounded.CopyAll, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("一键复制全部凭据") }
        }
    }
    if (about) androidx.compose.ui.window.Dialog(onDismissRequest = { about = false }) {
        val colors = MaterialTheme.colorScheme
        Surface(shape = RoundedCornerShape(20.dp), color = colors.surfaceContainerHigh) {
            Column(Modifier.padding(start = 20.dp, top = 24.dp, end = 20.dp, bottom = 24.dp).verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
                Image(painterResource(R.drawable.about_icon), "Lurk", Modifier.size(72.dp).clip(RoundedCornerShape(18.dp)), contentScale = ContentScale.Crop)
                Spacer(Modifier.height(14.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Lurk", fontSize = 21.sp, fontWeight = FontWeight.Bold, letterSpacing = .2.sp); Spacer(Modifier.width(8.dp))
                    Surface(color = colors.primaryContainer, shape = RoundedCornerShape(8.dp)) { Text("v${BuildConfig.VERSION_NAME}", Modifier.padding(horizontal = 8.dp, vertical = 2.5.dp), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = colors.onPrimaryContainer) }
                }
                Spacer(Modifier.height(6.dp)); Text("纯原生 Material You 极简社区客户端", fontSize = 13.sp, color = colors.onSurfaceVariant)
                Spacer(Modifier.height(16.dp)); OriginalDivider(); Spacer(Modifier.height(14.dp))
                listOf("100% 纯原生 Compose 与 MD3 动态主题配色", "原生接口直连、动态板块与社区签到", "自适应九宫格、全高清原图与丰富社区表情").forEachIndexed { i, text ->
                    if (i > 0) Spacer(Modifier.height(8.dp))
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Icon(listOf(Icons.Outlined.Palette, Icons.Rounded.Sync, Icons.Outlined.PhotoLibrary)[i], null, Modifier.size(16.dp), tint = colors.primary)
                        Spacer(Modifier.width(8.dp)); Text(text, fontSize = 12.5.sp, lineHeight = 1.35.em, color = colors.onSurfaceVariant)
                    }
                }
                Spacer(Modifier.height(14.dp)); OriginalDivider(); Spacer(Modifier.height(12.dp))
                Surface(onClick = tapFeedback { open(Route("url", "https://github.com/Chengeeker/Lurk")) }, shape = RoundedCornerShape(12.dp), color = colors.surfaceContainerHighest.copy(alpha = .5f), border = BorderStroke(1.dp, colors.outlineVariant.copy(alpha = .4f))) {
                    Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Code, null, Modifier.size(20.dp), tint = colors.primary); Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) { Text("GitHub 开源地址", fontSize = 13.sp, fontWeight = FontWeight.Bold); Text("github.com/Chengeeker/Lurk", fontSize = 11.sp, color = colors.onSurfaceVariant) }
                        Icon(Icons.Rounded.OpenInNew, null, Modifier.size(16.dp), tint = colors.primary)
                    }
                }
                Spacer(Modifier.height(16.dp))
                Button(onClick = tapFeedback { about = false }, shape = RoundedCornerShape(12.dp), contentPadding = PaddingValues(horizontal = 24.dp, vertical = 10.dp)) { Text("我知道了") }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OriginalAppearance(back: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current; val revision = model.revision
    DisposableEffect(model) { onDispose { model.fontSizePreview = null } }
    val names = listOf("深海蓝", "活力橙", "薄荷绿", "优雅紫", "樱花粉", "极光青", "玄青黑")
    val seeds = listOf(0xFF2F54EB, 0xFFFF7A00, 0xFF00A870, 0xFF722ED1, 0xFFEB2F96, 0xFF13C2C2, 0xFF374151)
    Column {
        PageBar("个性化", back, frosted = false)
        Column(Modifier.verticalScroll(rememberPageScrollState()).padding(start = 16.dp, top = 12.dp, end = 16.dp, bottom = 24.dp)) {
            AppearanceModes(model.store.int("key_theme_mode"), { model.setting("key_theme_mode", it) },
                model.store.bool("key_is_pure_black_dark"), { model.setting("key_is_pure_black_dark", it) })
            Spacer(Modifier.height(16.dp))
            AppearancePalette(model.store.bool("key_use_dynamic_color"), { model.setting("key_use_dynamic_color", it) },
                model.store.int("key_theme_color_index"), { model.setting("key_theme_color_index", it) }, seeds, names)
            Spacer(Modifier.height(16.dp))
            FontWeightSetting(model.store.bool("key_use_custom_font_weight", model.store.int("key_font_weight_index", 1) != 1),
        (model.store.int("key_font_weight_index", 1) - 1) * 100, "Lurk", hapticsEnabled = model.store.bool("key_enable_haptics", true),
        onReset = { model.setting("key_use_custom_font_weight", false) },
        onCommit = { model.setting("key_font_weight_index", it / 100 + 1); model.setting("key_use_custom_font_weight", true) })
    Spacer(Modifier.height(16.dp))
            FontSizeSetting(model.store.int("key_font_size_percent", 100) / 100f) { model.setting("key_font_size_percent", kotlin.math.round(it * 100).toInt()) }
            Spacer(Modifier.height(16.dp))
            Spacer(Modifier.height(16.dp))
            AppearanceSection("底部导航") { OriginalSwitch("使用悬浮底栏", "key_use_floating_nav_bar", Icons.Rounded.Dock, true) }
            Spacer(Modifier.height(16.dp))
            AppearanceSection("显示效果") { OriginalSwitch("使用液态玻璃效果", "key_use_liquid_glass_effect", Icons.Rounded.BlurOn, subtitle = "用于图片画廊按钮；悬浮底栏需同时开启悬浮样式")
                if(model.store.bool("key_use_liquid_glass_effect") && model.store.bool("key_use_floating_nav_bar", true)) NavigationGlassChoice(model.store.bool("translucentNavigationGlass", false), hapticsEnabled = model.store.bool("key_enable_haptics", true)) { model.setting("translucentNavigationGlass", it) }
            }
            Spacer(Modifier.height(16.dp))
            AppearanceSection("屏幕显示") { SettingsRow("屏幕帧率设置", Icons.Rounded.Speed) { open(Route("settings", "display")) } }
            Spacer(Modifier.height(16.dp))
            AppearanceSection("触感与震动") { OriginalSwitch("触感与震动反馈", "key_enable_haptics", Icons.Rounded.Vibration, true) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OriginalStorage(back: () -> Unit) {
    val model = LocalState.current; val revision = model.revision
    var selected by remember { mutableStateOf<Boolean?>(null) }
    val nickname = model.account?.name ?: "MyProfile"
    fun summary(type: Int) = when (type) { 1 -> "Pictures/Lurk/$nickname/"; 2 -> "Pictures/Lurk/该贴发布用户昵称/"; else -> "Pictures/Lurk/" }
    Column {
        PageBar("存储设置", back, frosted = false)
        Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
            SettingsSectionCard {
                SettingsRow("图片存储路径", Icons.Outlined.Image, summary(model.store.int("key_image_save_path_type"))) { selected = false }
                SettingsRow("视频存储路径", Icons.Outlined.VideoLibrary, summary(model.store.int("key_video_save_path_type"))) { selected = true }
            }
        }
    }
    selected?.let { video -> ModalBottomSheet(sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), onDismissRequest = { selected = null }, dragHandle = null, containerColor = MaterialTheme.colorScheme.surface, shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)) {
        val key = if (video) "key_video_save_path_type" else "key_image_save_path_type"
        Column(Modifier.padding(horizontal = 16.dp, vertical = 16.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text(if (video) "视频存储路径" else "图片存储路径", Modifier.weight(1f), fontSize = 16.sp, fontWeight = FontWeight.Bold); IconButton(onClick = tapFeedback { selected = null }) { Icon(Icons.Rounded.Close, "关闭") } }
            Spacer(Modifier.height(6.dp)); Text("保存${if (video) "视频" else "图片"}时，文件将自动归类并存储至相册对应文件夹下。", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(12.dp))
            listOf("默认路径", "按本人昵称前缀归类", "按楼主昵称前缀归类").forEachIndexed { index, text ->
                ListItem(headlineContent = { Text(text, fontSize = 16.sp) }, supportingContent = { Text(summary(index), fontSize = 12.sp) },
                    leadingContent = { RadioButton(model.store.int(key) == index, tapFeedback { model.setting(key, index); selected = null }) },
                    modifier = Modifier.feedbackClickable { model.setting(key, index); selected = null }, colors = ListItemDefaults.colors(containerColor = Color.Transparent))
            }
        }
    } }
}

@Composable
fun OriginalDisplay(back: () -> Unit) {
    val model = LocalState.current; val activity = androidx.activity.compose.LocalActivity.current; val revision = model.revision
    val modes = activity?.window?.decorView?.display?.supportedModes.orEmpty()
    val selected = model.store.int("key_selected_display_mode_id")
    Column {
        PageBar("屏幕帧率设置", back, titleWeight = FontWeight.SemiBold)
        Column(Modifier.verticalScroll(rememberPageScrollState()).padding(horizontal = 16.dp, vertical = 12.dp)) {
            Text("没有生效？重启app试试", Modifier.padding(start = 16.dp, bottom = 16.dp), fontSize = 13.5.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.primary.copy(alpha = .85f))
            SettingsSectionCard {
                (listOf(0 to "自动") + modes.map { it.modeId to "#${it.modeId} ${it.physicalWidth}x${it.physicalHeight} @ ${it.refreshRate.toInt()}Hz" }).forEach { (id, name) ->
                    Row(Modifier.fillMaxWidth().feedbackClickable { model.setting("key_selected_display_mode_id", id) }.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(name, Modifier.weight(1f), fontSize = 16.sp, color = if (selected == id) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
                        Box(Modifier.size(22.dp).border(2.dp, if (selected == id) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant.copy(alpha = .35f), CircleShape), contentAlignment = Alignment.Center) {
                            if (selected == id) Box(Modifier.size(11.dp).background(MaterialTheme.colorScheme.primary, CircleShape))
                        }
                    }
                }
            }
        }
    }
}



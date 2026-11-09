@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.lurk

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.*
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import coil.compose.AsyncImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class ForumRule(val title: String, val contents: List<String>)
fun forumRules(j: JSONObject): List<ForumRule> = (j.optJSONArray("rules") ?: j.optJSONArray("new_rules") ?: j.optJSONArray("default_rules")).objects().map { row ->
    val text = linkedSetOf<String>()
    fun extract(value: Any?, depth: Int = 0) {
        require(depth <= 64) { "吧规内容层级过深" }
        when (value) {
            is String -> if (value.isNotBlank()) text.add(value.trim())
            is JSONArray -> (0 until value.length()).forEach { extract(value.opt(it), depth + 1) }
            is JSONObject -> { extract(value.opt("text"), depth + 1); listOf("content", "content_list", "children", "items").forEach { extract(value.opt(it), depth + 1) } }
        }
    }
    listOf("content", "content_list", "children", "items").forEach { extract(row.opt(it)) }
    ForumRule(row.s("title"), text.toList())
}

@Composable
fun ForumScreen(name: String, back: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current; val context = LocalContext.current; val colors = MaterialTheme.colorScheme
    var sort by rememberSaveable { mutableIntStateOf(model.store.int("key_habit_forum_default_sort").coerceIn(0, 1)) }
    var selectedTab by rememberSaveable { mutableIntStateOf(0) }
    var forum by pageState("forum") { JSONObject() }; var tabs by pageState("tabs") { emptyList<JSONObject>() }
    var rule by pageState("rule") { JSONObject() }; var pins by pageState("pins") { emptyList<ThreadItem>() }
    var showPins by rememberSaveable { mutableStateOf(false) }; var menu by remember { mutableStateOf(false) }
    var unfollow by remember { mutableStateOf(false) }; var rules by remember { mutableStateOf(false) }
    val followed = forum.flag("is_like") || forum.flag("is_liked") || forum.flag("is_like_forum")
    val parsed = Forum.parse(JSONObject(forum.toString()).put("name", name)); val signed = model.signed(parsed)
    fun follow(like: Boolean) = model.action { api, generation ->
        val id = forum.s("id", "forum_id").takeUnless { it.isEmpty() || it == "0" } ?: api.forum(name, 1).obj("forum").s("id")
        require(id.isNotEmpty() && id != "0") { "无法获取吧 ID" }
        api.write(if (like) "/c/c/forum/like" else "/c/c/forum/unfavolike", mapOf("kw" to name, "fid" to id))
        if (model.stillCurrent(generation)) { forum = JSONObject(forum.toString()).put("is_like", if (like) 1 else 0).put("is_liked", if (like) 1 else 0).put("is_like_forum", if (like) 1 else 0); model.invalidateFollowed(); model.message(if (like) "关注成功！" else "已取消关注") }
    }
    FrostedFrame(header = {
        PageBar("${name.removeSuffix("吧")}吧", back, titleSize = 17.sp, titleWeight = FontWeight.Bold, actions = {
            IconButton(onClick = tapFeedback { open(Route("search", name)) }) { Icon(Icons.Rounded.Search, "吧内搜索") }
            Box { IconButton(onClick = tapFeedback { menu = true }) { Icon(Icons.Rounded.MoreVert, "更多") }; DropdownMenu(menu, { menu = false }) {
                DropdownMenuItem(text = { Text("发帖") }, leadingIcon = { Icon(Icons.Rounded.PostAdd, null) }, onClick = tapFeedback { menu = false; if (model.account == null) model.message("请先登录百度账号") else open(Route("compose", name, forum.s("id"))) })
                DropdownMenuItem(text = { Text("分享") }, leadingIcon = { Icon(Icons.Outlined.Share, null) }, onClick = tapFeedback { menu = false; (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("贴吧链接", "https://tieba.baidu.com/f?kw=${java.net.URLEncoder.encode(name, "UTF-8")}")); model.message("已复制贴吧链接") })
                DropdownMenuItem(text = { Text("取消关注") }, leadingIcon = { Icon(Icons.Outlined.PersonRemove, null) }, onClick = tapFeedback { menu = false; if (followed) unfollow = true else model.message("尚未关注该贴吧") })
            } }
        })
    }) {
        PagedContent(identity = "forumThreads", reloadKey = "$sort:$selectedTab", emptyMessage = "本板块暂无帖子", bottomPadding = 40, load = { page ->
            val data = model.api.forum(name, page, sort, tabs.getOrNull(selectedTab), forum.s("id"))
            if (page == 1 && data.has("forum")) {
                forum = data.obj("forum"); model.observeForum(Forum.parse(JSONObject(forum.toString()).put("name", name)))
                val remoteTabs = data.obj("nav_tab_info").rows("tab").ifEmpty { data.rows("frs_tab_info") }.ifEmpty { data.rows("frs_main_tab_list") }.distinctBy { it.s("tab_name", "text") }
                tabs = if (remoteTabs.none { it.s("tab_name", "text") == "全部" }) listOf(JSONObject().put("tab_name", "全部").put("tab_id", "0")) + remoteTabs else remoteTabs
                if (tabs.none { it.s("tab_name", "text").contains("精华") || it.s("tab_id") == "301" }) tabs = tabs.take(1) + JSONObject().put("tab_id", "301").put("tab_type", "12").put("tab_name", "最新精华").put("is_good", 1) + tabs.drop(1)
                rule = data.optJSONObject("forum_rule") ?: data.obj("forum").obj("forum_rule")
                if (!model.store.bool("key_habit_do_not_save_history")) withContext(Dispatchers.IO) {
                    val key = "key_forum_browsing_history_list"
                    val row = JSONObject().put("name", name).put("avatar", forum.s("avatar")).put("time", System.currentTimeMillis())
                    model.store.put(key, (listOf(row.toString()) + model.store.list(key).filter { runCatching { JSONObject(it).s("name") != name }.getOrDefault(false) }).take(100))
                }
            }
            val all = model.api.threads(data, if (data.has("general_list")) "general_list" else "thread_list")
            if (page == 1) pins = all.filter { it.raw.flag("is_top") }
            all.filterNot { it.raw.flag("is_top") } to (data.obj("page").flag("has_more") || data.flag("has_more"))
        }, header = {
            Column(Modifier.padding(start = 12.dp, top = 6.dp, end = 12.dp, bottom = 4.dp)) {
                Card(Modifier.padding(horizontal = 2.dp, vertical = 5.dp), shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = colors.surfaceContainerLow)) {
                    Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        OriginalAvatar(forum.s("avatar"), "$name 的头像", Modifier.size(48.dp).clip(CircleShape)); Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text("${name.removeSuffix("吧")}吧", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(2.dp)); if (forum.length() > 0) Text("关注 ${forum.s("member_num")}  |  帖子 ${forum.s("post_num")}", fontSize = 11.5.sp, color = colors.onSurfaceVariant)
                            if (forum.s("slogan").isNotEmpty()) Text(forum.s("slogan"), Modifier.padding(top = 2.dp), fontSize = 10.5.sp, color = colors.outline, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                        Spacer(Modifier.width(8.dp))
                        if (forum.length() > 0) Surface(onClick = tapFeedback { if (!model.writing) { if (!followed) follow(true) else if (!signed) model.signOne(parsed) } }, enabled = !model.writing && (!followed || !signed), shape = RoundedCornerShape(20.dp), color = if (!followed) colors.primary else if (signed) colors.surfaceContainerLow else colors.primaryContainer) {
                            Row(Modifier.padding(horizontal = if (!followed) 14.dp else 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                                Icon(if (!followed) Icons.Rounded.Add else if (signed) Icons.Rounded.CheckCircle else Icons.Outlined.CalendarToday, null, Modifier.size(15.dp), tint = if (!followed) colors.onPrimary else if (signed) colors.outline else colors.primary)
                                Spacer(Modifier.width(2.dp)); Text(if (!followed) "关注" else if (signed) "已签到" else "签到", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = if (!followed) colors.onPrimary else if (signed) colors.outline else colors.primary)
                            }
                        }
                    }
                }
                if (tabs.isNotEmpty()) Row(Modifier.padding(top = 8.dp).height(36.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    tabs.forEachIndexed { index, tab -> FilterChip(index == selectedTab, tapFeedback { selectedTab = index }, label = { Text(tab.s("tab_name", "text", "name"), fontSize = 12.5.sp, fontWeight = if (selectedTab == index) FontWeight.Bold else FontWeight.Normal) }, shape = RoundedCornerShape(18.dp), border = BorderStroke(.8.dp, if (selectedTab == index) colors.primary else colors.outlineVariant.copy(alpha = .25f)), colors = FilterChipDefaults.filterChipColors(containerColor = colors.surfaceContainerHighest.copy(alpha = .3f), selectedContainerColor = colors.primaryContainer)) }
                }
                if (rule.s("title").isNotEmpty()) {
                    Spacer(Modifier.height(6.dp)); ForumRuleBanner(rule.s("title")) { rules = true }
                }
                if (pins.isNotEmpty()) {
                    Spacer(Modifier.height(6.dp)); Surface(shape = RoundedCornerShape(12.dp), color = colors.surfaceContainerLow, border = BorderStroke(.6.dp, colors.outlineVariant.copy(alpha = .25f))) {
                        Column {
                            Row(Modifier.fillMaxWidth().feedbackClickable { showPins = !showPins }.padding(horizontal = 10.dp, vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
                                Surface(shape = RoundedCornerShape(4.dp), color = colors.errorContainer) { Text("置顶", Modifier.padding(horizontal = 5.dp, vertical = 1.5.dp), fontSize = 10.5.sp, fontWeight = FontWeight.Bold, color = colors.onErrorContainer) }
                                PinnedCount(pins.size, Modifier.weight(1f).padding(start = 8.dp)); Icon(if (showPins) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown, "展开置顶帖", Modifier.size(16.dp))
                            }
                            if (showPins) pins.forEach { pin -> OriginalDivider(); ListItem(headlineContent = { Text(pin.title, fontSize = 12.5.sp, maxLines = 1, overflow = TextOverflow.Ellipsis) }, leadingContent = { Icon(Icons.Rounded.PushPin, null, Modifier.size(14.dp), tint = colors.error) }, colors = ListItemDefaults.colors(containerColor = Color.Transparent), modifier = Modifier.feedbackClickable { open(Route("thread", pin.id)) }) }
                        }
                    }
                }
                Row(Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("按回复时间", "按发帖时间").forEachIndexed { index, title -> Surface(onClick = tapFeedback { sort = index }, shape = RoundedCornerShape(12.dp), color = if (sort == index) colors.primary.copy(alpha = .12f) else colors.surfaceContainerLow, border = BorderStroke(.8.dp, if (sort == index) colors.primary else colors.outlineVariant.copy(alpha = .25f))) { Text(title, Modifier.padding(horizontal = 10.dp, vertical = 5.dp), fontSize = 11.5.sp, fontWeight = if (sort == index) FontWeight.Bold else FontWeight.Normal, color = if (sort == index) colors.primary else colors.onSurfaceVariant) } }
                }
            }
        }) { Box(Modifier.padding(horizontal = 4.dp, vertical = 2.dp)) { ThreadCard(it) } }
    }
    if (unfollow) AlertDialog(onDismissRequest = { unfollow = false }, title = { Text("取消关注") }, text = { Text("确定要取消关注「${name.removeSuffix("吧")}吧」吗？") }, confirmButton = { TextButton(onClick = tapFeedback { unfollow = false; follow(false) }) { Text("确定取消", color = colors.error) } }, dismissButton = { TextButton(onClick = tapFeedback { unfollow = false }) { Text("取消") } })
    if (rules) ForumRulesSheet(forum.s("id", "forum_id"), rule.s("title")) { rules = false }
}

@Composable
internal fun ForumRuleBanner(title: String, click: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    // This translucent container is drawn over the page, so use the page's foreground role.
    Surface(onClick = tapFeedback(click), shape = RoundedCornerShape(12.dp), color = colors.tertiaryContainer.copy(alpha = .35f), border = BorderStroke(.6.dp, colors.tertiary.copy(alpha = .2f))) {
        Row(Modifier.padding(horizontal = 10.dp, vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Campaign, null, Modifier.size(16.dp), tint = colors.tertiary)
            Spacer(Modifier.width(8.dp))
            Text("吧规: $title", Modifier.weight(1f), fontSize = 12.sp, maxLines = 1, color = colors.onSurface, overflow = TextOverflow.Ellipsis)
            Icon(Icons.Rounded.ChevronRight, null, Modifier.size(16.dp), tint = colors.tertiary)
        }
    }
}

@Composable
internal fun PinnedCount(count: Int, modifier: Modifier = Modifier) {
    Text("$count 篇置顶帖", modifier, fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
fun ForumRulesSheet(fid: String, title: String, dismiss: () -> Unit) {
    val model = LocalState.current; val colors = MaterialTheme.colorScheme
    val scroll = rememberScrollState()
    val windowHeight = with(LocalDensity.current) { LocalConfiguration.current.screenHeightDp.dp.toPx() }
    var fraction by remember { mutableFloatStateOf(.75f) }
    fun resize(delta: Float): Float { val old = fraction; fraction = (fraction - delta / windowHeight).coerceIn(.4f, .95f); return (old - fraction) * windowHeight }
    val nested = remember(windowHeight) { object : NestedScrollConnection {
        override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset =
            if (available.y < 0 && fraction < .95f || available.y > 0 && scroll.value == 0 && fraction > .4f) Offset(0f, resize(available.y)) else Offset.Zero
    } }
    var data by remember { mutableStateOf<JSONObject?>(null) }; var failed by remember { mutableStateOf(false) }
    var rules by remember { mutableStateOf(emptyList<ForumRule>()) }
    LaunchedEffect(fid) {
        try {
            require(fid.isNotEmpty() && fid != "0")
            val response = model.api.post("/c/f/forum/forumRuleDetail", mapOf("forum_id" to fid))
            val payload = listOf("data", "result", "forum_rule_detail", "forum_rule").firstNotNullOfOrNull { response.optJSONObject(it) } ?: response
            rules = forumRules(payload); data = payload
        } catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (_: Exception) { failed = true }
    }
    ModalBottomSheet(sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), onDismissRequest = dismiss, dragHandle = null, shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp), containerColor = colors.background) {
        Column(Modifier.fillMaxWidth().fillMaxHeight(fraction).nestedScroll(nested)) {
            Box(Modifier.fillMaxWidth().draggable(rememberDraggableState { resize(it) }, Orientation.Vertical).padding(top = 12.dp, bottom = 8.dp), contentAlignment = Alignment.Center) { Box(Modifier.size(40.dp, 4.dp).background(colors.outline.copy(alpha = .3f), RoundedCornerShape(2.dp))) }
            Row(Modifier.draggable(rememberDraggableState { resize(it) }, Orientation.Vertical).padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Outlined.Gavel, null, Modifier.size(24.dp), tint = colors.primary); Spacer(Modifier.width(10.dp)); Text("本吧吧规", Modifier.weight(1f), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold); IconButton(onClick = tapFeedback(dismiss)) { Icon(Icons.Outlined.Close, "关闭") } }
            OriginalDivider()
            if (failed || data == null) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Column(horizontalAlignment = Alignment.CenterHorizontally) { if (!failed) CircularProgressIndicator() else Icon(Icons.Rounded.ErrorOutline, null); Spacer(Modifier.height(16.dp)); Text(if (failed) "官方吧规加载失败" else "正在拉取官方吧规详细内容..."); if (failed) Text("当前没有展示占位内容，请检查网络后关闭并重新打开。", Modifier.padding(20.dp), fontSize = 13.sp) } }
            else Column(Modifier.verticalScroll(scroll).padding(20.dp)) {
                val detail = data!!
                Text(detail.s("title").ifEmpty { title }, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                val publisher = detail.obj("bazhu")
                if (publisher.length() > 0 || detail.s("publish_time").isNotEmpty()) Row(Modifier.padding(vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) { OriginalAvatar(portraitUrl(publisher.s("portrait")), null, Modifier.size(28.dp).clip(CircleShape)); Spacer(Modifier.width(8.dp)); Text("${publisher.s("name_show", "name")}  ${detail.s("publish_time")}", fontSize = 12.sp, color = colors.outline) }
                if (detail.s("preface").isNotEmpty()) Text(plainText(detail.s("preface")), Modifier.padding(bottom = 20.dp), fontSize = 13.5.sp, lineHeight = 1.55.em)
                if (rules.isEmpty()) Text(if (detail.length() == 0) "本吧暂未配置详细吧规" else "官方暂未返回详细条款内容。", Modifier.padding(vertical = 12.dp), color = colors.outline)
                rules.forEach { row ->
                    Surface(shape = RoundedCornerShape(16.dp), color = colors.surfaceContainerLow, border = BorderStroke(1.dp, colors.outline.copy(alpha = .12f)), modifier = Modifier.padding(bottom = 12.dp)) {
                        Column(Modifier.fillMaxWidth().padding(16.dp)) {
                            if (row.title.isNotEmpty()) { Row(verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Outlined.Shield, null, Modifier.size(18.dp), tint = colors.primary); Spacer(Modifier.width(8.dp)); Text(row.title, fontSize = 15.sp, fontWeight = FontWeight.Bold) }; Spacer(Modifier.height(10.dp)) }
                            row.contents.forEach { Text(plainText(it), Modifier.padding(bottom = 6.dp), fontSize = 13.5.sp, lineHeight = 1.55.em, color = colors.onSurfaceVariant) }
                        }
                    }
                }
                Text("文明发帖，理性交流，共同维护良好贴吧秩序", Modifier.align(Alignment.CenterHorizontally).padding(top = 12.dp, bottom = 24.dp), fontSize = 11.sp, color = colors.outline.copy(alpha = .7f))
            }
        }
    }
}



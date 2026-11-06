@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.lurk

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import org.json.JSONObject

suspend fun NativeApi.searchPosts(keyword: String, page: Int, sort: Int, only: Boolean, forum: String): List<ThreadItem> = coroutineScope {
    val params = mutableMapOf("word" to keyword, "pn" to "$page", "rn" to "20", "only_thread" to if (only) "1" else "0", "sm" to "$sort", "_client_version" to "12.65.1.0")
    if (forum.isNotEmpty()) params["kw"] = forum
    val source = threads(post("/c/s/searchpost", params), "post_list")
    val permits = Semaphore(4)
    source.map { item -> async {
        permits.withPermit {
            withTimeoutOrNull(2500) {
                try {
                    val data = post("/c/f/pb/page", mapOf("kz" to item.id, "pn" to "1", "rn" to "1", "from" to "baidu_appstore"))
                    val first = data.rows("post_list").firstOrNull()
                    val media = distinctPostMedia(parseContent(first?.opt("content")).mapNotNull { it.media })
                    val author = item.author.copy(portrait = item.author.portrait.ifEmpty { data.obj("thread").obj("author").s("portrait") })
                    val pictures = media.ifEmpty { item.media }
                    val title = item.title.ifEmpty { plainText(item.segments.joinToString("") { it.text }).ifEmpty { "贴吧贴子" } }
                    val stored = JSONObject(item.raw.toString()).put("title", title).put("author", JSONObject(item.raw.obj("author").toString()).put("portrait", author.portrait))
                        .put("media", org.json.JSONArray(pictures.map { it.json() }))
                    item.copy(title = title, author = author, media = pictures, raw = stored)
                } catch (e: CancellationException) { throw e } catch (_: Exception) { item }
            } ?: item
        }
    } }.awaitAll()
}

@Composable
fun FilterPill(text: String, selected: Boolean, click: () -> Unit) {
    val c = MaterialTheme.colorScheme
    Surface(onClick = tapFeedback(click), shape = RoundedCornerShape(16.dp), color = if (selected) c.primary else c.surfaceContainerHighest.copy(alpha = .5f), border = BorderStroke(.8.dp, if (selected) c.primary else c.outline.copy(alpha = .15f))) {
        Text(text, Modifier.padding(horizontal = 10.dp, vertical = 4.dp), fontSize = 12.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal, color = if (selected) c.onPrimary else c.onSurfaceVariant)
    }
}

@Composable
fun SearchScreen(forum: String, back: () -> Unit, initial: String = "") {
    val model = LocalState.current; val open = LocalOpen.current; val colors = MaterialTheme.colorScheme
    val keyboard = LocalSoftwareKeyboardController.current
    var query by rememberSaveable { mutableStateOf(initial) }; var submitted by rememberSaveable { mutableStateOf(initial) }
    var tab by rememberSaveable { mutableIntStateOf(if (forum.isNotEmpty() || initial.isNotEmpty()) 1 else 0) }
    var sort by rememberSaveable { mutableIntStateOf(0) }; var only by rememberSaveable { mutableStateOf(true) }
    var sorts by remember { mutableStateOf(false) }; val focus = remember { FocusRequester() }
    fun submit() { if (query.isNotBlank()) { submitted = query.trim(); keyboard?.hide() } }
    LaunchedEffect(Unit) { if (initial.isEmpty()) focus.requestFocus() }
    Column {
        FrostedHeading {
        Row(Modifier.fillMaxWidth().statusBarsPadding().height(56.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = tapFeedback(back)) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "返回") }
            if (forum.isNotEmpty()) {
                Surface(color = colors.primaryContainer, shape = RoundedCornerShape(8.dp), modifier = Modifier.widthIn(max = 120.dp)) { Row(Modifier.padding(horizontal = 8.dp, vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Outlined.Forum, null, Modifier.size(14.dp), tint = colors.onPrimaryContainer); Spacer(Modifier.width(4.dp)); Text(forum, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis, color = colors.onPrimaryContainer) } }
                Spacer(Modifier.width(8.dp))
            }
            BasicTextField(query, { query = it }, Modifier.weight(1f).focusRequester(focus), singleLine = true, textStyle = TextStyle(fontSize = 15.sp, color = colors.onSurface), keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search), keyboardActions = KeyboardActions(onSearch = { submit() }), decorationBox = { input -> Box { if (query.isEmpty()) Text(if (forum.isEmpty()) "搜索吧、贴子或吧友..." else "吧内搜索...", fontSize = 14.sp, color = colors.outline); input() } })
            if (query.isNotEmpty()) IconButton(onClick = tapFeedback { query = "" }) { Icon(Icons.Outlined.Clear, "清除", Modifier.size(18.dp)) }
            IconButton(onClick = tapFeedback(::submit)) { Icon(Icons.Rounded.Search, "搜索") }
        }
        if (forum.isEmpty()) OriginalTabBar(tab, listOf("搜吧", "搜帖", "搜人"), { if (tab == 1 && it == 1) sorts = true; tab = it })
        }
        if (forum.isNotEmpty()) Row(Modifier.fillMaxWidth().height(48.dp).padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            FilterPill("相关性", sort == 0) { sort = 0; submit() }; Spacer(Modifier.width(6.dp)); FilterPill("时间倒序", sort == 1) { sort = 1; submit() }
            Spacer(Modifier.weight(1f)); FilterPill("全部", !only) { only = false; submit() }; Spacer(Modifier.width(6.dp)); FilterPill("只看主题贴", only) { only = true; submit() }
        }
        OriginalTabs(if (forum.isEmpty()) tab else 0, if (forum.isEmpty()) 3 else 1, { if (forum.isEmpty()) tab = it }) { page ->
        val tab = if (forum.isEmpty()) page else 1
        Column {
        if (forum.isEmpty() && tab == 1) Row(Modifier.fillMaxWidth().background(colors.surface).padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("排序：", fontSize = 12.sp, color = colors.outline, fontWeight = FontWeight.Medium); Spacer(Modifier.width(4.dp))
            listOf(1 to "新贴在前", 2 to "旧贴在前", 0 to "相关度").forEachIndexed { index, (value, label) ->
                if (index > 0) Spacer(Modifier.width(8.dp))
                FilterPill(label, sort == value) { sort = value }
            }
        }
        if (submitted.isEmpty()) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text(if (forum.isNotEmpty()) "输入关键字在 $forum 吧内搜索" else listOf("输入关键字搜索贴吧", "输入关键字搜索贴子", "输入关键字搜索吧友")[tab], fontSize = 13.5.sp, color = colors.outline) }
        else key(submitted, tab, sort, only) {
            if (tab == 1) PagedContent(identity = "$submitted:$tab:$sort:$only", emptyMessage = "未找到相关贴子", load = { page -> model.api.searchPosts(submitted, page, sort, only, forum).let { it to (it.size >= 20) } }) { ThreadCard(it) }
            else PagedContent(identity = "$submitted:$tab", emptyMessage = if (tab == 0) "未找到相关贴吧" else "未找到相关用户", load = {
                val data = model.api.web("/mo/q/search/${if (tab == 0) "forum" else "user"}", mapOf("word" to submitted)).obj("data")
                (listOfNotNull(data.optJSONObject("exactMatch")?.put("compose_featured", true)) + data.rows("fuzzyMatch").onEachIndexed { index, row -> row.put("compose_related_header", index == 0) }) to false
            }) { row ->
                val featured = row.flag("compose_featured")
                val name = row.s("name_show", "name", "user_name", "forum_name")
                Column(Modifier.padding(horizontal = 14.dp)) {
                    if (featured) Row(Modifier.padding(start = 12.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Rounded.Verified, null, Modifier.size(15.dp), tint = colors.primary); Spacer(Modifier.width(5.dp)); Text(if (tab == 0) "推荐贴吧" else "推荐用户", fontSize = 13.sp, color = colors.primary, fontWeight = FontWeight.Bold) }
                    if (row.flag("compose_related_header")) Text(if (tab == 0) "相关贴吧" else "相关用户", Modifier.padding(start = 12.dp, bottom = 8.dp), fontSize = 13.sp, fontWeight = FontWeight.Bold, color = colors.onSurfaceVariant)
                    Card(Modifier.padding(bottom = 8.dp).fillMaxWidth().feedbackClickable { open(if (tab == 0) Route("forum", row.s("name", "forum_name")) else Route("profile", row.s("id", "user_id", "uid"))) }, shape = RoundedCornerShape(14.dp), border = if (featured) BorderStroke(1.dp, colors.primary.copy(alpha = .3f)) else null, elevation = CardDefaults.cardElevation(if (featured) 1.5.dp else .5.dp), colors = CardDefaults.cardColors(containerColor = if (featured) colors.primaryContainer.copy(alpha = .25f) else colors.surfaceContainerLow)) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            OriginalAvatar(if (tab == 0) row.s("avatar", "forum_avatar", "image") else portraitUrl(row.s("portrait")), "$name 的头像", Modifier.size(if (featured) 52.dp else 44.dp).clip(RoundedCornerShape(if (tab == 0) 12.dp else if (featured) 26.dp else 22.dp)))
                            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(if (tab == 0) "${name.removeSuffix("吧")}吧" else name, Modifier.weight(1f, fill = false), fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    if (featured) { Spacer(Modifier.width(6.dp)); Text("精准匹配", Modifier.background(colors.primary, RoundedCornerShape(6.dp)).padding(horizontal = 6.dp, vertical = 2.dp), color = colors.onPrimary, fontSize = 10.sp, fontWeight = FontWeight.Bold) }
                                }
                                if (tab != 0 && row.s("name").isNotEmpty()) { Spacer(Modifier.height(3.dp)); Text("贴吧账号：${row.s("name")}", fontSize = 12.sp, color = colors.onSurfaceVariant) }
                                val desc = plainText(row.s("intro", "desc", "slogan"))
                                if (desc.isNotEmpty()) { Spacer(Modifier.height(3.dp)); Text(desc, fontSize = if (tab == 0) 12.sp else 11.5.sp, maxLines = 1, overflow = TextOverflow.Ellipsis, color = if (tab == 0) colors.onSurfaceVariant else colors.outline) }
                                Spacer(Modifier.height(4.dp))
                                Text(if (tab == 0) "关注 ${row.s("member_num", "concern_count", "concern_num")}  •  帖子 ${row.s("post_num", "post_count")}" else "粉丝 ${row.s("fans_num", "fans_count")}", fontSize = 11.5.sp, color = colors.outline)
                            }
                            Spacer(Modifier.width(8.dp)); Icon(Icons.Rounded.ChevronRight, null, tint = colors.outline.copy(alpha = .6f))
                        }
                    }
                    if (featured) Spacer(Modifier.height(16.dp))
                }
            }
        }
        }
    }
    }
    if (sorts) ModalBottomSheet(sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), onDismissRequest = { sorts = false }, dragHandle = null, shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)) {
        Column(Modifier.padding(horizontal = 20.dp, vertical = 16.dp)) {
            Box(Modifier.align(Alignment.CenterHorizontally).size(36.dp, 4.dp).background(colors.outline.copy(alpha = .3f), RoundedCornerShape(2.dp))); Spacer(Modifier.height(14.dp))
            Text("搜帖排序方式", fontSize = 16.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.height(12.dp))
            listOf(Triple(1, "新贴在前", "按发帖与最新回复时间倒序排列"), Triple(2, "旧贴在前", "按发帖时间正序排列"), Triple(0, "相关度", "按贴子与搜索关键词的相关程度综合排序")).forEach { (mode, label, detail) ->
                Row(Modifier.fillMaxWidth().heightIn(min = 72.dp).feedbackClickable { sort = mode; sorts = false }.padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) { Text(label, fontSize = 16.sp, color = if (sort == mode) colors.primary else colors.onSurface, fontWeight = if (sort == mode) FontWeight.Bold else FontWeight.Medium); Text(detail, fontSize = 12.sp, color = colors.outline) }
                    if (sort == mode) Icon(Icons.Rounded.Check, "已选择", tint = colors.primary)
                }
            }
        }
    }
}

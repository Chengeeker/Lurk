@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.lurk

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import coil.compose.AsyncImage
import kotlinx.coroutines.*
import org.json.JSONObject

fun savedRows(store: AppStore, key: String) = store.list(key).mapNotNull { runCatching { ThreadItem.parse(JSONObject(it)) }.getOrNull() }

@Composable
fun SavedScreen(bookmarks: Boolean, back: () -> Unit) {
    if (!bookmarks) { HistoryScreen(back); return }
    val model = LocalState.current; val colors = MaterialTheme.colorScheme; val scope = rememberCoroutineScope()
    var values by pageState("saved") { model.saved() }; var page by pageState("page") { -1 }; var more by pageState("more") { true }
    var busy by remember { mutableStateOf(false) }; var cloud by pageState("cloud") { false }; var error by remember { mutableStateOf(false) }
    var ascending by rememberSaveable { mutableStateOf(model.store.bool("key_bookmark_sort_order")) }; var menu by remember { mutableStateOf(false) }
    val list = rememberLazyListState(); val session = LocalPage.current
    fun fetch(refresh: Boolean) {
        if (busy) return
        val api = model.api; val uid = api.account?.uid.orEmpty(); val key = "key_bookmarks_list" + if (uid.isEmpty()) "" else "_$uid"
        val generation = model.accountGeneration
        busy = true; error = false
        scope.launch {
            try {
                if (uid.isEmpty()) { values = withContext(Dispatchers.IO) { savedRows(model.store, key) }; more = false; page = 0; return@launch }
                val next = if (refresh) 0 else page + 1
                suspend fun remote(): List<ThreadItem> {
                    val result = api.post("/c/f/post/threadstore", mapOf("rn" to "20", "offset" to "${next * 20}", "user_id" to uid))
                    require(result.optJSONArray("store_thread") != null) { "收藏列表格式无效" }
                    return api.threads(result, "store_thread")
                }
                var version = model.store.bookmarkVersion
                var rows = remote()
                if (refresh) {
                    val pending = model.store.list("key_bookmark_pending_adds_$uid") + model.store.list("key_bookmark_pending_removes_$uid")
                    if (pending.isNotEmpty()) {
                        try { model.syncBookmarks(api, rows.map { it.id }.toSet()); version = model.store.bookmarkVersion; rows = remote() }
                        catch (e: CancellationException) { throw e } catch (_: Exception) { model.message("云端同步未完成，待同步操作已保留") }
                    }
                }
                val moreRows = rows.size >= 20
                val local = withContext(Dispatchers.IO) { savedRows(model.store, key) }
                val localMap = local.associateBy { it.id }
                val removes = model.store.list("key_bookmark_pending_removes_$uid").toSet()
                val adds = model.store.list("key_bookmark_pending_adds_$uid").toSet()
                rows = rows.filterNot { it.id in removes }.map { remote ->
                    val cached = localMap[remote.id]
                    if (cached != null && (remote.segments.isEmpty() || cached.segments.any { it.link.isNotEmpty() } && remote.segments.none { it.link.isNotEmpty() })) ThreadItem.parse(JSONObject(remote.raw.toString()).removeSnippet().put("first_post_content", cached.raw.opt("first_post_content") ?: cached.raw.opt("content") ?: cached.raw.opt("abstract"))) else remote
                }
                if (!model.stillCurrent(generation)) return@launch
                if (version != model.store.bookmarkVersion) { values = savedRows(model.store, key); return@launch }
                values = ((if (refresh) emptyList() else values) + rows + local.filter { it.id in adds }).distinctBy { it.id }
                // A page is not an authoritative snapshot: keep all not-yet-fetched cached rows.
                withContext(Dispatchers.IO) { synchronized(model.store) {
                    if (version != model.store.bookmarkVersion) return@synchronized
                    val latest = savedRows(model.store, key)
                    val excluded = model.store.list("key_bookmark_pending_removes_$uid").toSet()
                    val cache = (values + latest).filterNot { it.id in excluded }.distinctBy { it.id }
                    model.store.put(key, cache.map { it.raw.toString() })
                } }
                page = next; more = moreRows; cloud = true
            } catch (e: CancellationException) { throw e }
            catch (_: Exception) { cloud = false; error = true; if (values.isEmpty()) values = withContext(Dispatchers.IO) { savedRows(model.store, key) }; model.message("云端同步失败，已展示本地缓存") }
            finally { busy = false }
        }
    }
    LaunchedEffect(Unit) { if (page < 0) fetch(true) }
    LaunchedEffect(session) { session.commands.collect { refresh -> list.animateScrollToItem(0); if (refresh) fetch(true) } }
    val revision = model.revision
    LaunchedEffect(revision) { if (page >= 0) { val ids = model.saved().map { it.id }.toSet(); values = values.filter { it.id in ids } } }
    Column {
        TopAppBar(colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent), modifier = Modifier.frostedTint(colors.background, colors.outlineVariant), title = { Column { Text("我的收藏", fontSize = 18.sp, fontWeight = FontWeight.Bold); Row(verticalAlignment = Alignment.CenterVertically) { Icon(if (cloud) Icons.Rounded.CloudDone else Icons.Rounded.PhoneAndroid, null, Modifier.size(12.dp), tint = if (cloud) colors.primary else colors.outline); Spacer(Modifier.width(4.dp)); Text(if (cloud) "已与百度贴吧官方云端同步" else "本地收藏 (未登录百度账号)", fontSize = 11.sp, color = if (cloud) colors.primary else colors.outline) } } }, navigationIcon = { IconButton(onClick = tapFeedback(back)) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "返回") } }, actions = {
            Box { IconButton(onClick = tapFeedback { menu = true }) { Icon(Icons.Rounded.Sort, "排序预览") }; DropdownMenu(menu, { menu = false }) { listOf(false, true).forEach { asc -> DropdownMenuItem(text = { Text(if (asc) "顺序预览（最早在前）" else "倒序预览（最新在前）") }, trailingIcon = { if (ascending == asc) Icon(Icons.Rounded.Check, null, Modifier.size(18.dp), tint = colors.primary) }, onClick = tapFeedback { ascending = asc; menu = false; model.setting("key_bookmark_sort_order", asc) }) } } }
        }, expandedHeight = 56.dp, windowInsets = WindowInsets.statusBars)
        OriginalRefreshBox(busy && page >= 0, { fetch(true) }, Modifier.fillMaxSize(), failed = error) {
            if (values.isEmpty() && busy) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            else if (values.isEmpty()) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { SavedEmptyState("暂无收藏的贴子", Icons.Rounded.BookmarkBorder, if (cloud) "您在贴吧官方客户端收藏的帖子将自动同步展现在这里" else "在浏览帖子时点击收藏，将自动保存在这里；登录后可双向同步官方云端收藏", bookmark = true) }
            else LazyColumn(state = list, contentPadding = PaddingValues(vertical = 8.dp)) {
                items(if (ascending) values.reversed() else values, key = { it.id }) { item ->
                    val dismiss = rememberSwipeToDismissBoxState()
                    LaunchedEffect(dismiss.currentValue) { if (dismiss.currentValue == SwipeToDismissBoxValue.EndToStart) { if (model.writing) dismiss.reset() else { values = values.filterNot { it.id == item.id }; model.bookmark(item, false) } } }
                    SwipeToDismissBox(state = dismiss, enableDismissFromStartToEnd = false, backgroundContent = { Box(Modifier.fillMaxSize().padding(horizontal = 10.dp, vertical = 4.dp).background(colors.errorContainer, RoundedCornerShape(20.dp)).padding(end = 24.dp), contentAlignment = Alignment.CenterEnd) { Icon(Icons.Outlined.Delete, "取消收藏", tint = colors.onErrorContainer) } }) { ThreadCard(item, recover = true) }
                }
                item {
                    Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                        if (busy) CircularProgressIndicator() else if (more || error) { if (!error && model.store.bool("key_habit_auto_load_more", true)) LaunchedEffect(page) { fetch(false) }; TextButton(onClick = tapFeedback { fetch(page < 0) }) { Text(if (error) "重试" else "加载更多") } }
                    }
                }
            }
        }
    }
}

@Composable
fun HistoryScreen(back: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current; val colors = MaterialTheme.colorScheme
    var tab by rememberSaveable { mutableIntStateOf(0) }; var clear by remember { mutableStateOf(false) }; val revision = model.revision
    val history = remember(revision) { savedRows(model.store, "key_browsing_history_list").reversed() }
    val forums = remember(revision) { model.store.list("key_forum_browsing_history_list").mapNotNull { runCatching { JSONObject(it) }.getOrNull() }.sortedByDescending { it.optLong("time") } }
    Column {
        FrostedHeading {
        PageBar("浏览记录", back, titleWeight = FontWeight.Bold, actions = { IconButton(onClick = tapFeedback { if (if (tab == 0) history.isNotEmpty() else forums.isNotEmpty()) clear = true }) { Icon(Icons.Rounded.DeleteSweep, "清空当前记录") } })
        OriginalTabBar(tab, listOf("帖子记录", "经过贴吧"), { tab = it })
        }
        OriginalTabs(tab, 2, { tab = it }) { tab ->
        if (tab == 0) { if (history.isEmpty()) SavedEmptyState("暂无帖子浏览记录", Icons.Rounded.History) else LazyColumn(contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp)) { items(history, key = { it.id }) { ThreadCard(it, recover = true) } } }
        else if (forums.isEmpty()) SavedEmptyState("暂无经过贴吧足迹", Icons.Outlined.Forum, "逛过的贴吧都会自动记录在这里")
        else LazyColumn(contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(forums, key = { it.s("name") }) { forum ->
                var avatar by remember { mutableStateOf(forum.s("avatar")) }
                LaunchedEffect(forum.s("name")) { if (avatar.isEmpty()) runCatching { model.api.forum(forum.s("name"), 1).obj("forum").s("avatar") }.onSuccess { avatar = it } }
                Card(onClick = tapFeedback { open(Route("forum", forum.s("name"))) }, shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = colors.surfaceContainerLow)) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(colors.surfaceContainerHighest), contentAlignment = Alignment.Center) { Text(forum.s("name").take(1), fontSize = 18.sp, color = colors.primary, fontWeight = FontWeight.Bold); if (avatar.isNotEmpty()) AsyncImage(avatar, null, Modifier.fillMaxSize()) }
                        Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text("${forum.s("name").removeSuffix("吧")}吧", fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1); if (forum.optLong("time") > 0) Text("最近经过：${relativeTime(forum.s("time"))}", Modifier.padding(top = 4.dp), fontSize = 12.sp, color = colors.outline) }
                        Icon(Icons.Rounded.ChevronRight, null, tint = colors.outline.copy(alpha = .6f))
                    }
                }
            }
        }
    }
    }
    if (clear) OriginalConfirmation(if (tab == 0) "清空帖子浏览记录" else "清空经过贴吧足迹", if (tab == 0) "确定要清空全部看过的帖子历史吗？" else "确定要清空全部进入过的贴吧历史吗？", "清空", { clear = false }) { model.setting(if (tab == 0) "key_browsing_history_list" else "key_forum_browsing_history_list", emptyList<String>()); clear = false }
}

@Composable
private fun SavedEmptyState(message: String, icon: androidx.compose.ui.graphics.vector.ImageVector, detail: String = "", bookmark: Boolean = false) {
    val colors = MaterialTheme.colorScheme
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(Modifier.padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(icon, null, Modifier.size(64.dp), tint = colors.outline.copy(alpha = .5f))
            Spacer(Modifier.height(16.dp))
            Text(message, fontSize = 15.sp, fontWeight = if (bookmark) FontWeight.Medium else FontWeight.Normal, color = colors.outline)
            if (detail.isNotEmpty()) {
                Spacer(Modifier.height(if (bookmark) 8.dp else 6.dp))
                Text(detail, fontSize = if (bookmark) 13.sp else 12.5.sp, lineHeight = if (bookmark) 1.4.em else 1.428571.em, color = colors.outline.copy(alpha = .7f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
    }
}

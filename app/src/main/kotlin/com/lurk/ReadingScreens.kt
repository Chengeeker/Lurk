package com.lurk

import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import android.content.Intent
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.scrollable
import androidx.compose.foundation.gestures.rememberScrollableState
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.shape.CircleShape
import coil.compose.AsyncImage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import org.json.JSONArray
import org.json.JSONObject

@Composable
fun RichText(segments: List<Segment>, modifier: Modifier = Modifier, preview: Boolean = false, fontSize: Float = 15f, height: Float? = 1.55f) {
    val haptics = LocalHapticFeedback.current
    val open = LocalOpen.current
    val color = MaterialTheme.colorScheme.primary
    val inline = mutableMapOf<String, InlineTextContent>()
    val text = buildAnnotatedString {
        fun emoji(label: String, url: String) {
            val key = "emoji:${inline.size}"
            val size = if (preview) 18.225.sp else (fontSize * 1.35f).coerceIn(18f, 24f).sp
            inline[key] = InlineTextContent(Placeholder((size.value + 3).sp, size, PlaceholderVerticalAlign.Center)) { AsyncImage(url, label, Modifier.fillMaxSize().padding(horizontal = 1.5.dp)) }
            appendInlineContent(key, label)
        }
        fun link(label: String, route: Route, underline: Boolean = false) {
            withLink(LinkAnnotation.Clickable(label, TextLinkStyles(SpanStyle(color = color, textDecoration = if (underline) TextDecoration.Underline else null))) {
                haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
                open(route)
            }) { append(label) }
        }
        segments.filter { it.media == null }.forEach { segment ->
            if (segment.emoji.isNotEmpty()) emoji(segment.text, segment.emoji)
            else if (segment.userId.isNotEmpty()) link(segment.text, Route("profile", segment.userId))
            else if (segment.link.isNotEmpty()) link(segment.link, Route("url", segment.link), true)
            else {
                val raw = plainText(segment.text, false)
                var offset = 0
                Regex("https?://[^\\s<>]+|@[a-zA-Z0-9_\\u4e00-\\u9fa5]+|#[^#\\n]+#|#\\([^\\n)]+\\)|\\[[^\\n\\]]+\\]|image[_ ]emoticon\\s*\\d*", RegexOption.IGNORE_CASE).findAll(raw).forEach { match ->
                    append(raw.substring(offset, match.range.first))
                    val token = match.value
                    when {
                        token.startsWith("http", true) -> { val url = targetUrl(token); if (url.isEmpty()) append(token) else link(url, Route("url", url), true) }
                        token.startsWith("@") -> link(token, Route("search", extra = token.drop(1)))
                        token.startsWith("#") && token.endsWith("#") -> link(token, Route("search", extra = token.trim('#')))
                        isEmoji(token) -> emoji(token, emojiUrl(token))
                        else -> append(unicodeEmoji[token] ?: token)
                    }
                    offset = match.range.last + 1
                }
                append(raw.substring(offset))
            }
        }
    }
    val links = segments.any { it.link.isNotEmpty() || it.text.contains("http", true) }
    if (text.isNotBlank()) SelectionContainer { Text(text, modifier,
        style = if (preview) MaterialTheme.typography.bodyMedium.copy(fontSize = 13.5.sp, lineHeight = 1.45.em, color = MaterialTheme.colorScheme.onSurfaceVariant) else MaterialTheme.typography.bodyLarge.copy(fontSize = fontSize.sp, lineHeight = height?.em ?: androidx.compose.ui.unit.TextUnit.Unspecified),
        maxLines = if (preview && !links) 3 else Int.MAX_VALUE, inlineContent = inline, overflow = if (preview && !links) androidx.compose.ui.text.style.TextOverflow.Ellipsis else androidx.compose.ui.text.style.TextOverflow.Clip) }
}

@Composable
fun AuthorRow(author: Author, detail: String = "", compact: Boolean = false, top: Boolean = false) {
    val open = LocalOpen.current
    Row(Modifier.fillMaxWidth().feedbackClickable { if (author.id.isNotEmpty()) open(Route("profile", author.id)) }.padding(vertical = if (compact) 0.dp else 6.dp), verticalAlignment = Alignment.CenterVertically) {
        OriginalAvatar(portraitUrl(author.portrait), "${author.name}的头像", Modifier.size(38.dp).clip(CircleShape))
        Column(Modifier.weight(1f).padding(start = 10.dp)) {
            Text(author.name, fontSize = 13.5.sp, fontWeight = FontWeight.Bold)
            if (detail.isNotEmpty() || author.ip.isNotEmpty()) Text(listOf(detail, author.ip.removePrefix("来自").trim().let { if (it.isEmpty()) "" else "来自$it" }).filter { it.isNotEmpty() }.joinToString(" · "), Modifier.padding(top = 1.5.dp), fontSize = 11.sp, color = MaterialTheme.colorScheme.outline)
        }
        if (top) Surface(color = MaterialTheme.colorScheme.errorContainer, shape = RoundedCornerShape(4.dp)) { Text("置顶", Modifier.padding(horizontal = 6.dp, vertical = 2.dp), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onErrorContainer) }
        else if (!compact && author.level.isNotEmpty()) Text("Lv.${author.level}", style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
fun MediaGrid(media: List<Media>) {
    val galleryScope = remember { Any() }
    val model = LocalState.current
    if (media.isEmpty()) return
    if (model.store.int("key_habit_image_load_mode") in listOf(1, 3)) return
    val columns = if (media.size == 1) 1 else if (media.size == 2 || media.size == 4) 2 else 3
    if (media.size == 1) {
        val item = media.first()
        val ratio = if (item.width > 0 && item.height > 0) item.width.toFloat() / item.height else 1.5f
        val width = minOf(300f, 280f * ratio)
        GalleryThumbnail(galleryScope, media, 0, 12, item.original.ifEmpty { item.thumbnail },
            Modifier.widthIn(max = width.dp).fillMaxWidth().aspectRatio(ratio).clip(RoundedCornerShape(12.dp))) {
            if (item.isVideo) Icon(Icons.Outlined.PlayCircle, "播放视频", Modifier.align(Alignment.Center).size(48.dp))
        }
        return
    }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        media.take(9).chunked(columns).forEachIndexed { row, items ->
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                items.forEachIndexed { col, item ->
                    val url = if (model.store.int("key_habit_image_load_mode") == 2) item.original.ifEmpty { item.thumbnail } else item.thumbnail.ifEmpty { item.original }
                    GalleryThumbnail(galleryScope, media, row * columns + col, 8, url,
                        Modifier.weight(1f).aspectRatio(1f).clip(RoundedCornerShape(8.dp)).background(MaterialTheme.colorScheme.surfaceContainer)) {
                        if (item.isVideo) Icon(Icons.Outlined.PlayCircle, "播放视频", Modifier.align(Alignment.Center).size(40.dp))
                    }
                }
                repeat(columns - items.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
fun ThreadCard(source: ThreadItem, recover: Boolean = false, filterRecommendation: Boolean = false) {
    val model = LocalState.current
    var item by remember(source) { mutableStateOf(source) }
    LaunchedEffect(source.id, recover) { if (recover) item = model.recoverPreview(source) }
    val open = LocalOpen.current
    val context = LocalContext.current
    val revision = model.revision
    val agreement = model.agrees[item.id] ?: (item.agreed to (item.agrees.toIntOrNull() ?: 0))
    val colors = MaterialTheme.colorScheme
    if (filterRecommendation && model.store.blocked(item, model.followedNames ?: emptySet())) return
    OriginalListCard(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 4.dp)) {
        Column(Modifier.fillMaxWidth().feedbackClickable {
            model.recordHistory(item)
            open(Route("thread", item.id, item.postId))
        }.padding(start = 14.dp, top = 12.dp, end = 14.dp, bottom = 8.dp)) {
            AuthorRow(item.author, relativeTime(item.raw.s("create_time", "createTime", "time")), compact = true, top = item.raw.flag("is_top") || item.raw.flag("isTop"))
            Spacer(Modifier.height(10.dp))
            if (item.title.isNotEmpty()) Text(plainText(item.title), fontSize = 15.5.sp, lineHeight = 1.35.em, fontWeight = FontWeight.Bold, maxLines = 2, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            if (item.segments.any { it.text.isNotBlank() } && item.segments.joinToString("") { it.text } != item.title) RichText(item.segments, Modifier.padding(top = 4.dp), preview = true)
            if (item.media.isNotEmpty() && model.store.int("key_habit_image_load_mode") !in listOf(1, 3)) { Spacer(Modifier.height(8.dp)); MediaGrid(item.media.map { it.copy(folderName = item.author.name, threadId = item.id, title = item.title, fromThreadPreview = true) }) }
            if (item.forum.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                Row(Modifier.clip(RoundedCornerShape(6.dp)).feedbackClickable { open(Route("forum", item.forum)) }.padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    val avatar = item.raw.s("forumAvatar", "forum_avatar").ifEmpty { item.raw.obj("forum").s("avatar") }
                    if (avatar.isNotEmpty()) { AsyncImage(avatar, null, Modifier.size(15.dp).clip(RoundedCornerShape(3.dp))); Spacer(Modifier.width(5.dp)) }
                    else Icon(Icons.Outlined.Forum, null, Modifier.size(13.dp), tint = colors.outline)
                    Text("${item.forum.removeSuffix("吧")}吧", fontSize = 11.5.sp, fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
                }
            }
            Spacer(Modifier.height(8.dp)); OriginalDivider(thickness = .5.dp, color = colors.outlineVariant.copy(alpha = .08f)); Spacer(Modifier.height(4.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                CardAction(Icons.Outlined.Share, "分享", colors.outline) { runCatching { context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "${item.title}\nhttps://tieba.baidu.com/p/${item.id}"), "分享")) }.onFailure { model.message("无法打开分享菜单") } }
                CardAction(Icons.Rounded.ChatBubbleOutline, item.replies.takeUnless { it.isEmpty() || it == "0" } ?: "回复", colors.outline) { open(Route("thread", item.id, item.postId)) }
                CardAction(if (agreement.first) Icons.Filled.Favorite else Icons.Rounded.FavoriteBorder, if (agreement.second > 0) "${agreement.second}" else "赞", if (agreement.first) Color(0xFFFF5252) else colors.outline) { model.toggleAgree(item) }
            }
        }
    }
}

@Composable
fun RowScope.CardAction(icon: ImageVector, title: String, color: Color, click: () -> Unit) {
    Row(Modifier.weight(1f).clip(RoundedCornerShape(16.dp)).feedbackClickable(onClick = click).padding(vertical = 6.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) { Icon(icon, title, Modifier.size(17.dp), tint = color); Spacer(Modifier.width(6.dp)); Text(title, fontSize = 12.5.sp, color = color) }
}

fun relativeTime(raw: String): String {
    val timestamp = raw.toLongOrNull()?.takeIf { it > 0 } ?: return ""
    val seconds = if (timestamp > 100000000000L) timestamp / 1000 else timestamp
    val delta = System.currentTimeMillis() / 1000 - seconds
    return when { delta < 60 -> "${delta.coerceAtLeast(1)}秒前"; delta < 3600 -> "${delta / 60}分钟前"; delta < 86400 -> "${delta / 3600}小时前"; delta < 2592000 -> "${delta / 86400}天前"; else -> java.text.SimpleDateFormat("MM-dd", java.util.Locale.ROOT).format(java.util.Date(seconds * 1000)) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> PagedContent(
    identity: Any?, load: suspend (Int) -> Pair<List<T>, Boolean>, modifier: Modifier = Modifier,
    targetId: String = "", bottomPadding: Int = 80, emptyMessage: String = "暂无内容", topPadding: Int = 0,
    emptyState: (@Composable (Boolean, String?, () -> Unit) -> Unit)? = null,
    header: (@Composable LazyItemScope.() -> Unit)? = null, item: @Composable (T) -> Unit,
) {
    val model = LocalState.current
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()
    val state by pageState("items:$identity") { PageItems<T>() }
    var values by state::items
    var page by state::number
    var more by state::more
    var busy by remember(identity) { mutableStateOf(false) }
    var refreshing by remember(identity) { mutableStateOf(false) }
    var updated by remember(identity) { mutableLongStateOf(System.currentTimeMillis()) }
    var error by remember(identity) { mutableStateOf<String?>(null) }
    val currentLoad by rememberUpdatedState(load)
    fun fetch(refresh: Boolean) {
        if (busy) return
        busy = true; refreshing = refresh && page > 0; error = null
        scope.launch {
            try {
                val target = if (refresh) 1 else page + 1
                val result = currentLoad(target)
                values = (if (refresh) result.first else values + result.first).distinctBy {
                    when (it) { is ThreadItem -> it.id + ":" + it.postId; is Forum -> it.id; is JSONObject -> it.s("id", "pid", "post_id", "tid").ifEmpty { it.toString() }; else -> it }
                }
                page = target; more = result.second; updated = System.currentTimeMillis()
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) { error = if (e is ApiFailure) e.message else "加载失败，请重试" }
            finally { busy = false; refreshing = false }
        }
    }
    LaunchedEffect(identity) { if (page == 0) fetch(true) }
    val session = LocalPage.current
    val invalidation = session.invalidation
    LaunchedEffect(invalidation) { if (invalidation > 0) { listState.scrollToItem(0); fetch(true) } }
    val active by rememberUpdatedState(LocalPageActive.current)
    LaunchedEffect(session, identity) { session.commands.collect { refresh -> if (active) { listState.animateScrollToItem(0); if (refresh) fetch(true) } } }
    var previousPosition by pageState("previousScroll:$identity") { 0 to 0 }
    LaunchedEffect(session, identity) { session.timelineToggle.collect {
        if (!active) return@collect
        if (listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 50) {
            previousPosition = listState.firstVisibleItemIndex to listState.firstVisibleItemScrollOffset
            listState.animateScrollToItem(0)
        } else if (previousPosition.first > 0 || previousPosition.second > 50) listState.animateScrollToItem(previousPosition.first, previousPosition.second)
    } }
    var targetLocated by rememberSaveable(identity) { mutableStateOf(false) }
    LaunchedEffect(values.size, targetId) {
        if (!targetLocated && targetId.isNotEmpty() && targetId != "0") {
            val index = values.indexOfFirst { it is JSONObject && it.s("id") == targetId }
            if (index >= 0) { targetLocated = true; listState.animateScrollToItem(index + if (header != null) 1 else 0) }
        }
    }
    OriginalRefreshBox(isRefreshing = refreshing, onRefresh = { fetch(true) }, modifier = modifier.fillMaxSize(), failed = error != null) {
    if (header == null && values.isEmpty()) Box(Modifier.fillMaxSize().padding(top = LocalContentTop.current).scrollable(rememberScrollableState { 0f }, Orientation.Vertical), contentAlignment = Alignment.Center) {
        if (emptyState != null) emptyState(busy, error) { fetch(true) }
        else if (busy) CircularProgressIndicator()
        else Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(error ?: emptyMessage, fontSize = 13.5.sp, color = MaterialTheme.colorScheme.outline)
            if (error != null) TextButton(onClick = tapFeedback { fetch(true) }) { Text("重试") }
        }
    } else LazyColumn(Modifier.fillMaxSize(), state = listState, contentPadding = PaddingValues(top = LocalContentTop.current + topPadding.dp, bottom = bottomPadding.dp)) {
        header?.let { item(content = it) }
        items(values.size) { index -> item(values[index]) }
        item {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                if (busy) { if (page == 0) CircularProgressIndicator() else OriginalRefreshIndicator(ClassicPhase.Loading, updated, footer = true) }
                error?.let { OriginalRefreshIndicator(ClassicPhase.Failed, updated, footer = true); Text(it); TextButton(onClick = tapFeedback { fetch(page == 0) }) { Text("重试") } }
                if (!busy && error == null) {
                    if (values.isEmpty()) { Text(emptyMessage, color = MaterialTheme.colorScheme.outline); if (more) TextButton(onClick = tapFeedback { fetch(false) }) { Text("加载更多") } }
                    else if (more) {
                        if (model.store.bool("key_habit_auto_load_more", true)) LaunchedEffect(page) { fetch(false) }
                        TextButton(onClick = tapFeedback { fetch(false) }) { Text("加载更多") }
                    } else OriginalRefreshIndicator(ClassicPhase.NoMore, updated, footer = true)
                }
            }
        }
    }
    }
}

@Composable
fun FeedScreen() {
    val model = LocalState.current; val open = LocalOpen.current
    var section by rememberSaveable { mutableIntStateOf(1) }
    FrostedFrame(104.dp, header = { Column {
        PageBar("动态", titleWeight = FontWeight.Bold, actions = { IconButton(onClick = tapFeedback { open(Route("search")) }) { Icon(Icons.Rounded.Search, "搜索") } })
        OriginalTabBar(section, listOf("关注", "推荐", "热榜"), { section = it }, MaterialTheme.typography.titleSmall.copy(fontSize = 15.sp, fontWeight = FontWeight.Bold), MaterialTheme.typography.titleSmall.copy(fontSize = 14.sp, fontWeight = FontWeight.Normal))
    } }) {
        OriginalTabs(section, 3, { section = it }) { section -> key(section) {
            if (section == 0 && model.account == null) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(Modifier.padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Rounded.PersonOutline, null, Modifier.size(64.dp), tint = MaterialTheme.colorScheme.outline)
                    Spacer(Modifier.height(16.dp)); Text("登录后查看关注的人动态", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp)); Text("登录百度贴吧账号，随时掌握关注好友的最新发布", fontSize = 13.sp, color = MaterialTheme.colorScheme.outline, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                    Spacer(Modifier.height(20.dp)); FilledTonalButton(onClick = tapFeedback { open(Route("login")) }) { Icon(Icons.Rounded.Login, null); Spacer(Modifier.width(8.dp)); Text("立即登录") }
                }
            }
            else if (section == 2) PagedContent(identity = section, topPadding = 8, emptyState = { _, error, retry -> FeedEmptyState(false, error, retry) }, load = {
                model.api.web("/hottopic/browse/topicList").obj("data").obj("bang_topic").rows("topic_list").mapIndexed { index, topic -> topic.put("rank", index + 1) } to false
            }) { topic -> HotTopic(topic) }
            else PagedContent(identity = section, topPadding = 4, emptyState = { _, error, retry -> FeedEmptyState(section == 0, error, retry) }, load = { page ->
                val api = model.api
                val threads = if (section == 1) api.threads(api.post("/c/f/excellent/personalized", mapOf("pn" to "$page", "load_type" to if (page == 1) "1" else "2", "page_thread_count" to "15", "need_forumlist" to "1")))
                else {
                    require(model.account != null) { "请先登录" }
                    val users = api.post("/c/u/follow/page", mapOf("uid" to model.account!!.uid, "pn" to "$page", "rn" to "20")).rows("user_list")
                    val lanes = Semaphore(3)
                    coroutineScope { users.take(10).map { user -> async { lanes.withPermit {
                        try { api.threads(api.post("/c/u/feed/userpost", mapOf("uid" to user.s("id", "user_id"), "pn" to "1", "rn" to "5", "is_thread" to "1", "need_content" to "1")), "post_list") }
                        catch (e: CancellationException) { throw e } catch (_: Exception) { emptyList() }
                    } } }.awaitAll().flatten().sortedByDescending { it.raw.s("create_time", "createTime").toLongOrNull() ?: 0 } }
                }
                if (model.store.bool("key_recommend_followed_only") && model.account != null && model.followedNames == null) model.loadFollowed(api)
                threads.distinctBy { it.id } to threads.isNotEmpty()
            }) { ThreadCard(it, filterRecommendation = section == 1) }
        } }
    }
}

@Composable
fun LoginPrompt() { val open = LocalOpen.current; Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Button(onClick = tapFeedback { open(Route("login")) }) { Text("登录账号") } } }




@Composable
fun HotTopic(topic: JSONObject) {
    val open = LocalOpen.current; val colors = MaterialTheme.colorScheme; val rank = topic.optInt("rank")
    val rankColor = when (rank) { 1 -> Color(0xFFE53935); 2 -> Color(0xFFFF6D00); 3 -> Color(0xFFFBC02D); else -> colors.outline.copy(alpha = .65f) }
    Row(Modifier.fillMaxWidth().feedbackClickable { open(Route("url", topic.s("topic_url"))) }.padding(horizontal = 16.dp, vertical = 12.dp)) {
        Text("$rank", Modifier.width(28.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center, fontSize = 16.sp, fontWeight = FontWeight.Black, fontStyle = if (rank <= 3) androidx.compose.ui.text.font.FontStyle.Italic else androidx.compose.ui.text.font.FontStyle.Normal, color = rankColor)
        Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) {
            Text(topic.s("topic_name"), fontSize = 15.sp, lineHeight = 1.35.em, fontWeight = FontWeight.Bold, maxLines = 2, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            if (topic.s("topic_desc", "abstract").isNotEmpty()) Text(topic.s("topic_desc", "abstract"), Modifier.padding(top = 4.dp), fontSize = 12.5.sp, lineHeight = 1.35.em, color = colors.outline, maxLines = 2, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            Spacer(Modifier.height(6.dp)); Row(verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Rounded.LocalFireDepartment, null, Modifier.size(15.dp), tint = Color(0xFFFF6E40)); Spacer(Modifier.width(3.dp)); val count = topic.optLong("discuss_num"); Text(if (count >= 10000) "${String.format(java.util.Locale.ROOT, "%.1f", count / 10000.0)}万讨论" else "${count}讨论", fontSize = 11.5.sp, fontWeight = FontWeight.Medium, color = colors.outline) }
        }
        val image = topic.s("topic_pic", "topic_avatar", "topic_default_avatar")
        if (image.isNotEmpty()) { Spacer(Modifier.width(12.dp)); AsyncImage(image, null, Modifier.size(76.dp, 56.dp).clip(RoundedCornerShape(8.dp)), contentScale = androidx.compose.ui.layout.ContentScale.Crop) }
    }
}



@Composable
fun FeedEmptyState(following: Boolean, error: String?, retry: () -> Unit) {
    if (error == null) return
    val colors = MaterialTheme.colorScheme
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(if (following) Icons.Outlined.Info else Icons.Rounded.ErrorOutline, null, Modifier.size(48.dp), tint = if (following) colors.outline else colors.error)
        Spacer(Modifier.height(12.dp)); Text(error, color = colors.outline)
        Spacer(Modifier.height(16.dp)); FilledTonalButton(onClick = tapFeedback(retry)) { Text(if (following) "刷新" else "重试") }
    }
}

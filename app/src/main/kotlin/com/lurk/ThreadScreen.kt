@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.lurk

import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.automirrored.outlined.Reply
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import coil.compose.AsyncImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

fun resolvePostAuthors(data: JSONObject, key: String = "post_list"): List<JSONObject> {
    val users = data.rows("user_list").associateBy { it.s("id") }
    fun attach(post: JSONObject) {
        val author = Author.parse(post.optJSONObject("author") ?: post.optJSONObject("user") ?: JSONObject(), users, post.s("author_id", "authorId"))
        post.put("author", JSONObject().put("id", author.id).put("name_show", author.name).put("portrait", author.portrait).put("level_id", author.level).put("ip_address", author.ip))
    }
    return data.rows(key).onEach { post -> attach(post); post.obj("sub_post_list").rows("sub_post_list").forEach(::attach) }
}

suspend fun NativeApi.deletePost(tid: String, pid: String, forum: JSONObject, thread: Boolean = false) {
    val name = forum.s("name").removeSuffix("吧").trim()
    val fid = forum.s("id").takeUnless { it.isEmpty() || it == "0" } ?: if (name.isNotEmpty()) forum(name, 1).obj("forum").s("id") else ""
    require(fid.isNotEmpty() && fid != "0" && name.isNotEmpty()) { "缺少吧信息，无法删除" }
    val args = mapOf("fid" to fid, "word" to name, "z" to tid, "src" to "1", "is_vipdel" to "0") +
        if (thread) mapOf("delete_my_thread" to "1", "is_frs_mask" to "0") else mapOf("pid" to pid, "isfloor" to "0", "delete_my_post" to "1")
    write(if (thread) "/c/c/bawu/delthread" else "/c/c/bawu/delpost", args)
}

fun ownsPost(account: Account?, author: Author): Boolean = account != null && ((author.id.isNotEmpty() && author.id != "0" && account.uid == author.id) || (author.portrait.isNotEmpty() && account.raw.s("portrait") == author.portrait) || (author.name != "贴吧吧友" && author.name in listOf(account.name, account.raw.s("name"))))

@Composable
fun LevelBadge(level: String, profile: Boolean = false) {
    val n = level.toIntOrNull() ?: 1
    val color = when { n >= 16 -> Color(0xFFFF5252); n >= 10 -> Color(0xFFE67E22); n >= 4 -> Color(0xFF2E86DE); else -> Color(0xFF16A085) }
    Surface(color = color, shape = RoundedCornerShape(10.dp), modifier = Modifier.padding(start = if (profile) 8.dp else 6.dp)) { Text(if (profile) "Lv.$n" else "$n", Modifier.padding(horizontal = if (profile) 6.dp else 5.dp, vertical = if (profile) 1.5.dp else 1.dp), fontSize = if (profile) 10.sp else 9.5.sp, lineHeight = 1.1.em, fontWeight = FontWeight.Bold, color = Color.White) }
}

@Composable
fun ReplyInput(text: String, change: (String) -> Unit, hint: String, target: String = "", clearTarget: () -> Unit = {}, send: () -> Unit) {
    val model = LocalState.current; val colors = MaterialTheme.colorScheme
    val keyboard = LocalSoftwareKeyboardController.current
    Surface(color = colors.surface) {
        Column {
            OriginalDivider(color = colors.outlineVariant.copy(alpha = .3f))
            Row(Modifier.fillMaxWidth().imePadding().padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                if (target.isNotEmpty()) { InputChip(selected = false, onClick = tapFeedback(clearTarget), label = { Text("@$target", fontSize = 11.5.sp, maxLines = 1) }, trailingIcon = { Icon(Icons.Outlined.Close, "取消回复目标", Modifier.size(14.dp)) }, modifier = Modifier.widthIn(max = 120.dp)); Spacer(Modifier.width(6.dp)) }
                Box(Modifier.weight(1f).height(40.dp).background(colors.surfaceContainerHighest, RoundedCornerShape(20.dp)).padding(horizontal = 14.dp), contentAlignment = Alignment.CenterStart) {
                    BasicTextField(text, change, Modifier.fillMaxWidth(), enabled = !model.writing, singleLine = true, textStyle = TextStyle(fontSize = 14.sp, color = colors.onSurface), keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send), keyboardActions = KeyboardActions(onSend = { keyboard?.hide(); send() }), decorationBox = { input -> if (text.isEmpty()) Text(if (model.writing) "正在发送中..." else hint, fontSize = 13.5.sp, color = colors.outline); input() })
                }
                Spacer(Modifier.width(8.dp)); FilledIconButton(onClick = tapFeedback { keyboard?.hide(); send() }, enabled = !model.writing) { if (model.writing) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = colors.onPrimary) else Icon(Icons.AutoMirrored.Rounded.Send, "发送", Modifier.size(18.dp)) }
            }
        }
    }
}

@Composable
private fun PostImage(galleryScope: Any, media: List<Media>, index: Int, maxHeight: Int, radius: Int) {
    val item = media[index]
    GalleryThumbnail(galleryScope, media, index, radius, item.original.ifEmpty { item.thumbnail },
        Modifier.padding(vertical = 4.dp).heightIn(max = maxHeight.dp).clip(RoundedCornerShape(radius.dp)), crop = false) {
        if (item.isVideo) Icon(Icons.Outlined.PlayCircle, "播放视频", Modifier.align(Alignment.Center).size(48.dp))
    }
}

@Composable
fun PostContent(content: List<Segment>, author: String, main: Boolean = false) {
    val galleryScope = remember { Any() }
    val hideImages = LocalState.current.store.int("key_habit_image_load_mode") in listOf(1, 3)
    val media = if (hideImages) emptyList() else content.mapNotNull { it.media?.copy(folderName = author) }
    if (main) {
        RichText(content, Modifier.padding(top = 3.dp, bottom = if (media.isNotEmpty()) 13.dp else 3.dp))
        media.indices.forEach { PostImage(galleryScope, media, it, 400, 12) }
    } else {
        val groups = mutableListOf<List<Segment>>(); var text = mutableListOf<Segment>()
        content.forEach { segment -> if (segment.media != null) { if (text.isNotEmpty()) groups.add(text); text = mutableListOf(); groups.add(listOf(segment)) } else text.add(segment) }
        if (text.isNotEmpty()) groups.add(text)
        var index = 0
        groups.forEach { group -> if (group.first().media != null) { if (!hideImages) PostImage(galleryScope, media, index++, 280, 8) } else RichText(group, Modifier.padding(vertical = 2.dp), fontSize = 14f, height = 1.45f) }
    }
}

@Composable
fun ThreadScreen(tid: String, targetPid: String, back: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current; val colors = MaterialTheme.colorScheme
    var lz by rememberSaveable { mutableStateOf(false) }; var reverse by rememberSaveable { mutableStateOf(false) }
    var refresh by rememberSaveable { mutableIntStateOf(0) }; var reply by rememberSaveable { mutableStateOf("") }
    var thread by pageState("thread") { JSONObject() }; var forum by pageState("forum") { JSONObject() }; var first by pageState("first") { JSONObject() }
    var count by pageState("count") { 0 }
    var floor by remember { mutableStateOf<JSONObject?>(null) }; var actions by remember { mutableStateOf<JSONObject?>(null) }; var delete by remember { mutableStateOf<JSONObject?>(null) }
    val revision = model.revision
    val author = Author.parse(first.optJSONObject("author") ?: thread.obj("author"))
    val item = ThreadItem.parse(JSONObject(thread.toString()).put("tid", tid).put("fname", forum.s("name")).put("first_post_content", first.opt("content")))
    val agreement = model.agrees[tid] ?: (item.agreed to (item.agrees.toIntOrNull() ?: 0))
    val ownThread = ownsPost(model.account, author)
    val bookmarked = model.saved().any { it.id == tid }
    FrostedFrame(header = {
        CenterAlignedTopAppBar(title = {
            if (forum.s("name").isNotEmpty()) Surface(onClick = tapFeedback { open(Route("forum", forum.s("name"))) }, shape = RoundedCornerShape(50), color = colors.surfaceContainerHighest) {
                Row(Modifier.padding(start = 4.dp, top = 4.dp, end = 14.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    OriginalAvatar(forum.s("avatar"), null, Modifier.size(32.dp).clip(CircleShape))
                    Spacer(Modifier.width(8.dp))
                    Text("${forum.s("name").removeSuffix("吧")}吧", Modifier.widthIn(max = (androidx.compose.ui.platform.LocalConfiguration.current.screenWidthDp - 230).coerceIn(72, 156).dp), fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }, navigationIcon = { IconButton(onClick = tapFeedback(back)) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "返回") } }, actions = {
            if (ownThread) IconButton(onClick = tapFeedback { delete = JSONObject(first.toString()).put("floor", 1) }) { Icon(Icons.Outlined.Delete, "删除我的贴子") }
            IconButton(onClick = tapFeedback { model.bookmark(item) }) { Icon(if (bookmarked) Icons.Filled.Bookmark else Icons.Rounded.BookmarkBorder, if (bookmarked) "取消收藏" else "收藏贴子", tint = if (bookmarked) Color(0xFFFFC107) else colors.onSurfaceVariant) }
        }, colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Color.Transparent), expandedHeight = 56.dp, windowInsets = WindowInsets.statusBars)
    }) {
        Box(Modifier.weight(1f)) { key(lz, reverse, refresh) { PagedContent(identity = "$lz:$reverse:$refresh", targetId = targetPid, bottomPadding = 32, load = { page ->
            val data = model.api.detail(tid, page, lz, reverse)
            thread = data.obj("thread"); forum = data.obj("forum")
            val posts = resolvePostAuthors(data)
            posts.firstOrNull { it.s("floor") == "1" }?.let { first = it }
            if (page == 1 && first.length() == 0 && reverse) first = resolvePostAuthors(model.api.detail(tid)).firstOrNull { it.s("floor") == "1" } ?: JSONObject()
            if (page == 1) withContext(Dispatchers.IO) { model.store.history(ThreadItem.parse(JSONObject(thread.toString()).put("tid", tid).put("fname", forum.s("name")).put("first_post_content", first.opt("content")))) }
            val comments = posts.filter { it.s("floor") != "1" }
            count = if (page == 1) comments.size else count + comments.size
            comments to data.obj("page").flag("has_more")
        }, header = {
            Card(Modifier.fillMaxWidth().padding(start = 12.dp, top = 12.dp, end = 12.dp, bottom = 4.dp), shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = colors.surfaceContainerLow)) {
                Column(Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OriginalAvatar(portraitUrl(author.portrait), "${author.name}的头像", Modifier.size(44.dp).clip(CircleShape).feedbackClickable { open(Route("profile", author.id)) }); Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) { Text(author.name, Modifier.weight(1f, false).feedbackClickable { open(Route("profile", author.id)) }, fontSize = 14.sp, fontWeight = FontWeight.Bold, maxLines = 1); LevelBadge(author.level); Spacer(Modifier.width(6.dp)); Surface(shape = RoundedCornerShape(4.dp), color = colors.primaryContainer) { Text("楼主", Modifier.padding(horizontal = 5.dp, vertical = 1.dp), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = colors.onPrimaryContainer) } }
                            val timestamp = first.s("time").ifEmpty { thread.s("create_time") }.toLongOrNull() ?: 0
                            val time = if (timestamp > 0) java.text.SimpleDateFormat("yyyy-MM-dd HH:mm", java.util.Locale.ROOT).format(java.util.Date(timestamp * 1000)) else ""
                            Text(listOf(time, author.ip.takeIf { it.isNotEmpty() }?.let { "来自$it" }.orEmpty()).filter(String::isNotEmpty).joinToString(" · ").ifEmpty { forum.s("name").let { if (it.isEmpty()) "百度贴吧" else "${it}吧" } }, Modifier.padding(top = 2.dp), fontSize = 11.5.sp, color = colors.outline)
                        }
                    }
                    Spacer(Modifier.height(14.dp)); if (thread.s("title").isNotEmpty()) { Text(plainText(thread.s("title")), fontSize = 19.sp, lineHeight = 1.35.em, fontWeight = FontWeight.Bold); Spacer(Modifier.height(12.dp)) }
                    PostContent(parseContent(first.opt("content")), author.name, true)
                    Spacer(Modifier.height(12.dp)); Row(Modifier.align(Alignment.End).clip(RoundedCornerShape(16.dp)).feedbackClickable { model.toggleAgree(item) }.padding(horizontal = 10.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) { Icon(if (agreement.first) Icons.Filled.Favorite else Icons.Rounded.FavoriteBorder, "点赞", Modifier.size(18.dp), tint = if (agreement.first) Color(0xFFFF5252) else colors.outline); Spacer(Modifier.width(4.dp)); Text(if (agreement.second > 0) "${agreement.second}" else "赞", fontSize = 12.5.sp, color = if (agreement.first) Color(0xFFFF5252) else colors.outline) }
                }
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("回复 ${if (count > 0) count else item.replies.ifEmpty { "0" }}", fontSize = 14.5.sp, fontWeight = FontWeight.Bold); Text("|", Modifier.padding(horizontal = 8.dp), fontSize = 13.sp, color = colors.outline.copy(alpha = .3f))
                Text("只看楼主", Modifier.height(48.dp).feedbackClickable { lz = !lz }.padding(horizontal = 4.dp).wrapContentHeight(Alignment.CenterVertically), fontSize = 13.5.sp, color = if (lz) colors.primary else colors.outline, fontWeight = if (lz) FontWeight.Bold else FontWeight.Normal)
                Spacer(Modifier.weight(1f)); Text("正序", Modifier.height(48.dp).feedbackClickable { reverse = false }.padding(horizontal = 4.dp).wrapContentHeight(Alignment.CenterVertically), fontSize = 13.5.sp, fontWeight = if (!reverse) FontWeight.Bold else FontWeight.Normal, color = if (!reverse) colors.onSurface else colors.outline); Text("|", Modifier.padding(horizontal = 8.dp), fontSize = 13.sp, color = colors.outline.copy(alpha = .3f)); Text("倒序", Modifier.height(48.dp).feedbackClickable { reverse = true }.padding(horizontal = 4.dp).wrapContentHeight(Alignment.CenterVertically), fontSize = 13.5.sp, fontWeight = if (reverse) FontWeight.Bold else FontWeight.Normal, color = if (reverse) colors.onSurface else colors.outline)
            }
        }) { post -> CommentFloor(tid, post, author.id, { floor = post }, { actions = post }) } } }
        ReplyInput(reply, { reply = it }, "说点什么吧...") {
            if (reply.isNotBlank()) model.action { api, _ -> api.reply(tid, forum.s("id"), forum.s("name"), reply.trim()); reply = ""; refresh++; model.message("回复成功") }
        }
    }
    actions?.let { post -> PostActions(post, ownsPost(model.account, Author.parse(post.obj("author"))) || ownThread, false, { actions = null }, { floor = post }, { delete = post }) }
    floor?.let { post -> FloorSheet(tid, forum, post, ownThread) { floor = null } }
    delete?.let { post -> val main = post.s("floor") == "1"; DeleteConfirmation(if (main) "删除贴子" else "删除评论", if (main) "确定要删除这篇贴子吗？删除后将无法恢复。" else "确定要删除这条回复吗？删除后将无法恢复。", { delete = null }) { model.action { api, _ -> api.deletePost(tid, post.s("id"), forum, main); delete = null; if (main) back() else refresh++ } } }
}

@Composable
fun CommentFloor(tid: String, post: JSONObject, authorId: String, reply: () -> Unit, actions: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current; val colors = MaterialTheme.colorScheme
    val author = Author.parse(post.obj("author"))
    val haptics = LocalHapticFeedback.current
    var liked by pageState("like:${post.s("id")}") { post.obj("agree").flag("has_agree") }
    var likes by pageState("likes:${post.s("id")}") { post.obj("agree").s("agree_num").toIntOrNull() ?: 0 }
    Row(Modifier.fillMaxWidth().combinedClickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null, hapticFeedbackEnabled = false, onClick = {}, onLongClick = { haptics.performHapticFeedback(HapticFeedbackType.LongPress); actions() }).padding(horizontal = 16.dp, vertical = 8.dp)) {
        OriginalAvatar(portraitUrl(author.portrait), "${author.name}的头像", Modifier.size(36.dp).clip(CircleShape).feedbackClickable { open(Route("profile", author.id)) }); Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) { Text(author.name, Modifier.weight(1f, false).feedbackClickable { open(Route("profile", author.id)) }, fontSize = 13.5.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis); LevelBadge(author.level); if (author.id == authorId) Text("楼主", Modifier.padding(start = 5.dp).background(Color(0x26FFC107), RoundedCornerShape(10.dp)).border(.6.dp, Color(0x99FFC107), RoundedCornerShape(10.dp)).padding(horizontal = 5.dp, vertical = 1.dp), fontSize = 9.sp, color = Color(0xFFFFC107), fontWeight = FontWeight.Bold) }
                Spacer(Modifier.width(8.dp))
                Row(Modifier.heightIn(min = 48.dp).widthIn(min = 48.dp).feedbackClickable { model.action { api, generation -> api.agree(tid, post.s("id"), !liked); if (model.stillCurrent(generation)) { likes = (likes + if (liked) -1 else 1).coerceAtLeast(0); liked = !liked } } }, verticalAlignment = Alignment.CenterVertically) { Icon(if (liked) Icons.Filled.Favorite else Icons.Rounded.FavoriteBorder, "点赞", Modifier.size(18.dp), tint = if (liked) Color(0xFFFF5252) else colors.outline); Spacer(Modifier.width(4.dp)); Text(if (likes > 0) "$likes" else "", Modifier.width(26.dp), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (liked) Color(0xFFFF5252) else colors.outline) }
                Spacer(Modifier.width(2.dp)); IconButton(onClick = tapFeedback(actions)) { Icon(Icons.Rounded.MoreHoriz, "更多操作", Modifier.size(18.dp), tint = colors.outline.copy(alpha = .7f)) }
            }
            Text(listOf(relativeTime(post.s("time")), "第 ${post.s("floor")} 楼", author.ip.takeIf(String::isNotEmpty)?.let { "来自$it" }.orEmpty()).filter(String::isNotEmpty).joinToString(" · "), Modifier.padding(top = 2.dp), fontSize = 11.5.sp, color = colors.outline)
            Spacer(Modifier.height(6.dp)); PostContent(parseContent(post.opt("content")), author.name)
            val sub = post.obj("sub_post_list"); val count = sub.s("sub_post_number").ifEmpty { post.s("sub_post_number") }.toIntOrNull() ?: 0
            if (count > 0) Surface(onClick = tapFeedback(reply), color = colors.surfaceContainerLow, shape = RoundedCornerShape(8.dp), modifier = Modifier.padding(top = 8.dp)) { Column(Modifier.fillMaxWidth().padding(8.dp)) {
                sub.rows("sub_post_list").take(2).forEach { row -> Text(androidx.compose.ui.text.buildAnnotatedString {
                    pushStyle(androidx.compose.ui.text.SpanStyle(color = colors.primary, fontWeight = FontWeight.Bold)); append("${Author.parse(row.obj("author")).name}: "); pop()
                    append(parseContent(row.opt("content")).joinToString("") { it.text })
                }, Modifier.padding(vertical = 1.dp), fontSize = 12.sp, color = colors.onSurfaceVariant, maxLines = if (row.toString().contains("http")) Int.MAX_VALUE else 2, overflow = if (row.toString().contains("http")) TextOverflow.Clip else TextOverflow.Ellipsis) }
                Spacer(Modifier.height(4.dp)); Text("共 $count 条回复 >", fontSize = 11.sp, color = colors.primary, fontWeight = FontWeight.Bold)
            } }
        }
    }
}

@Composable
fun PostActions(post: JSONObject, canDelete: Boolean, sub: Boolean, dismiss: () -> Unit, reply: () -> Unit, delete: () -> Unit) {
    val model = LocalState.current; val context = LocalContext.current; val colors = MaterialTheme.colorScheme
    ModalBottomSheet(sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), onDismissRequest = dismiss, dragHandle = null, containerColor = colors.surface, shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)) {
        Spacer(Modifier.height(8.dp))
        Box(Modifier.align(Alignment.CenterHorizontally).size(36.dp, 4.dp).background(colors.outlineVariant.copy(alpha = .5f), RoundedCornerShape(2.dp)))
        Spacer(Modifier.height(12.dp))
        ListItem(colors = ListItemDefaults.colors(containerColor = Color.Transparent), headlineContent = { Text(if (sub) "回复 @${Author.parse(post.obj("author")).name}" else "回复第 ${post.s("floor")} 楼") }, leadingContent = { Icon(Icons.AutoMirrored.Outlined.Reply, null) }, modifier = Modifier.feedbackClickable { dismiss(); reply() })
        ListItem(colors = ListItemDefaults.colors(containerColor = Color.Transparent), headlineContent = { Text("复制内容") }, leadingContent = { Icon(Icons.Outlined.ContentCopy, null) }, modifier = Modifier.feedbackClickable { dismiss(); val text = parseContent(post.opt("content")).joinToString("") { it.text }; if (text.isNotEmpty()) { (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("内容", text)); model.message("已复制到剪贴板") } })
        if (canDelete) ListItem(colors = ListItemDefaults.colors(containerColor = Color.Transparent), headlineContent = { Text(if (sub) "删除回复" else "删除评论", color = colors.error, fontWeight = FontWeight.Bold) }, leadingContent = { Icon(Icons.Outlined.Delete, null, tint = colors.error) }, modifier = Modifier.feedbackClickable { dismiss(); delete() })
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
fun DeleteConfirmation(title: String, text: String, dismiss: () -> Unit, delete: () -> Unit) = OriginalConfirmation(title, text, "删除", dismiss, delete)

@Composable
fun FloorSheet(tid: String, forum: JSONObject, post: JSONObject, ownThread: Boolean, dismiss: () -> Unit) {
    val model = LocalState.current; val colors = MaterialTheme.colorScheme
    val haptics = LocalHapticFeedback.current
    var target by remember { mutableStateOf<JSONObject?>(null) }; var actions by remember { mutableStateOf<JSONObject?>(null) }; var delete by remember { mutableStateOf<JSONObject?>(null) }
    var text by rememberSaveable { mutableStateOf("") }; var refresh by remember { mutableIntStateOf(0) }; var count by remember { mutableIntStateOf(0) }
    val page = remember { PageSession() }
    ModalBottomSheet(sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), onDismissRequest = dismiss, dragHandle = null, shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp), containerColor = colors.surface) {
        CompositionLocalProvider(LocalPage provides page) {
            Column(Modifier.fillMaxHeight(.82f)) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) { Text("${post.s("floor")} 楼的回复 ($count)", Modifier.weight(1f), fontSize = 16.sp, fontWeight = FontWeight.Bold); IconButton(onClick = tapFeedback(dismiss)) { Icon(Icons.Rounded.Close, "关闭") } }
                OriginalDivider()
                Box(Modifier.weight(1f)) { key(refresh) { PagedContent(identity = refresh, bottomPadding = 16, emptyMessage = "暂无更多楼中楼回复", load = { number ->
                    val data = model.api.post("/c/f/pb/floor", mapOf("kz" to tid, "pid" to post.s("id"), "pn" to "$number"))
                    val rows = resolvePostAuthors(data, "subpost_list"); count = if (number == 1) rows.size else count + rows.size
                    rows to data.obj("page").flag("has_more")
                }) { row ->
                    val author = Author.parse(row.obj("author"))
                    Row(Modifier.fillMaxWidth().combinedClickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null, hapticFeedbackEnabled = false, onClick = {}, onLongClick = { haptics.performHapticFeedback(HapticFeedbackType.LongPress); actions = row }).padding(horizontal = 16.dp, vertical = 4.dp)) {
                        OriginalAvatar(portraitUrl(author.portrait), author.name, Modifier.size(32.dp).clip(CircleShape)); Spacer(Modifier.width(8.dp))
                        Column(Modifier.weight(1f)) { Row(verticalAlignment = Alignment.CenterVertically) { Text(author.name, Modifier.weight(1f), fontSize = 12.5.sp, fontWeight = FontWeight.Bold, maxLines = 1); Text(relativeTime(row.s("time")), fontSize = 11.sp, color = colors.outline); IconButton(onClick = tapFeedback { actions = row }, modifier = Modifier.size(32.dp)) { Icon(Icons.Rounded.MoreHoriz, "更多操作", Modifier.size(16.dp)) } }; Spacer(Modifier.height(4.dp)); RichText(parseContent(row.opt("content")), fontSize = 13f, height = null); OriginalDivider(Modifier.padding(vertical = 8.dp)) }
                    }
                } } }
                ReplyInput(text, { text = it }, target?.let { "回复 @${Author.parse(it.obj("author")).name}..." } ?: "回复 ${post.s("floor")} 楼...", target?.let { Author.parse(it.obj("author")).name }.orEmpty(), { target = null }) {
                    if (text.isNotBlank()) model.action { api, _ -> api.reply(tid, forum.s("id"), forum.s("name"), text.trim(), post.s("id"), target?.s("id").orEmpty(), target?.let { Author.parse(it.obj("author")) }); text = ""; target = null; refresh++; model.message("回复成功") }
                }
            }
        }
    }
    actions?.let { row -> PostActions(row, ownThread || ownsPost(model.account, Author.parse(row.obj("author"))), true, { actions = null }, { target = row }, { delete = row }) }
    delete?.let { row -> DeleteConfirmation("删除回复", "确定要删除这条楼中楼回复吗？删除后将无法恢复。", { delete = null }) { model.action { api, _ -> api.deletePost(tid, row.s("id"), forum); delete = null; refresh++ } } }
}



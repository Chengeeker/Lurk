package com.lurk

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import kotlinx.coroutines.CancellationException
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OriginalFollowedScreen() {
    val model = LocalState.current; val open = LocalOpen.current; val revision = model.revision
    var forums by pageState("followed") { emptyList<Forum>() }
    var observedRevision by pageState("followedRevision") { -1 }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var refresh by remember { mutableIntStateOf(0) }
    val listState = androidx.compose.foundation.lazy.rememberLazyListState()
    val gridState = rememberLazyGridState()
    val session = LocalPage.current
    LaunchedEffect(session) { session.commands.collect { reload -> listState.scrollToItem(0); gridState.scrollToItem(0); if (reload) refresh++ } }
    LaunchedEffect(model.followedSnapshot) { if (model.followedSnapshot.isNotEmpty()) forums = model.followedSnapshot }
    val single = model.store.bool("key_my_forums_single_column")
    LaunchedEffect(refresh, model.accountGeneration, model.followedRevision) {
        if (model.account == null) return@LaunchedEffect
        if (refresh == 0 && forums.isNotEmpty() && observedRevision == model.followedRevision) return@LaunchedEffect
        busy = true; error = null
        try { forums = model.loadFollowed(); observedRevision = model.followedRevision }
        catch (e: CancellationException) { throw e } catch (e: Exception) { error = if (e is ApiFailure) e.message else "获取关注列表失败" }
        finally { busy = false }
    }
    Column {
        TopAppBar(colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent), modifier = Modifier.frostedTint(MaterialTheme.colorScheme.background, MaterialTheme.colorScheme.outlineVariant), title = { Row(verticalAlignment = Alignment.CenterVertically) {
            Text("我的关注", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            IconButton(onClick = tapFeedback { model.setting("key_my_forums_single_column", !single) }, modifier = Modifier.size(36.dp)) {
                Icon(if (single) Icons.Rounded.GridView else Icons.Outlined.ViewAgenda, if (single) "切换为双列视图" else "切换为单列视图", Modifier.size(20.dp))
            }
        } }, expandedHeight = 56.dp, windowInsets = WindowInsets.statusBars, actions = {
            if (model.account != null && forums.isNotEmpty()) TextButton(enabled = !model.writing, onClick = tapFeedback { model.batchSign {} }) {
                Icon(Icons.Rounded.AssignmentTurnedIn, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text("一键签到", fontWeight = FontWeight.Bold)
            }
        })
        OriginalRefreshBox(busy && forums.isNotEmpty(), { refresh++ }, Modifier.fillMaxSize(), failed = error != null) {
            when {
                model.account == null -> StateMessage("请先登录以查看关注的吧", Icons.Outlined.Lock)
                busy && forums.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                error != null && forums.isEmpty() -> StateMessage(error!!, Icons.Rounded.ErrorOutline, "请检查网络连接后重试") { refresh++ }
                forums.isEmpty() -> StateMessage("暂无关注的吧", Icons.Outlined.Forum, "关注新的吧后，它们会显示在这里")
                single -> LazyColumn(state = listState, contentPadding = PaddingValues(start = 12.dp, top = 8.dp, end = 12.dp, bottom = 80.dp)) {
                    items(forums, key = { it.id.ifEmpty { it.name } }) { ForumTile(it, true, model.signed(it)) { open(Route("forum", it.name)) } }
                }
                else -> {
                    val columns = kotlin.math.ceil((LocalConfiguration.current.screenWidthDp - 24) / 280f).toInt().coerceAtLeast(1)
                    LazyVerticalGrid(GridCells.Fixed(columns), state = gridState, contentPadding = PaddingValues(start = 12.dp, top = 12.dp, end = 12.dp, bottom = 80.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        items(forums, key = { it.id.ifEmpty { it.name } }) { ForumTile(it, false, model.signed(it)) { open(Route("forum", it.name)) } }
                    }
                }
            }
        }
    }
}

@Composable
fun StateMessage(message: String, icon: androidx.compose.ui.graphics.vector.ImageVector, detail: String = "", retry: (() -> Unit)? = null) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 96.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, null, Modifier.size(48.dp), tint = MaterialTheme.colorScheme.outline); Spacer(Modifier.height(12.dp)); Text(message, color = MaterialTheme.colorScheme.outline)
        if (detail.isNotEmpty()) { Spacer(Modifier.height(6.dp)); Text(detail, fontSize = 12.sp, color = MaterialTheme.colorScheme.outline) }
        if (retry != null) { Spacer(Modifier.height(16.dp)); FilledTonalButton(onClick = tapFeedback(retry)) { Text("重试") } }
    }
}

@Composable
fun ForumTile(forum: Forum, single: Boolean, signed: Boolean, open: () -> Unit) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val outerMargin = if (!single && maxWidth >= 200.dp) 10.dp else 0.dp
        val minimumHeight = if (single) 0.dp else (maxWidth / 2 - 10.dp).coerceAtLeast(0.dp)
        OriginalListCard(Modifier.fillMaxWidth().padding(horizontal = outerMargin, vertical = if (single) 4.5.dp else 5.dp)) {
            Row(Modifier.fillMaxWidth().heightIn(min = minimumHeight).feedbackClickable(onClick = open).padding(horizontal = if (single) 14.dp else 10.dp, vertical = if (single) 12.dp else 8.dp), verticalAlignment = Alignment.CenterVertically) {
                val avatar = forum.raw.s("avatar")
                OriginalAvatar(if (avatar.startsWith("http")) avatar else "https://tb1.bdstatic.com/tb/cms/post/avatar/$avatar", "${forum.name}头像", Modifier.size(if (single) 46.dp else 42.dp).clip(CircleShape))
                Spacer(Modifier.width(if (single) 12.dp else 8.dp))
                Column(Modifier.weight(1f)) {
                    Text(forum.name, fontSize = if (single) 15.sp else 14.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Spacer(Modifier.height(if (single) 5.dp else 3.dp))
                    // Wrap whole badges when necessary; never split the sign-in label into characters.
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(if (single) 6.dp else 5.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = RoundedCornerShape(4.dp)) {
                            Text("Lv.${forum.level}", Modifier.padding(horizontal = if (single) 6.dp else 5.dp, vertical = if (single) 1.5.dp else 1.dp), fontSize = if (single) 10.5.sp else 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer, maxLines = 1, softWrap = false)
                        }
                        if (signed) Text("已签到", Modifier.background(MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(4.dp)).padding(horizontal = if (single) 6.dp else 5.dp, vertical = if (single) 1.5.dp else 1.dp), fontSize = if (single) 10.sp else 9.5.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.outline, maxLines = 1, softWrap = false)
                    }
                }
                if (single) { Spacer(Modifier.width(8.dp)); Icon(Icons.Rounded.ChevronRight, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.outline.copy(alpha = .4f)) }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OriginalMeScreen() {
    val model = LocalState.current; val open = LocalOpen.current
    var fans by remember { mutableStateOf(false) }
    val scroll = rememberScrollState(); val page = LocalPage.current
    LaunchedEffect(page) { page.commands.collect { scroll.animateScrollTo(0) } }
    LaunchedEffect(model.accountGeneration) { model.loadMyProfile() }
    val user = model.myProfile.profile.obj("user"); val account = model.account
    Column {
        PageBar("我的", titleWeight = FontWeight.Bold)
        OriginalRefreshBox(model.myProfile.refreshing, { model.loadMyProfile(manual = true) }, Modifier.weight(1f), failed = model.myProfile.failed) {
        Column(Modifier.verticalScroll(scroll).padding(horizontal = 16.dp, vertical = 12.dp)) {
            SectionCard {
                Row(Modifier.fillMaxWidth().feedbackClickable { open(if (account == null) Route("login") else Route("myPosts", account.uid)) }.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    OriginalAvatar(portraitUrl(user.s("portrait").ifEmpty { account?.raw?.s("portrait").orEmpty() }), "头像", Modifier.size(56.dp).clip(CircleShape))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(if (account == null) "点击登录百度账号" else user.s("name_show", "name").ifEmpty { account.name }, fontSize = 17.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Spacer(Modifier.height(4.dp)); Text(if (account == null) "登录后同步关注、粉丝、收藏等数据" else "吧龄: ${user.s("tb_age").ifEmpty { "0" }} 年  •  UID: ${account.uid}", fontSize = 13.sp, color = MaterialTheme.colorScheme.outline)
                    }
                    Icon(if (account == null) Icons.Rounded.Login else Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.outline)
                }
            }
            Spacer(Modifier.height(14.dp))
            SectionCard {
                Row(Modifier.padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(.8.dp)) {
                    listOf("关注" to user.s("concern_num"), "粉丝" to user.s("fans_num"), "回帖" to user.s("post_num"), "获赞" to user.s("total_agree_num", "agree_num")).forEachIndexed { index, (label, count) ->
                        Column(Modifier.weight(1f).feedbackClickable {
                            when { index == 1 -> fans = true; index == 3 -> model.message("累计获得 ${count.ifEmpty { "0" }} 个吧友点赞")
                                account == null -> open(Route("login")); index == 0 -> open(Route("list", account.uid, "follow")); else -> open(Route("myPosts", account.uid)) }
                        }.padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(count.ifEmpty { "0" }, fontSize = 18.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.height(4.dp)); Text(label, fontSize = 12.5.sp, color = MaterialTheme.colorScheme.outline)
                        }
                    }
                }
            }
            Spacer(Modifier.height(20.dp))
            Text("快捷功能", Modifier.padding(start = 16.dp, bottom = 8.dp), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SectionCard {
                SettingsRow("我的收藏", Icons.Rounded.BookmarkBorder) { open(Route("saved")) }
                SettingsRow("浏览记录", Icons.Rounded.History) { open(Route("history")) }
                SettingsRow("设置", Icons.Outlined.Settings) { open(Route("settings")) }
            }
            Spacer(Modifier.height(80.dp))
        }
    }
    }
    if (fans) AlertDialog(onDismissRequest = { fans = false }, icon = { Icon(Icons.Rounded.Favorite, null, Modifier.size(36.dp), tint = Color(0xFFFF4081)) }, title = { Text("我的粉丝", fontSize = 18.sp, fontWeight = FontWeight.Bold) }, text = { Text("您当前共有 ${user.s("fans_num").ifEmpty { "0" }} 位粉丝关注。", fontSize = 14.sp) }, confirmButton = { TextButton(onClick = tapFeedback { fans = false }) { Text("我知道了") } })
}




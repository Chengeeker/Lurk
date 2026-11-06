@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.lurk

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em

@Composable
fun PreferenceHeading(text: String) = Text(text, Modifier.padding(start = 16.dp, bottom = 8.dp), fontSize = 15.sp,
    fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)

@Composable
fun OriginalChoice(title: String, dialog: String, icon: ImageVector, key: String, choices: List<String>, prefix: String,
                   default: Int = 0, descriptions: List<String> = emptyList()) {
    val model = LocalState.current; val revision = model.revision
    val selected = model.store.int(key, default).coerceIn(choices.indices)
    var visible by remember { mutableStateOf(false) }
    SettingsRow(title, icon, prefix + choices[selected], detailSize = if (key == "key_font_weight_index") 14.sp else 12.5.sp) { visible = true }
    if (visible) BasicAlertDialog(onDismissRequest = { visible = false }) {
        Surface(shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.surfaceContainerHigh) {
            Column(Modifier.padding(vertical = 24.dp)) {
                if (key == "key_font_weight_index") {
                    Text(dialog, Modifier.padding(horizontal = 24.dp), style = MaterialTheme.typography.headlineSmall)
                    Spacer(Modifier.height(12.dp))
                    choices.forEachIndexed { index, label ->
                        Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).feedbackClickable { model.setting(key, index); visible = false }.padding(horizontal = 20.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                            CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) { RadioButton(selected == index, null, Modifier.size(40.dp)) }
                            Spacer(Modifier.width(16.dp)); Text(label, fontSize = 16.sp, fontWeight = FontWeight(300 + index * 100), color = if (selected == index) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
                        }
                    }
                    Spacer(Modifier.height(12.dp)); TextButton(onClick = tapFeedback { visible = false }, modifier = Modifier.align(Alignment.End).padding(end = 24.dp)) { Text("取消") }
                } else {
                Text(dialog, Modifier.padding(horizontal = 24.dp), fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(12.dp))
                choices.forEachIndexed { index, label ->
                    Row(Modifier.fillMaxWidth().feedbackClickable { model.setting(key, index); visible = false }.padding(horizontal = 24.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(label, fontSize = 16.sp, color = if (selected == index) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
                            descriptions.getOrNull(index)?.let { Text(it, Modifier.padding(top = 2.dp), fontSize = 11.5.sp, color = MaterialTheme.colorScheme.outline) }
                        }
                        if (index == selected) Icon(Icons.Rounded.Check, "已选择", Modifier.size(20.dp), tint = MaterialTheme.colorScheme.primary)
                    }
                }
                }
            }
        }
    }
}

@Composable
fun OriginalHabits(back: () -> Unit) {
    Column {
        PageBar("使用习惯", back, titleWeight = FontWeight.SemiBold)
        Column(Modifier.verticalScroll(rememberPageScrollState()).padding(horizontal = 16.dp, vertical = 8.dp)) {
            PreferenceHeading("启动与偏好")
            SectionCard {
                OriginalChoice("启动首选页", "选择启动首选页", Icons.Outlined.Home, "key_habit_initial_tab_index", listOf("进吧", "动态", "消息", "我的"), "当前首选：", 1)
                OriginalChoice("图片加载设置", "图片加载设置", Icons.Rounded.PhotoFilter, "key_habit_image_load_mode", listOf("智能省流量", "智能无图", "始终高质量", "始终无图"), "当前模式：", descriptions = listOf(
                    "自动压缩优化，列表省流，查看大图加载高清原图（推荐）", "列表仅展示占位提示，点击才加载图片，极致省流", "所有位置均优先请求无压缩原图，画质极致", "完全不加载并隐藏贴子配图，纯文本浏览"))
                OriginalChoice("吧默认排序方式", "默认排序方式", Icons.Rounded.Sort, "key_habit_forum_default_sort", listOf("回复时间排序", "发帖时间排序"), "当前排序：", descriptions = listOf("优先展示最近有新回帖的贴子（平台默认）", "按贴子最初发表时间倒序排列，查看最新贴子"))
                OriginalSwitch("不保存浏览记录", "key_habit_do_not_save_history", Icons.Rounded.HistoryToggleOff)
            }
            Spacer(Modifier.height(18.dp)); PreferenceHeading("浏览与交互偏好")
            SectionCard {
                OriginalSwitch("自动加载更多", "key_habit_auto_load_more", Icons.Rounded.Autorenew, true)
                OriginalSwitch("双击顶栏返回顶部", "key_habit_double_tap_top", Icons.Rounded.VerticalAlignTop, true)
                OriginalSwitch("看图优先加载高清原图", "key_habit_show_original_img", Icons.Outlined.Image)
                OriginalSwitch("双击底栏快速刷新", "key_habit_double_tap_feed_refresh", Icons.Outlined.TouchApp, true)
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
fun OriginalBlocks(back: () -> Unit) {
    val model = LocalState.current; val open = LocalOpen.current; val revision = model.revision
    Column {
        PageBar("屏蔽设置", back, titleWeight = FontWeight.SemiBold)
        Column(Modifier.verticalScroll(rememberPageScrollState()).padding(horizontal = 16.dp, vertical = 8.dp)) {
            PreferenceHeading("内容过滤与屏蔽")
            SectionCard {
                SettingsRow("屏蔽词管理", Icons.Outlined.FilterAlt, "黑名单 ${model.store.list("key_block_words_list").size} 个  |  白名单 ${model.store.list("key_white_words_list").size} 个", detailSize = 12.5.sp) { open(Route("settings", "words")) }
                OriginalSwitch("彻底隐藏被屏蔽的内容", "key_hide_blocked_completely", Icons.Outlined.VisibilityOff, true)
                OriginalSwitch("不看视频贴", "key_block_video_threads", Icons.Outlined.VideocamOff)
                OriginalSwitch("只推荐已关注的吧", "key_recommend_followed_only", Icons.Rounded.FavoriteBorder)
            }
        }
    }
}

@Composable
fun OriginalWords(back: () -> Unit) {
    val model = LocalState.current; val revision = model.revision
    var tab by rememberSaveable { mutableIntStateOf(0) }
    Column {
        FrostedHeading {
        PageBar("屏蔽词管理", back, titleSize = 19.sp, titleWeight = FontWeight.Bold)
        OriginalTabBar(tab, listOf("黑名单 (${model.store.list("key_block_words_list").size})", "白名单 (${model.store.list("key_white_words_list").size})"), { tab = it }, MaterialTheme.typography.titleSmall.copy(fontSize = 15.sp, fontWeight = FontWeight.Bold))
        }
        OriginalTabs(tab, 2, { tab = it }) { tab ->
        val key = if (tab == 0) "key_block_words_list" else "key_white_words_list"
        val words = model.store.list(key)
        var input by rememberSaveable(tab) { mutableStateOf("") }
        var clear by remember { mutableStateOf(false) }
        val accent = if (tab == 0) Color(0xFFFF5252) else Color(0xFF4CAF50)
        Column(Modifier.fillMaxSize()) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            TextField(input, { input = it }, Modifier.weight(1f), singleLine = true, shape = RoundedCornerShape(14.dp),
                placeholder = { Text(if (tab == 0) "输入屏蔽词，标题或内容包含时屏蔽..." else "输入白名单词，命中时免受黑名单屏蔽...", fontSize = 13.5.sp) },
                colors = TextFieldDefaults.colors(focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent, focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = .4f), unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = .4f)),
                trailingIcon = { IconButton(onClick = tapFeedback { input = "" }) { Icon(Icons.Outlined.Clear, "清除输入", Modifier.size(18.dp)) } })
            Spacer(Modifier.width(10.dp))
            Button(onClick = tapFeedback { if (input.isNotBlank()) model.setting(key, (words + input.trim()).distinct()); input = "" }, shape = RoundedCornerShape(14.dp), contentPadding = PaddingValues(horizontal = 18.dp, vertical = 12.dp)) { Text("添加", fontWeight = FontWeight.Bold) }
        }
        if (words.isEmpty()) Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(if (tab == 0) Icons.Outlined.Shield else Icons.Outlined.VerifiedUser, null, Modifier.size(56.dp), tint = MaterialTheme.colorScheme.outline.copy(alpha = .5f))
                Spacer(Modifier.height(12.dp)); Text(if (tab == 0) "暂无黑名单屏蔽词\n添加后包含该词的帖子将被过滤屏蔽" else "暂无白名单词\n白名单内的词汇将豁免黑名单屏蔽规则", fontSize = 13.5.sp, lineHeight = 1.5.em, textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.outline)
            }
        } else {
            Row(Modifier.padding(horizontal = 18.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("已添加 ${words.size} 个词汇", Modifier.weight(1f), fontSize = 12.5.sp, color = MaterialTheme.colorScheme.outline)
                TextButton(onClick = tapFeedback { clear = true }) { Text("清空全部", color = Color(0xFFFF5252), fontSize = 12.5.sp) }
            }
            LazyColumn(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(words, key = { it }) { word -> Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                    ListItem(headlineContent = { Text(word) }, leadingContent = { Box(Modifier.size(30.dp).background(accent.copy(alpha = .12f), CircleShape), contentAlignment = Alignment.Center) { Icon(if (tab == 0) Icons.Rounded.Block else Icons.Rounded.Check, null, Modifier.size(16.dp), tint = accent) } },
                        trailingContent = { IconButton(onClick = tapFeedback { model.setting(key, words - word) }) { Icon(Icons.Outlined.Close, "移除 $word") } }, colors = ListItemDefaults.colors(containerColor = Color.Transparent))
                } }
            }
        }
    }
    if (clear) AlertDialog(onDismissRequest = { clear = false }, title = { Text("清空${if (tab == 0) "黑名单" else "白名单"}") }, text = { Text("确定要清空全部${if (tab == 0) "黑名单" else "白名单"}词汇吗？") }, confirmButton = { TextButton(onClick = tapFeedback { model.setting(key, emptyList<String>()); clear = false }) { Text("清空", color = Color.Red) } }, dismissButton = { TextButton(onClick = tapFeedback { clear = false }) { Text("取消") } })
        }
    }
}


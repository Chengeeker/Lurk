@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package com.lurk

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import coil.compose.AsyncImage

@Composable
fun SettingsScreen(section: String, back: () -> Unit) {
    when (section) {
        "appearance" -> OriginalAppearance(back)
        "storage" -> OriginalStorage(back)
        "display" -> OriginalDisplay(back)
        "habits" -> OriginalHabits(back)
        "block" -> OriginalBlocks(back)
        "words" -> OriginalWords(back)
        "cache" -> OriginalCache(back)
        else -> OriginalSettingsHome(back)
    }
}
@Composable
fun EditorScreen(forum: String, fid: String, back: () -> Unit, published: () -> Unit = back) {
    val model = LocalState.current; val context = LocalContext.current; val colors = MaterialTheme.colorScheme
    var title by rememberSaveable { mutableStateOf("") }; var content by rememberSaveable { mutableStateOf("") }
    var images by remember { mutableStateOf(emptyList<Uri>()) }; var progress by remember { mutableStateOf("") }
    var submitting by remember { mutableStateOf(false) }; var alive by remember { mutableStateOf(true) }
    DisposableEffect(Unit) { onDispose { alive = false } }
    BackHandler(submitting) {}
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { uris ->
        val remaining = 9 - images.size
        if (uris.size > remaining) model.message("单个主题最多添加 9 张图片")
        images = (images + uris.take(remaining)).take(9)
    }
    Column(Modifier.imePadding()) {
        PageBar("在「${forum.removeSuffix("吧")}」吧发帖", { if (!submitting) back() })
        if (submitting) LinearProgressIndicator(Modifier.fillMaxWidth().height(2.dp))
        Column(Modifier.weight(1f).verticalScroll(rememberPageScrollState()).padding(start = 16.dp, top = 20.dp, end = 16.dp, bottom = 24.dp)) {
            OutlinedTextField(title, { if (it.codePointCount(0, it.length) <= 50) title = it }, Modifier.fillMaxWidth(), enabled = !submitting, label = { Text("标题") }, placeholder = { Text("请输入帖子标题") }, supportingText = { Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) { Text("${title.codePointCount(0, title.length)}/50") } })
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(content, { content = it }, Modifier.fillMaxWidth(), enabled = !submitting, minLines = 7, maxLines = 14, label = { Text("正文") }, placeholder = { Text("写下你想分享的内容，也可以只发图片") })
            Spacer(Modifier.height(24.dp)); Row(verticalAlignment = Alignment.CenterVertically) { Text("图片", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold); Spacer(Modifier.width(8.dp)); Text("${images.size}/9", color = colors.outline) }; Spacer(Modifier.height(12.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                images.forEachIndexed { index, uri ->
                    Box(Modifier.size(92.dp).clip(RoundedCornerShape(12.dp))) {
                        AsyncImage(uri, "待上传图片 ${index + 1}", Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                        Icon(Icons.Rounded.Close, "移除图片", Modifier.align(Alignment.TopEnd).padding(3.dp).clip(CircleShape).background(colors.surface.copy(alpha = .9f)).feedbackClickable(enabled = !submitting) { images = images.filterIndexed { i, _ -> i != index } }.padding(4.dp).size(17.dp))
                    }
                }
                if (images.size < 9) Column(Modifier.size(92.dp).clip(RoundedCornerShape(12.dp)).background(colors.surfaceContainerHighest.copy(alpha = .5f)).border(1.dp, colors.outlineVariant, RoundedCornerShape(12.dp)).feedbackClickable(enabled = !submitting) { runCatching { picker.launch("image/*") }.onFailure { model.message("无法打开系统图片选择器") } }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) { Icon(Icons.Outlined.AddPhotoAlternate, null, tint = colors.primary); Spacer(Modifier.height(4.dp)); Text("添加图片", color = colors.onSurfaceVariant) }
            }
            Spacer(Modifier.height(12.dp)); Text("图片会先上传到贴吧，再随主题提交；单张图片会压缩到 1080 像素以内、5 MB 以内。", fontSize = 12.sp, lineHeight = 1.45.em, color = colors.outline)
        }
        if (submitting) Text(progress, Modifier.align(Alignment.CenterHorizontally).padding(bottom = 4.dp), color = colors.onSurfaceVariant)
        Button(enabled = !model.writing, modifier = Modifier.fillMaxWidth().padding(start = 16.dp, top = 8.dp, end = 16.dp, bottom = 12.dp), onClick = tapFeedback {
            if (title.isBlank()) model.message("请输入帖子标题")
            else if (content.isBlank() && images.isEmpty()) model.message("请输入帖子内容或添加图片")
            else model.action { api, generation ->
                submitting = true
                try {
                    val id = fid.takeIf { it.isNotEmpty() && it != "0" } ?: api.forum(forum, 1).obj("forum").s("id")
                    require(id.isNotEmpty() && id != "0") { "无法取得吧信息" }
                    val tags = mutableListOf<String>()
                    for ((i, uri) in images.withIndex()) { progress = "正在上传图片 ${i + 1}/${images.size}…"; tags += api.uploadImage(context, uri, forum) }
                    progress = if (images.isNotEmpty()) "图片已上传，正在提交帖子…" else "正在提交帖子…"
                    api.write("/c/c/thread/add", mapOf("_client_id" to "wappc_${System.currentTimeMillis()}_0", "anonymous" to "0", "content" to content.trim() + tags.joinToString(""), "fid" to id, "kw" to forum.removeSuffix("吧"), "new_vcode" to "1", "title" to title.trim(), "vcode_tag" to "11"))
                    model.message("贴吧已接收发帖请求"); if (alive && model.stillCurrent(generation)) published()
                } finally { submitting = false }
            }
        }) { if (submitting) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) else Icon(Icons.AutoMirrored.Rounded.Send, null); Spacer(Modifier.width(8.dp)); Text(if (submitting) "正在发布" else "发表主题") }
    }
}


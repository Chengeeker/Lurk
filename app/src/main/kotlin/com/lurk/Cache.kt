package com.lurk

import android.content.Context
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import coil.imageLoader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Locale

data class CacheStats(val images: Long = 0, val network: Long = 0, val system: Long = 0) { val total get() = images + network + system }
fun formatBytes(bytes: Long): String {
    var value = bytes.coerceAtLeast(0).toDouble(); var index = 0
    while (value >= 1024 && index < 4) { value /= 1024; index++ }
    return String.format(Locale.ROOT, if (index == 0) "%.0f %s" else "%.2f %s", value, listOf("B", "KB", "MB", "GB", "TB")[index])
}
fun cacheRoots(context: Context) = (listOf(context.cacheDir, context.codeCacheDir) + context.externalCacheDirs.filterNotNull()).distinctBy { it.canonicalPath }
fun visitCache(root: File, delete: Boolean = false, visitor: (File) -> Unit = {}) {
    val prefix = root.canonicalPath + File.separator
    fun visit(entry: File) {
        // Reject every symlink, including links inside a valid cache directory.
        val parent = entry.parentFile ?: return
        if (entry.canonicalFile != File(parent.canonicalFile, entry.name) || !entry.canonicalPath.startsWith(prefix)) return
        if (entry.isDirectory) entry.listFiles()?.forEach(::visit) else if (entry.isFile) visitor(entry)
        if (delete && entry.exists()) check(entry.delete()) { "部分缓存正在使用，请稍后重试" }
    }
    root.listFiles()?.forEach(::visit)
}
suspend fun cacheStats(context: Context): CacheStats = withContext(Dispatchers.IO) {
    var images = 0L; var network = 0L; var system = 0L
    cacheRoots(context).forEach { root -> visitCache(root) { file ->
        val path = file.path.lowercase(Locale.ROOT); val size = file.length()
        if (path.contains("image") || path.contains("coil") || file.extension.lowercase(Locale.ROOT) in listOf("png", "jpg", "jpeg", "gif", "webp")) images += size
        else if (path.contains("http") || path.contains("webview") || path.contains("dio") || path.endsWith(".tmp")) network += size
        else system += size
    } }
    CacheStats(images, network, system)
}
@OptIn(coil.annotation.ExperimentalCoilApi::class)
suspend fun clearAppCache(context: Context) = withContext(Dispatchers.IO) {
    context.imageLoader.memoryCache?.clear(); context.imageLoader.diskCache?.clear()
    cacheRoots(context).forEach { visitCache(it, delete = true) }
}
suspend fun autoClearCache(store: AppStore) {
    val threshold = store.int("key_auto_clear_cache_threshold_mb", 200)
    if (threshold > 0 && cacheStats(store.context).total >= threshold * 1024L * 1024L) clearAppCache(store.context)
}

@Composable
fun OriginalCache(back: () -> Unit) {
    val context = LocalContext.current; val model = LocalState.current; val colors = MaterialTheme.colorScheme
    var stats by remember { mutableStateOf(CacheStats()) }; var loading by remember { mutableStateOf(true) }
    var failed by remember { mutableStateOf(false) }; var clear by remember { mutableStateOf(false) }; var thresholdDialog by remember { mutableStateOf(false) }
    var reload by remember { mutableIntStateOf(0) }; val revision = model.revision
    val threshold = model.store.int("key_auto_clear_cache_threshold_mb", 200)
    fun thresholdLabel(n: Int) = when { n == 0 -> "不限制（从不自动清理）"; n >= 1024 -> "${n / 1024} GB"; else -> "$n MB" }
    LaunchedEffect(reload) { loading = true; runCatching { cacheStats(context) }.onSuccess { stats = it; failed = false }.onFailure { failed = true }; loading = false }
    Column {
        PageBar("缓存管理", back, frosted = false)
        Column(Modifier.verticalScroll(rememberPageScrollState()).padding(horizontal = 16.dp, vertical = 12.dp)) {
            SectionCard {
                Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Rounded.CleaningServices, null, Modifier.size(32.dp), tint = colors.primary); Spacer(Modifier.height(12.dp))
                    if (loading) CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.5.dp) else Text(if (failed) "暂不可用" else formatBytes(stats.total), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(4.dp)); Text("当前应用缓存占用", color = colors.onSurfaceVariant)
                    if (failed) TextButton(onClick = tapFeedback { reload++ }) { Icon(Icons.Rounded.Refresh, null); Spacer(Modifier.width(8.dp)); Text("重新读取") } else {
                        Spacer(Modifier.height(20.dp))
                        Row(Modifier.fillMaxWidth().height(10.dp).clip(RoundedCornerShape(6.dp)).background(colors.surfaceContainerHighest)) {
                            listOf(stats.images to colors.primary, stats.network to colors.tertiary, stats.system to colors.secondary).forEach { (bytes, color) -> if (bytes > 0) Box(Modifier.weight((bytes.toDouble() / stats.total).toFloat().coerceAtLeast(.001f)).fillMaxHeight().background(color)) }
                        }
                        Spacer(Modifier.height(18.dp))
                        Row {
                            listOf(Triple("图片与媒体", stats.images, colors.primary), Triple("网络与临时", stats.network, colors.tertiary), Triple("系统运行时", stats.system, colors.secondary)).forEach { (name, bytes, color) ->
                                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                                    Row(verticalAlignment = Alignment.CenterVertically) { Box(Modifier.size(8.dp).background(color, CircleShape)); Spacer(Modifier.width(5.dp)); Text(name, Modifier.weight(1f, fill = false), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis, fontSize = 12.sp, color = colors.onSurfaceVariant) }
                                    Spacer(Modifier.height(4.dp)); Text(formatBytes(bytes), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
            SectionCard { Box(Modifier.padding(16.dp)) { Button(onClick = tapFeedback { clear = true }, enabled = !loading && !model.writing, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp), shape = RoundedCornerShape(12.dp)) { Icon(Icons.Rounded.DeleteSweep, null); Spacer(Modifier.width(8.dp)); Text(if (model.writing) "正在清理..." else "一键清理所有缓存") } } }
            Spacer(Modifier.height(24.dp)); PreferenceHeading("自动清理规则"); Spacer(Modifier.height(4.dp))
            SectionCard {
                ListItem(headlineContent = { Text("自动清理缓存阈值", style = MaterialTheme.typography.titleMedium.copy(fontSize = 16.sp)) }, supportingContent = { Text("启动时达到阈值后自动清理") }, leadingContent = { Icon(Icons.Outlined.AutoDelete, null) }, trailingContent = { Text(thresholdLabel(threshold), color = colors.primary, fontWeight = FontWeight.SemiBold) }, colors = ListItemDefaults.colors(containerColor = Color.Transparent), modifier = Modifier.feedbackClickable { thresholdDialog = true })
                OriginalSwitch("退出时自动清理缓存", "key_auto_clear_cache_on_exit", Icons.Rounded.ExitToApp)
            }
            Spacer(Modifier.height(24.dp)); PreferenceHeading("清理范围"); Spacer(Modifier.height(4.dp))
            SectionCard { Text("清理范围包括图片内存与磁盘缓存，以及 Android 应用缓存目录。分类按文件名和扩展名估算。不会清除账号凭据、收藏、浏览记录或保存到系统相册的媒体。", Modifier.padding(16.dp), fontSize = 13.sp, lineHeight = 1.45.em, color = colors.onSurfaceVariant) }
            Spacer(Modifier.height(32.dp))
        }
    }
    if (clear) AlertDialog(onDismissRequest = { clear = false }, title = { Text("清理所有缓存？") }, text = { Text(if (failed || stats.total <= 0) "将清理 Lurk 的图片缓存及 Android 应用缓存目录。不会删除账号、收藏、浏览记录或已保存的照片和视频。" else "将清理约 ${formatBytes(stats.total)} 的图片、网络与运行时缓存。不会删除账号、收藏、浏览记录或已保存的照片和视频。") }, confirmButton = { Button(onClick = tapFeedback { clear = false; model.action(false) { _, _ -> clearAppCache(context); reload++; model.message("缓存清理完毕") } }) { Text("立即清理") } }, dismissButton = { TextButton(onClick = tapFeedback { clear = false }) { Text("取消") } })
    if (thresholdDialog) AlertDialog(onDismissRequest = { thresholdDialog = false }, title = { Text("选择自动清理阈值") }, text = {
        Column { listOf(0, 50, 100, 200, 500, 1024, 2048).forEach { n -> Row(Modifier.fillMaxWidth().feedbackClickable { thresholdDialog = false; model.action(false) { _, _ -> withContext(Dispatchers.IO) { model.store.put("key_auto_clear_cache_threshold_mb", n) }; model.setting("key_auto_clear_cache_threshold_mb", n); autoClearCache(model.store); reload++ } }, verticalAlignment = Alignment.CenterVertically) { RadioButton(n == threshold, null); Text(if (n >= 1024) "${n / 1024} GB ($n MB)" else thresholdLabel(n)) } } }
    }, confirmButton = { TextButton(onClick = tapFeedback { thresholdDialog = false }) { Text("取消") } })
}


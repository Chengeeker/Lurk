package com.lurk

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import coil.request.ImageRequest

fun mediaRequest(context: Context, url: String, size: Int = 1600) = ImageRequest.Builder(context).data(url).memoryCacheKey(url).addHeader("User-Agent", "bdtb for Android 12.41.7.1").addHeader("Referer", "https://tieba.baidu.com/").size(size).crossfade(false).build()
@Composable
fun rememberMediaSaver(): (Media) -> Unit {
    val model = LocalState.current; val context = LocalContext.current
    var pending by remember { mutableStateOf<Media?>(null) }
    fun save(item: Media) { model.action(false) { _, _ -> saveMedia(model.store, item); model.message(if (!item.isVideo) "图片已保存到相册" else "视频已保存到相册") } }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { allowed -> val item = pending; pending = null; if (allowed && item != null) save(item) else if (!allowed) model.message("未获得存储权限，无法保存") }
    return { item -> if (!model.writing && pending == null) {
        if (Build.VERSION.SDK_INT < 29 && ContextCompat.checkSelfPermission(context, android.Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) { pending = item; permission.launch(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) }
        else save(item)
    } }
}

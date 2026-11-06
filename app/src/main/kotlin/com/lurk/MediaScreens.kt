package com.lurk

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject
import java.io.ByteArrayOutputStream
suspend fun saveMedia(store: AppStore, media: Media) = withContext(Dispatchers.IO) {
    val video = media.isVideo
    val url = targetUrl(if (video) media.video else media.original)
    require(url.isNotEmpty()) { "无效的媒体地址" }
    val context = store.context
    val resolver = context.contentResolver
    val response = NativeApi.http.newBuilder().followRedirects(true).build().newCall(NativeApi().request(url, false).header("Referer", "https://tieba.baidu.com/").build()).execute()
    response.use {
        require(it.isSuccessful) { "下载失败（${it.code}）" }
        val body = requireNotNull(it.body)
        val declared = body.contentType()?.toString()?.substringBefore(';').orEmpty()
        val type = mediaMime(declared, it.peekBody(32).bytes(), video)
        require(type.startsWith(if (video) "video/" else "image/")) { "返回的内容不是媒体文件" }
        val extension = when (type) { "image/png" -> "png"; "image/gif" -> "gif"; "image/webp" -> "webp"; "video/webm" -> "webm"; "video/x-flv" -> "flv"; else -> if (video) "mp4" else "jpg" }
        val name = "Lurk_${System.currentTimeMillis()}.$extension"
        val pathType = store.int(if (video) "key_video_save_path_type" else "key_image_save_path_type")
        val folder = when (pathType) { 1 -> store.active()?.name ?: "MyProfile"; 2 -> media.folderName; else -> "" }
            .trim().replace(Regex("[\\\\/:*?\"<>|\\r\\n]"), "_").take(40).takeUnless { it == "." || it == ".." }.orEmpty()
        val relativePath = (if (video) "Movies/Lurk" else "Pictures/Lurk") + if (folder.isNotEmpty()) "/$folder" else ""
        if (Build.VERSION.SDK_INT < 29) {
            require(androidx.core.content.ContextCompat.checkSelfPermission(context, android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == android.content.pm.PackageManager.PERMISSION_GRANTED) { "需要存储权限才能保存" }
            @Suppress("DEPRECATION") val root = android.os.Environment.getExternalStorageDirectory()
            val parent = java.io.File(root, relativePath)
            check(parent.isDirectory || parent.mkdirs()) { "无法创建保存目录" }
            val file = java.io.File(parent, name)
            try { file.outputStream().use { output -> body.byteStream().use { input -> input.copyTo(output) } }; android.media.MediaScannerConnection.scanFile(context, arrayOf(file.path), arrayOf(type), null) }
            catch (e: Exception) { file.delete(); throw e }
            return@withContext
        }
        val destination = run {
            val values = ContentValues().apply { put(MediaStore.MediaColumns.DISPLAY_NAME, name); put(MediaStore.MediaColumns.MIME_TYPE, type)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath); put(MediaStore.MediaColumns.IS_PENDING, 1) }
            resolver.insert(if (video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)        } ?: error("无法创建保存文件")
        try {
            resolver.openOutputStream(destination)?.use { output -> body.byteStream().use { input -> input.copyTo(output) } } ?: error("无法写入文件")
            if (Build.VERSION.SDK_INT >= 29) resolver.update(destination, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) { resolver.delete(destination, null, null); throw e }
    }
}

suspend fun NativeApi.uploadImage(context: Context, uri: Uri, forum: String): String = withContext(Dispatchers.IO) {
    val account = requireNotNull(account)
    val source = context.contentResolver.openInputStream(uri)?.use { stream ->
        val out = ByteArrayOutputStream(); val buffer = ByteArray(8192)
        while (true) { val n = stream.read(buffer); if (n < 0) break; require(out.size() + n <= 32 * 1024 * 1024) { "图片过大，请先裁剪" }; out.write(buffer, 0, n) }
        out.toByteArray()
    } ?: error("无法读取图片")
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(source, 0, source.size, bounds)
    require(bounds.outWidth > 0 && bounds.outHeight > 0) { "图片无法解码" }
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 2160) sample *= 2
    val original = requireNotNull(BitmapFactory.decodeByteArray(source, 0, source.size, BitmapFactory.Options().apply { inSampleSize = sample }))
    val factor = minOf(1f, 1080f / maxOf(original.width, original.height))
    val resized = Bitmap.createScaledBitmap(original, maxOf(1, (original.width * factor).toInt()), maxOf(1, (original.height * factor).toInt()), true)
    val orientation = androidx.exifinterface.media.ExifInterface(java.io.ByteArrayInputStream(source)).getAttributeInt(androidx.exifinterface.media.ExifInterface.TAG_ORIENTATION, 1)
    val matrix = android.graphics.Matrix().apply {
        when (orientation) {
            2 -> setScale(-1f, 1f); 3 -> setRotate(180f); 4 -> setScale(1f, -1f)
            5 -> { setRotate(90f); postScale(-1f, 1f) }; 6 -> setRotate(90f)
            7 -> { setRotate(-90f); postScale(-1f, 1f) }; 8 -> setRotate(-90f)
        }
    }
    val scaled = if (orientation in 2..8) Bitmap.createBitmap(resized, 0, 0, resized.width, resized.height, matrix, true) else resized
    val width = scaled.width; val height = scaled.height
    val output = ByteArrayOutputStream()
    try { check(scaled.compress(Bitmap.CompressFormat.JPEG, 95, output)) } finally { if (scaled !== resized) scaled.recycle(); if (resized !== original) resized.recycle(); original.recycle() }
    val bytes = output.toByteArray()
    require(bytes.size <= 5 * 1024 * 1024) { "压缩后图片仍超过 5 MB" }
    val chunkSize = 512000; val count = (bytes.size + chunkSize - 1) / chunkSize
    var result = JSONObject()
    for (index in 0 until count) {
        val fields = mapOf("alt" to "json", "chunkNo" to "${index + 1}", "forum_name" to forum.removeSuffix("吧"), "groupId" to "1", "height" to "$height",
            "isFinish" to if (index == count - 1) "1" else "0", "is_bjh" to "0", "pic_water_type" to "2", "resourceId" to "${md5(bytes)}$chunkSize", "saveOrigin" to "0",
            "size" to "${bytes.size}", "small_flow_fname" to forum.removeSuffix("吧"), "width" to "$width", "BDUSS" to account.bduss, "stoken" to account.stoken,
            "cuid" to NativeApi.CUID, "cuid_galaxy2" to NativeApi.CUID)
        val form = MultipartBody.Builder().setType(MultipartBody.FORM).apply {
            fields.forEach { (k, v) -> addFormDataPart(k, v) }
            addFormDataPart("chunk", "file", bytes.copyOfRange(index * chunkSize, minOf(bytes.size, (index + 1) * chunkSize)).toRequestBody("image/jpeg".toMediaType()))
        }.build()
        result = JSONObject(this@uploadImage.bytes(request(NativeApi.BASE + "/c/s/uploadPicture").header("Accept", "application/json").header("Cookie", "ka=open; CUID=${NativeApi.CUID}; BDUSS=${account.bduss}; STOKEN=${account.stoken}").post(form).build()).toString(Charsets.UTF_8))
        checkResult(result)
    }
    val origin = result.obj("picInfo").optJSONObject("originPic")
    require(result.s("picId").isNotEmpty() && origin != null) { "上传结果缺少图片信息" }
    val uploadedWidth = origin.optInt("width").takeIf { it > 0 } ?: width
    val uploadedHeight = origin.optInt("height").takeIf { it > 0 } ?: height
    "#(pic,${result.s("picId")},$uploadedWidth,$uploadedHeight)"
}





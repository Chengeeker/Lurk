package com.lurk

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import android.webkit.CookieManager
import java.io.File
import java.util.concurrent.Executors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val COOKIE_CHANNEL = "com.lurk/cookie_manager"
    private val APP_CHANNEL = "com.lurk/app"
    private var appMethodChannel: MethodChannel? = null
    private var cacheMethodChannel: MethodChannel? = null
    private val cacheExecutor = Executors.newSingleThreadExecutor()
    private var initialUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.dataString
        if (!data.isNullOrEmpty()) {
            initialUrl = data
            try {
                appMethodChannel?.invokeMethod("onDeepLinkOpened", data)
            } catch (_: Exception) {}
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. App Channel for Deep Links
        appMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialUrl" -> {
                        result.success(initialUrl)
                        initialUrl = null
                    }
                    "shareText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val title = call.argument<String>("title") ?: "分享贴子"
                        try {
                            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                                putExtra(Intent.EXTRA_SUBJECT, title)
                            }
                            activity.startActivity(Intent.createChooser(shareIntent, title))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    }
                    "setBrightness" -> {
                        try {
                            val brightness = call.argument<Double>("brightness")
                                ?.toFloat()?.coerceIn(0.01f, 1.0f) ?: 0.5f
                            val attributes = window.attributes
                            attributes.screenBrightness = brightness
                            window.attributes = attributes
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BRIGHTNESS_ERROR", e.message, null)
                        }
                    }
                    "getBrightness" -> {
                        val brightness = window.attributes.screenBrightness
                        val value = if (brightness < 0f) {
                            try {
                                Settings.System.getInt(
                                    contentResolver,
                                    Settings.System.SCREEN_BRIGHTNESS,
                                ) / 255.0
                            } catch (_: Exception) {
                                0.5
                            }
                        } else {
                            brightness.toDouble()
                        }
                        result.success(value)
                    }
                    "resetBrightness" -> {
                        val attributes = window.attributes
                        attributes.screenBrightness = -1f
                        window.attributes = attributes
                        result.success(true)
                    }
                    "saveImageToGallery" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "lurk_${System.currentTimeMillis()}.jpg"
                        val relativePath = call.argument<String>("relativePath") ?: "Pictures/Lurk"
                        if (bytes == null) {
                            result.error("INVALID_ARGS", "Bytes cannot be null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val values = ContentValues().apply {
                                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                    put(MediaStore.Images.Media.RELATIVE_PATH, relativePath)
                                    put(MediaStore.Images.Media.IS_PENDING, 1)
                                }
                            }
                            val resolver = contentResolver
                            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                            if (uri != null) {
                                resolver.openOutputStream(uri)?.use { os ->
                                    os.write(bytes)
                                }
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                    values.clear()
                                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                                    resolver.update(uri, values, null, null)
                                }
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    "saveVideoToGallery" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "lurk_video_${System.currentTimeMillis()}.mp4"
                        val relativePath = call.argument<String>("relativePath") ?: "Movies/Lurk"
                        if (bytes == null) {
                            result.error("INVALID_ARGS", "Bytes cannot be null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val values = ContentValues().apply {
                                put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                    put(MediaStore.Video.Media.RELATIVE_PATH, relativePath)
                                    put(MediaStore.Video.Media.IS_PENDING, 1)
                                }
                            }
                            val resolver = contentResolver
                            val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                            if (uri != null) {
                                resolver.openOutputStream(uri)?.use { os ->
                                    os.write(bytes)
                                }
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                    values.clear()
                                    values.put(MediaStore.Video.Media.IS_PENDING, 0)
                                    resolver.update(uri, values, null, null)
                                }
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // 2. Cookie Manager Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COOKIE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url") ?: "https://tieba.baidu.com"
                    val cookie = CookieManager.getInstance().getCookie(url)
                    val baiduCookie = CookieManager.getInstance().getCookie("https://baidu.com")
                    val passportCookie = CookieManager.getInstance().getCookie("https://wappass.baidu.com")
                    
                    val combined = mutableListOf<String>()
                    if (!cookie.isNullOrEmpty()) combined.add(cookie)
                    if (!baiduCookie.isNullOrEmpty()) combined.add(baiduCookie)
                    if (!passportCookie.isNullOrEmpty()) combined.add(passportCookie)
                    
                    result.success(combined.joinToString("; "))
                }
                "clearCookies" -> {
                    CookieManager.getInstance().removeAllCookies(null)
                    CookieManager.getInstance().flush()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        cacheMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.lurk/cache",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCacheStats" -> cacheExecutor.execute {
                        try {
                            val stats = getCacheStatistics()
                            runOnUiThread { result.success(stats) }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error("CACHE_STATS_FAILED", error.message, null)
                            }
                        }
                    }
                    "clearCache" -> cacheExecutor.execute {
                        try {
                            val cleared = clearAppCache()
                            runOnUiThread {
                                result.success(mapOf("cleared" to cleared))
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error("CACHE_CLEAR_FAILED", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        cacheMethodChannel?.setMethodCallHandler(null)
        cacheMethodChannel = null
        cacheExecutor.shutdown()
        super.onDestroy()
    }

    private fun cacheRoots(): List<File> {
        val roots = mutableListOf<File>()
        cacheDir?.let { roots.add(it) }
        codeCacheDir?.let { roots.add(it) }
        externalCacheDirs?.filterNotNull()?.let { roots.addAll(it) }
        return roots.distinctBy { it.absolutePath }
    }

    private fun forEachCacheFile(root: File, visit: (File) -> Unit) {
        val rootPath = try {
            root.canonicalPath
        } catch (_: Exception) {
            return
        }
        val rootPrefix = rootPath + File.separator
        val stack = java.util.ArrayDeque<File>()
        val visited = HashSet<String>()
        stack.addLast(root)
        while (stack.isNotEmpty()) {
            val file = stack.removeLast()
            val path = try {
                file.canonicalPath
            } catch (_: Exception) {
                continue
            }
            if (file != root && !path.startsWith(rootPrefix)) continue
            if (!visited.add(path)) continue
            if (file.isDirectory) {
                for (child in file.listFiles() ?: continue) stack.addLast(child)
            } else if (file.isFile) {
                visit(file)
            }
        }
    }

    private fun getCacheStatistics(): Map<String, Long> {
        var total = 0L
        var images = 0L
        var network = 0L
        var system = 0L
        for (root in cacheRoots()) {
            if (!root.exists()) continue
            forEachCacheFile(root) { file ->
                val length = file.length()
                total += length
                val path = file.absolutePath.lowercase()
                if (path.contains("image") || path.endsWith(".png") ||
                    path.endsWith(".jpg") || path.endsWith(".jpeg") ||
                    path.endsWith(".webp") || path.endsWith(".gif")
                ) {
                    images += length
                } else if (path.contains("http") || path.contains("webview") ||
                    path.contains("dio") || path.endsWith(".tmp")
                ) {
                    network += length
                } else {
                    system += length
                }
            }
        }
        return mapOf(
            "total" to total,
            "images" to images,
            "network" to network,
            "system" to system,
        )
    }

    private fun clearAppCache(): Long {
        var clearedBytes = 0L
        for (root in cacheRoots()) {
            if (!root.isDirectory) continue
            val rootPath = try {
                root.canonicalPath
            } catch (_: Exception) {
                continue
            }
            for (entry in root.listFiles() ?: continue) {
                clearedBytes += clearCacheEntry(rootPath, entry)
            }
        }
        return clearedBytes
    }

    private fun clearCacheEntry(rootPath: String, entry: File): Long {
        val path = try {
            entry.canonicalPath
        } catch (_: Exception) {
            return 0L
        }
        if (!path.startsWith(rootPath + File.separator)) return 0L

        var clearedBytes = 0L
        if (entry.isDirectory) {
            for (child in entry.listFiles() ?: emptyArray()) {
                clearedBytes += clearCacheEntry(rootPath, child)
            }
        }
        val entryBytes = if (entry.isFile) entry.length() else 0L
        if (entry.delete()) clearedBytes += entryBytes
        return clearedBytes
    }
}

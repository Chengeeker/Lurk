package com.lurk

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val COOKIE_CHANNEL = "com.lurk/cookie_manager"
    private val APP_CHANNEL = "com.lurk/app"
    private var appMethodChannel: MethodChannel? = null
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
    }
}

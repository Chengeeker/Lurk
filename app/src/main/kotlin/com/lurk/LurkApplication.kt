package com.lurk

import android.app.Application
import android.os.Build
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.decode.GifDecoder
import coil.decode.ImageDecoderDecoder
import coil.disk.DiskCache
import coil.memory.MemoryCache
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

class LurkApplication : Application(), ImageLoaderFactory {
    override fun newImageLoader() = ImageLoader.Builder(this)
        .components { if (Build.VERSION.SDK_INT >= 28) add(ImageDecoderDecoder.Factory()) else add(GifDecoder.Factory()) }
        .memoryCache { MemoryCache.Builder(this).maxSizePercent(.18).build() }
        .diskCache { DiskCache.Builder().directory(java.io.File(cacheDir, "image_cache")).maxSizeBytes(200L * 1024 * 1024).build() }
        .okHttpClient { OkHttpClient.Builder().connectTimeout(15, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS).addInterceptor { chain -> chain.proceed(chain.request().newBuilder().header("User-Agent", "bdtb for Android 12.41.7.1").header("Referer", "https://tieba.baidu.com/").build()) }.build() }
        .build()
}

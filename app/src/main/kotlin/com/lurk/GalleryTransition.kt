package com.lurk

import android.graphics.Bitmap
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import kotlin.math.*

internal data class ImageGeometry(val viewport: Rect, val plane: Rect, val radius: Float = 0f)
internal data class ImageFlight(val bitmap: Bitmap, val from: ImageGeometry, val to: ImageGeometry, val landingBitmap: Bitmap? = null)

private val galleryBarrierEasing = CubicBezierEasing(.25f, .1f, .25f, 1f)

internal fun galleryBackdropAlpha(routeAlpha: Float, dragFraction: Float): Float {
    if (dragFraction != 0f) return routeAlpha * (1f - dragFraction).coerceAtLeast(0f)
    val barrierAlpha = galleryBarrierEasing.transform(routeAlpha)
    return routeAlpha + barrierAlpha * (1f - routeAlpha)
}

internal fun galleryHeroProgress(progress: Float): Float =
    FastOutSlowInEasing.transform(progress.coerceIn(0f, 1f))

internal fun visibleGalleryGeometry(geometry: ImageGeometry, screen: Rect, horizontalOffset: Float): ImageGeometry {
    val offset = Offset(horizontalOffset, 0f)
    return geometry.copy(viewport = geometry.viewport.translate(offset).intersect(screen), plane = geometry.plane.translate(offset))
}

// ExtendedImage's critically damped fling, also used by RedNote's image player.
internal fun galleryPanProgress(seconds: Float): Float {
    val t = seconds.coerceAtLeast(0f).toDouble()
    val rate = sqrt(500.0)
    return (1.01 + (-1.01 + (.4 - rate * 1.01) * t) * exp(-rate * t)).toFloat().coerceIn(0f, 1f)
}

internal fun boundedImagePan(offset: Offset, plane: Rect, viewport: Rect, scale: Float): Offset {
    val x = ((plane.width * scale - viewport.width) / 2f).coerceAtLeast(0f)
    val y = ((plane.height * scale - viewport.height) / 2f).coerceAtLeast(0f)
    return Offset(offset.x.coerceIn(-x, x), offset.y.coerceIn(-y, y))
}

internal fun snapshotGalleryDrawable(drawable: android.graphics.drawable.Drawable): Bitmap? {
    if (drawable is android.graphics.drawable.BitmapDrawable) return drawable.bitmap.takeUnless { it.isRecycled }
    val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: return null
    val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: return null
    val ratio = min(1f, 2400f / max(width, height))
    val bitmap = Bitmap.createBitmap(max(1, (width * ratio).roundToInt()), max(1, (height * ratio).roundToInt()), Bitmap.Config.ARGB_8888)
    val bounds = android.graphics.Rect(drawable.bounds)
    return try {
        drawable.setBounds(0, 0, bitmap.width, bitmap.height)
        drawable.draw(android.graphics.Canvas(bitmap))
        bitmap
    } catch (_: RuntimeException) { bitmap.recycle(); null }
    finally { drawable.bounds = bounds }
}

internal fun fittedImagePlane(viewport: Rect, pixels: Size, crop: Boolean): Rect {
    require(pixels.width > 0f && pixels.height > 0f && !viewport.isEmpty)
    val sx = viewport.width / pixels.width; val sy = viewport.height / pixels.height
    val scale = if (crop) max(sx, sy) else min(sx, sy)
    val half = Offset(pixels.width * scale / 2f, pixels.height * scale / 2f)
    return Rect(viewport.center - half, viewport.center + half)
}

internal fun imageGeometryAt(flight: ImageFlight, progress: Float): ImageGeometry {
    val t = progress.coerceIn(0f, 1f)
    return ImageGeometry(lerp(flight.from.viewport, flight.to.viewport, t), lerp(flight.from.plane, flight.to.plane, t),
        flight.from.radius + (flight.to.radius - flight.from.radius) * t)
}

internal fun transformedImagePlane(plane: Rect, viewport: Rect, scale: Float, pan: Offset): Rect =
    Rect(viewport.center + (plane.topLeft - viewport.center) * scale + pan,
        viewport.center + (plane.bottomRight - viewport.center) * scale + pan)

@Composable
internal fun GalleryImageFlight(flight: ImageFlight, progress: () -> Float) {
    val painter = remember { GalleryFlightPainter() }
    Canvas(Modifier.fillMaxSize().graphicsLayer()) {
        drawIntoCanvas { painter.draw(it.nativeCanvas, flight, progress()) }
    }
}

internal fun drawGalleryFlight(canvas: android.graphics.Canvas, flight: ImageFlight, progress: Float) =
    GalleryFlightPainter().draw(canvas, flight, progress)

private class GalleryFlightPainter {
    private val viewport = android.graphics.RectF()
    private val plane = android.graphics.RectF()
    private val path = android.graphics.Path()
    private val paint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)
    private val blend = android.graphics.PorterDuffXfermode(android.graphics.PorterDuff.Mode.ADD)

    fun draw(canvas: android.graphics.Canvas, flight: ImageFlight, progress: Float) {
        val geometry = imageGeometryAt(flight, progress)
        viewport.set(geometry.viewport.left, geometry.viewport.top, geometry.viewport.right, geometry.viewport.bottom)
        plane.set(geometry.plane.left, geometry.plane.top, geometry.plane.right, geometry.plane.bottom)
        val landing = flight.landingBitmap?.takeUnless { it === flight.bitmap || it.isRecycled }
        val landingAlpha = ((progress - .8f) * 5f * 255f).roundToInt().coerceIn(0, 255)
        canvas.save()
        if (geometry.radius > 0f) {
            path.rewind()
            path.addRoundRect(viewport, geometry.radius, geometry.radius, android.graphics.Path.Direction.CW)
            canvas.clipPath(path)
        } else canvas.clipRect(viewport)
        if (landing == null || landingAlpha == 0) {
            canvas.drawBitmap(flight.bitmap, null, plane, paint)
        } else if (landingAlpha == 255) {
            canvas.drawBitmap(landing, null, plane, paint)
        } else {
            // Blend premultiplied pixels in a bounded layer so transparent images stay transparent.
            val layer = canvas.saveLayer(viewport, null)
            paint.alpha = 255 - landingAlpha
            canvas.drawBitmap(flight.bitmap, null, plane, paint)
            paint.alpha = landingAlpha
            paint.xfermode = blend
            canvas.drawBitmap(landing, null, plane, paint)
            paint.alpha = 255
            paint.xfermode = null
            canvas.restoreToCount(layer)
        }
        canvas.restore()
    }
}

package com.lurk

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.ui.geometry.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class GalleryTransitionTest {
    @Test fun anOldOverlayCannotRevealANewerSource() {
        val origins = GalleryOrigins()
        val old = Any()
        val next = Any()
        origins.hide(old, "same-image")
        origins.hide(next, "same-image")
        origins.reveal(old)
        assertEquals("same-image", origins.hidden)
        origins.reveal(next)
        assertNull(origins.hidden)
    }

    @Test fun heroPopAndPagePopFollowTheirDifferentFlutterReverseCurves() {
        val hero = CubicBezierEasing(.4f, 0f, .2f, 1f)
        val routeReverse = CubicBezierEasing(.55f, .055f, .675f, .19f)
        for (t in listOf(.1f, .25f, .5f, .8f, .95f)) {
            val routeValue = 1f - t
            val flippedHero = 1f - hero.transform(1f - routeValue)
            assertEquals(1f - flippedHero, galleryHeroProgress(t), .001f)
            assertEquals(1f - routeReverse.transform(routeValue), routePopEasing.transform(t), .001f)
        }
        assertEquals(0f, galleryBackdropAlpha(0f, 0f))
        assertEquals(.5f, galleryBackdropAlpha(1f, .5f))
        assertEquals(1f, galleryBackdropAlpha(1f, 0f))
        assertTrue(galleryBackdropAlpha(.5f, 0f) > .8f)
    }

    @Test fun zoomedPanStaysInsideTheActualImageAndFlingSettles() {
        val viewport = Rect(0f, 0f, 400f, 800f)
        val plane = fittedImagePlane(viewport, Size(800f, 400f), crop = false)
        assertEquals(Offset(300f, 0f), boundedImagePan(Offset(1000f, 200f), plane, viewport, 2.5f))
        assertEquals(0f, galleryPanProgress(0f))
        assertTrue(galleryPanProgress(.12f) > galleryPanProgress(.06f))
        assertEquals(1f, galleryPanProgress(.5f))
    }

    @Test fun galleryReturnsOnlyToTheVisibleImageInTheOpenedCard() {
        val origins = GalleryOrigins()
        val scope = Any()
        val item = Media("same-url")
        val viewport = Rect(0f, 0f, 400f, 800f)
        val visible = Rect(12f, 50f, 100f, 130f)
        val drawable = android.graphics.drawable.ColorDrawable(Color.RED)
        origins.sources["duplicate-card"] = GalleryOrigin(visible, item, 8f, true, Any(), 1) { drawable }
        origins.sources["offscreen"] = GalleryOrigin(visible.translate(Offset(0f, 900f)), item, 8f, true, scope, 1) { drawable }
        origins.sources["loading"] = GalleryOrigin(visible, item, 8f, true, scope, 1) { null }
        assertNull(origins.returnTarget(scope, 1, item.original, viewport))
        origins.sources["opened-card"] = GalleryOrigin(visible, item, 8f, true, scope, 1) { drawable }
        assertEquals("opened-card", origins.returnTarget(scope, 1, item.original, viewport)?.key)
        assertNull(origins.returnTarget(scope, 0, item.original, viewport))
    }

    @Test fun animatedDrawableSnapshotsFreezeTheCurrentFrameAndRestoreBounds() {
        var color = Color.RED
        val drawable = object : android.graphics.drawable.Drawable() {
            override fun getIntrinsicWidth() = 4000
            override fun getIntrinsicHeight() = 1000
            override fun draw(canvas: Canvas) { canvas.drawColor(color) }
            override fun setAlpha(alpha: Int) {}
            override fun setColorFilter(filter: android.graphics.ColorFilter?) {}
            @Suppress("DEPRECATION") override fun getOpacity() = android.graphics.PixelFormat.OPAQUE
        }
        drawable.setBounds(7, 11, 407, 111)
        val originalBounds = android.graphics.Rect(drawable.bounds)
        val first = snapshotGalleryDrawable(drawable)!!
        color = Color.BLUE
        val second = snapshotGalleryDrawable(drawable)!!
        assertEquals(2400, first.width); assertEquals(600, first.height)
        assertEquals(Color.RED, first.getPixel(50, 50)); assertEquals(Color.BLUE, second.getPixel(50, 50))
        assertEquals(originalBounds, drawable.bounds)
        assertSame(first, snapshotGalleryDrawable(android.graphics.drawable.BitmapDrawable(null, first)))
    }

    private fun picture() = Bitmap.createBitmap(160, 320, Bitmap.Config.ARGB_8888).apply {
        for (y in 0 until height) for (x in 0 until width) setPixel(x, y, Color.rgb(x * 255 / width, y * 255 / height, 100))
    }

    @Test fun cropPlaneAndViewportMoveIndependentlyAndMeetSourceWithoutSnap() {
        val bitmap = picture()
        val pixels = Size(160f, 320f)
        val thumbnail = Rect(20f, 80f, 120f, 180f)
        val screen = Rect(0f, 0f, 360f, 640f)
        val source = ImageGeometry(thumbnail, fittedImagePlane(thumbnail, pixels, true), 8f)
        val target = ImageGeometry(screen, fittedImagePlane(screen, pixels, false))
        assertEquals(Rect(20f, 30f, 120f, 230f), source.plane)
        assertEquals(Rect(20f, 0f, 340f, 640f), target.plane)
        val flight = ImageFlight(bitmap, target, source)
        val midpoint = imageGeometryAt(flight, .5f)
        assertEquals(.5f, midpoint.plane.width / midpoint.plane.height, .0001f)
        val atEnd = Bitmap.createBitmap(360, 640, Bitmap.Config.ARGB_8888)
        drawGalleryFlight(Canvas(atEnd), flight, 1f)
        // Independently draw the original thumbnail using the source-pixel crop.
        val original = Bitmap.createBitmap(360, 640, Bitmap.Config.ARGB_8888)
        Canvas(original).drawBitmap(bitmap, android.graphics.Rect(0, 80, 160, 240), android.graphics.Rect(20, 80, 120, 180), android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG))
        for (y in 90..170) for (x in 30..110) assertEquals(original.getPixel(x, y), atEnd.getPixel(x, y))
        assertEquals(source, imageGeometryAt(flight, 1f))
        assertEquals(target, imageGeometryAt(flight, 0f))
    }

    @Test fun returnStartsAtActualZoomPanAndCanReverseAnIncompleteOpening() {
        val bitmap = picture(); val viewport = Rect(0f, 0f, 360f, 640f)
        val plane = fittedImagePlane(viewport, Size(160f, 320f), false)
        val zoomed = transformedImagePlane(plane, viewport, 2.5f, Offset(35f, -120f))
        assertEquals(plane.width * 2.5f, zoomed.width, .001f)
        assertEquals(viewport.center + Offset(35f, -120f), zoomed.center)
        val source = ImageGeometry(Rect(20f, 80f, 120f, 180f), Rect(20f, 30f, 120f, 230f), 8f)
        val opening = ImageFlight(bitmap, source, ImageGeometry(viewport, plane))
        val openedAt = .37f
        val interrupted = imageGeometryAt(opening, galleryHeroProgress(openedAt))
        val returning = ImageFlight(bitmap, interrupted, source)
        assertEquals(interrupted, imageGeometryAt(returning, 0f))
        assertEquals(source, imageGeometryAt(returning, 1f))
        val shifted = visibleGalleryGeometry(ImageGeometry(viewport, zoomed), viewport, -80f)
        assertEquals(Rect(0f, 0f, 280f, 640f), shifted.viewport)
        assertEquals(zoomed.translate(Offset(-80f, 0f)), shifted.plane)
        val fitSource = fittedImagePlane(Rect(10f, 20f, 210f, 100f), Size(160f, 320f), false)
        assertEquals(Rect(90f, 20f, 130f, 100f), fitSource)
    }

    @Test fun returnCrossfadesIntoTheActualThumbnailWithoutLosingTransparency() {
        val original = Bitmap.createBitmap(32, 32, Bitmap.Config.ARGB_8888).apply { eraseColor(0x80ff0000.toInt()) }
        val thumbnail = Bitmap.createBitmap(16, 16, Bitmap.Config.ARGB_8888).apply { eraseColor(0x800000ff.toInt()) }
        val geometry = ImageGeometry(Rect(0f, 0f, 32f, 32f), Rect(0f, 0f, 32f, 32f))
        val flight = ImageFlight(original, geometry, geometry, thumbnail)
        val result = Bitmap.createBitmap(32, 32, Bitmap.Config.ARGB_8888)
        drawGalleryFlight(Canvas(result), flight, .9f)
        val halfway = result.getPixel(16, 16)
        assertEquals(128f, Color.alpha(halfway).toFloat(), 1f)
        assertEquals(128f, Color.red(halfway).toFloat(), 3f)
        assertEquals(128f, Color.blue(halfway).toFloat(), 3f)
        result.eraseColor(Color.TRANSPARENT)
        drawGalleryFlight(Canvas(result), flight, 1f)
        assertEquals(thumbnail.getPixel(8, 8), result.getPixel(16, 16))
    }
}

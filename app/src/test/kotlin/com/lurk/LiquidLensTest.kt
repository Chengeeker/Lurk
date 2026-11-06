package com.lurk

import android.graphics.*
import androidx.compose.ui.geometry.Offset
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LiquidLensTest {
    @Test fun referenceShaderSeparatesBackdropPixelsFromTheMovingGlassShape() {
        val optics = GlassOptics(org.robolectric.RuntimeEnvironment.getApplication())
        val background = Bitmap.createBitmap(256, 86, Bitmap.Config.ARGB_8888)
        Canvas(background).apply {
            drawColor(Color.RED)
            drawRect(0f, 43f, 256f, 86f, Paint().apply { color = Color.BLUE })
        }
        optics.shader.setInputShader("background", BitmapShader(background, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP))
        val frame = Bitmap.createBitmap(256, 86, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(frame)
        Canvas::class.java.getMethod("setHwFeaturesInSwModeEnabled", Boolean::class.javaPrimitiveType).invoke(canvas, true)
        fun draw(shape: androidx.compose.ui.geometry.Rect, active: Boolean) {
            frame.eraseColor(Color.TRANSPARENT)
            optics.configure(androidx.compose.ui.geometry.Size(256f, 86f), shape, 1f, true,
                lens = active, pressed = if (active) 1f else 0f, dragging = active)
            canvas.drawPaint(Paint().apply { shader = optics.shader })
        }
        draw(androidx.compose.ui.geometry.Rect(20f, 15f, 236f, 71f), false)
        assertEquals(0, Color.alpha(frame.getPixel(4, 43)))
        assertTrue(Color.red(frame.getPixel(128, 30)) > 100)
        assertTrue(Color.blue(frame.getPixel(128, 55)) > 100)
        draw(androidx.compose.ui.geometry.Rect(162f, 11f, 232f, 75f), true)
        assertEquals(0, Color.alpha(frame.getPixel(59, 43)))
        assertEquals(255, Color.alpha(frame.getPixel(198, 43)))
    }

    @Test fun lensHasFlatCenterBoundedRimAndDensityIndependentShape() {
        assertEquals(Offset.Zero, lensDisplacement(150f, 28f, 300f, 56f, 10f, 1.19f))
        val top = lensDisplacement(150f, 2f, 300f, 56f, 10f, 1.19f)
        val bottom = lensDisplacement(150f, 54f, 300f, 56f, 10f, 1.19f)
        assertTrue(top.y > 10f && top.y <= 28f)
        assertEquals(-top.y, bottom.y, .001f)
        val scaled = lensDisplacement(450f, 6f, 900f, 168f, 30f, 1.19f)
        assertEquals(top.y * 3, scaled.y, .001f)
        for (y in 0..56) for (x in 0..300) {
            val shift = lensDisplacement(x.toFloat(), y.toFloat(), 300f, 56f, 10f, 1.19f)
            assertTrue(shift.getDistance().isFinite() && shift.getDistance() <= 28.001f)
        }
    }

    @Test fun galleryButtonKeepsItsCenterAndOnlyShiftsTheRimByASubpixel() {
        val input = RuntimeShader("half4 main(float2 p) { return half4(p.x / 100.0, p.y / 100.0, 0.0, 1.0); }")
        val shader = RuntimeShader(GALLERY_BUTTON_SHADER).apply {
            setInputShader("image", input); setFloatUniform("resolution", 44f, 44f); setFloatUniform("inset", 20f)
        }
        val result = Bitmap.createBitmap(84, 84, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        Canvas::class.java.getMethod("setHwFeaturesInSwModeEnabled", Boolean::class.javaPrimitiveType).invoke(canvas, true)
        canvas.drawPaint(Paint().apply { this.shader = shader })
        assertEquals(42.5f * 255 / 100, Color.red(result.getPixel(42, 42)).toFloat(), 1f)
        val rim = Color.red(result.getPixel(62, 42)).toFloat()
        assertTrue(rim > 62.5f * 255 / 100)
        assertTrue(rim < 63.5f * 255 / 100)
    }

    @Test fun nativeShaderActuallyRefractsPixelsAndMatchesCompatibilityLens() {
        val source = Bitmap.createBitmap(340, 96, Bitmap.Config.ARGB_8888)
        for (y in 0 until source.height) for (x in 0 until source.width) source.setPixel(x, y, Color.rgb(y * 255 / 96, y * 255 / 96, y * 255 / 96))
        val shader = RuntimeShader(LIQUID_LENS_SHADER).apply {
            setInputShader("image", BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP))
            configureLiquidShader(this, androidx.compose.ui.geometry.Size(300f, 56f), 20f, 3f, LiquidMaterial())
        }
        val result = Bitmap.createBitmap(340, 96, Bitmap.Config.ARGB_8888)
        val shaderCanvas = Canvas(result)
        // Test-only: run Skia's runtime effect on the host CPU, not a device GPU.
        Canvas::class.java.getMethod("setHwFeaturesInSwModeEnabled", Boolean::class.javaPrimitiveType).invoke(shaderCanvas, true)
        shaderCanvas.drawPaint(Paint().apply { this.shader = shader })
        assertEquals(Color.green(source.getPixel(170, 48)), Color.green(result.getPixel(170, 48)))
        val shift = lensDisplacement(150.5f, 2.5f, 300f, 56f, 10f, 1.19f)
        val observed = Color.green(result.getPixel(170, 22))
        assertTrue("rim must move actual content", observed > Color.green(source.getPixel(170, 22)) + 25)
        assertEquals((22.5f + shift.y) * 255 / 96, observed.toFloat(), 6f)
        val mesh = lensMesh(300f, 56f, 10f, 1.19f, 20f, 6f)
        assertTrue(mesh.size in 100..300)
        val legacy = Bitmap.createBitmap(300, 56, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(legacy)
        mesh.forEach { triangle ->
            canvas.save(); canvas.clipPath(triangle.clip); canvas.concat(triangle.transform)
            canvas.drawBitmap(source, 0f, 0f, Paint(Paint.FILTER_BITMAP_FLAG)); canvas.restore()
        }
        assertTrue(Color.green(legacy.getPixel(150, 2)) > Color.green(source.getPixel(170, 22)) + 25)
        assertEquals(Color.green(source.getPixel(170, 48)).toFloat(), Color.green(legacy.getPixel(150, 28)).toFloat(), 3f)
        val file = java.io.File("build/reports/appearance/lens.png").apply { parentFile?.mkdirs() }
        file.outputStream().use { result.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}

package com.lurk

import android.os.Build
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.*
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.graphics.layer.*
import androidx.compose.ui.layout.*
import androidx.compose.ui.unit.*

class BackdropSource(val layer: GraphicsLayer) { var revision = 0L; var offset by mutableStateOf(Offset.Zero); var coordinates: LayoutCoordinates? = null; var underlay: BackdropSource? = null }
val LocalBackdrop = staticCompositionLocalOf<BackdropSource?> { null }
@Composable
fun rememberBackdrop(flatten: Boolean = false): BackdropSource { val layer = rememberGraphicsLayer(); layer.compositingStrategy = if (flatten) androidx.compose.ui.graphics.layer.CompositingStrategy.Offscreen else androidx.compose.ui.graphics.layer.CompositingStrategy.Auto; return remember(layer) { BackdropSource(layer) } }
fun Modifier.backdropSource(source: BackdropSource) = onGloballyPositioned { source.coordinates = it; source.offset = it.positionInWindow() }.drawWithContent {
    source.layer.record { this@drawWithContent.drawContent() }
    drawLayer(source.layer)
    source.revision++
}

// Record commands on the GPU; overscan the blur kernel before sampling the local lens.
internal fun Modifier.backdrop(blur: Float = 2f, refraction: Float = 0f, refractiveIndex: Float = 1.19f, dispersion: Float = .008f, material: LiquidMaterial? = null, galleryButton: Boolean = false): Modifier = composed {
    val source = LocalBackdrop.current ?: return@composed this
    val region = rememberGraphicsLayer()
    val lens = material ?: if (refraction > 0f) LiquidMaterial(refraction, refractiveIndex, dispersion) else null
    val lensShader = remember(lens != null, galleryButton) { if (Build.VERSION.SDK_INT >= 33 && (lens != null || galleryButton)) android.graphics.RuntimeShader(if (galleryButton) GALLERY_BUTTON_SHADER else LIQUID_LENS_SHADER) else null }
    var position by remember { mutableStateOf(Offset.Zero) }
    var coordinates: LayoutCoordinates? by remember { mutableStateOf(null) }
    this.onGloballyPositioned { coordinates = it; position = it.positionInWindow() }.drawWithCache {
        val margin = kotlin.math.ceil(maxOf(blur * density * 3f + 2f, if (lens != null) 20f * density else 0f)).toInt()
        val regionSize = IntSize(kotlin.math.ceil(size.width).toInt() + margin * 2, kotlin.math.ceil(size.height).toInt() + margin * 2)
        val shader = if (Build.VERSION.SDK_INT >= 33) lensShader?.apply {
            if (galleryButton) { setFloatUniform("resolution", size.width, size.height); setFloatUniform("inset", margin.toFloat()) }
            else if (lens != null) configureLiquidShader(this, size, margin.toFloat(), density, lens)
        } else null
        region.compositingStrategy = androidx.compose.ui.graphics.layer.CompositingStrategy.Offscreen
        region.renderEffect = if (Build.VERSION.SDK_INT >= 31) {
            val blurEffect = if (blur > 0f) android.graphics.RenderEffect.createBlurEffect(blur * density, blur * density, android.graphics.Shader.TileMode.CLAMP) else null
            val effect = if (Build.VERSION.SDK_INT >= 33 && shader != null) android.graphics.RenderEffect.createRuntimeShaderEffect(shader, "image") else null
            (if (effect != null && blurEffect != null) android.graphics.RenderEffect.createChainEffect(effect, blurEffect) else effect ?: blurEffect)?.asComposeRenderEffect()
        } else null
        // shortcut: pre-33 uses an affine lens without RGB dispersion; full spectral parity needs an older-API shader renderer.
        val mesh = if (Build.VERSION.SDK_INT < 33 && lens != null) lensMesh(size.width, size.height, (lens.thickness * lens.visibility * density / 3f).coerceAtLeast(.001f), 1f + (lens.index - 1f) * lens.visibility, margin.toFloat(), 6f * density) else emptyList()
        val weights = floatArrayOf(1f, 2f, 1f)
        val kernel = (0..8).map { Paint().apply { alpha = weights[it % 3] * weights[it / 3] / 16f; blendMode = BlendMode.Plus } }
        val transform = android.graphics.Matrix()
        val basis = floatArrayOf(0f, 0f, 256f, 0f, 0f, 256f)
        val mapped = FloatArray(6)
        onDrawWithContent {
            region.record(size = regionSize) {
                fun DrawScope.paintLayer(layer: BackdropSource, x: Float, y: Float) {
                    val target = coordinates; val origin = layer.coordinates
                    val offset = layer.offset - position + Offset(margin.toFloat(), margin.toFloat())
                    if (target != null && origin != null && target.isAttached && origin.isAttached) {
                        for (i in 0..2) {
                            val point = target.localPositionOf(origin, Offset(basis[i * 2], basis[i * 2 + 1]))
                            mapped[i * 2] = point.x + margin + x; mapped[i * 2 + 1] = point.y + margin + y
                        }
                        transform.setPolyToPoly(basis, 0, mapped, 0, 3)
                        val canvas = drawContext.canvas.nativeCanvas
                        canvas.save(); canvas.concat(transform); drawLayer(layer.layer); canvas.restore()
                    } else {
                        translate(offset.x + x, offset.y + y) { drawLayer(layer.layer) }
                    }
                }
                fun DrawScope.paintBackdrop(x: Float = 0f, y: Float = 0f) {
                    source.underlay?.let { paintLayer(it, x, y) }
                    paintLayer(source, x, y)
                }
                if (Build.VERSION.SDK_INT >= 31 || blur == 0f) paintBackdrop()
                else {
                    // shortcut: pre-31 uses a nine-tap blur; increase only after profiling legacy GPUs.
                    for (y in -1..1) for (x in -1..1) {
                        drawContext.canvas.saveLayer(Rect(Offset.Zero, size), kernel[(y + 1) * 3 + x + 1])
                        paintBackdrop(x * blur * density, y * blur * density)
                        drawContext.canvas.restore()
                    }
                }
                if (Build.VERSION.SDK_INT < 33 && lens != null) drawRect(lens.tint.copy(alpha = lens.tint.alpha * lens.visibility))
            }
            clipRect {
                if (mesh.isEmpty()) translate(-margin.toFloat(), -margin.toFloat()) { drawLayer(region) }
                else {
                    val canvas = drawContext.canvas.nativeCanvas
                    for (triangle in mesh) {
                        canvas.save(); canvas.clipPath(triangle.clip); canvas.concat(triangle.transform)
                        drawLayer(region)
                        canvas.restore()
                    }
                }
            }
            drawContent()
        }
    }
}

val LocalContentTop = staticCompositionLocalOf { 0.dp }
val LocalFrostedHeader = staticCompositionLocalOf { false }
@Composable
fun FrostedFrame(headerHeight: Dp = 56.dp, header: @Composable () -> Unit, content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    val backdrop = rememberBackdrop(); val colors = androidx.compose.material3.MaterialTheme.colorScheme
    Box(Modifier.fillMaxSize()) {
        CompositionLocalProvider(LocalContentTop provides (headerHeight + WindowInsets.statusBars.asPaddingValues().calculateTopPadding())) { androidx.compose.foundation.layout.Column(Modifier.fillMaxSize().backdropSource(backdrop), content = content) }
        CompositionLocalProvider(LocalBackdrop provides backdrop, LocalFrostedHeader provides true) {
            Box(Modifier.fillMaxWidth().clipToBounds().backdrop(20f).frostedTint(colors.background, colors.outlineVariant)) { header() }
        }
    }
}
fun Modifier.frostedTint(surface: Color, border: Color) = drawWithContent {
    drawRect(surface.copy(alpha = .45f)); drawRect(Brush.verticalGradient(listOf(surface.copy(alpha = .95f), Color.Transparent)))
    drawContent(); drawLine(border.copy(alpha = .24f), Offset(0f, size.height), Offset(size.width, size.height), .5f * density)
}


@Composable
fun FrostedHeading(content: @Composable ColumnScope.() -> Unit) {
    val colors = androidx.compose.material3.MaterialTheme.colorScheme
    CompositionLocalProvider(LocalFrostedHeader provides true) {
        Column(Modifier.fillMaxWidth().frostedTint(colors.background, colors.outlineVariant), content = content)
    }
}

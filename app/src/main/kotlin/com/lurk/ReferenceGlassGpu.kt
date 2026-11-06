package com.lurk

import android.content.Context
import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import androidx.annotation.RequiresApi
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.CompositingStrategy
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

// Optical configuration and fixed-canvas pass ordering adapted from RedNote Compose.
@RequiresApi(33)
internal class GlassOptics(context: Context) {
    val shader =
        RuntimeShader(
            context.assets.open("glass/liquid_glass.agsl").bufferedReader().use { it.readText() }
        )

    fun moveShape(shape: Rect) {
        shader.setFloatUniform("shape", shape.center.x, shape.center.y, shape.width, shape.height)
        shader.setFloatUniform("uGeometryOffset", shape.left, shape.top)
        shader.setFloatUniform("uGeometrySize", shape.width, shape.height)
        shader.setFloatUniform("uTouchPosition", shape.center.x, shape.center.y)
    }

    fun configure(
        size: Size,
        shape: Rect,
        density: Float,
        dark: Boolean,
        lens: Boolean = false,
        pressed: Float = 0f,
        dragging: Boolean = false,
        galleryButton: Boolean = false,
        touch: Float = 0f,
    ) {
        val fade = if (lens) pressed.coerceIn(.001f, 1f) else 1f
        val dpr = density / 3f
        val ri = if (lens) 1f + .18f * fade else if (galleryButton) 1.24f else 1.16f
        val thickness = (if (lens) 20f * fade else if (galleryButton) 32f else 10f) * dpr
        val rgb =
            if (lens) {
                if (dark) 1f else 0f
            } else {
                if (dark || galleryButton) 0f else 1f
            }
        moveShape(shape)
        shader.apply {
            setFloatUniform("uSize", size.width, size.height)
            setFloatUniform(
                "uGlassColor",
                rgb,
                rgb,
                rgb,
                (if (lens) {
                    if (dark) 38f / 255 else 24f / 255
                } else {
                    if (dark || galleryButton) .4f else 240f / 255
                }) * fade,
            )
            setFloatUniform(
                "uOpticalProps",
                ri,
                if (lens || galleryButton) .025f * fade else .008f,
                thickness,
                1f,
            )
            setFloatUniform(
                "uLightConfig",
                (if (lens) 2f else .25f) * fade,
                0f,
                if (lens || galleryButton) 1.5f else 1f,
            )
            setFloatUniform("uLightDirection", -.7071068f, .7071068f)
            setFloatUniform("uWhiten", 0f)
            setFloatUniform("uWhitenGated", 1f)
            setFloatUniform(
                "uPinchStrength",
                if (lens && dragging) .7f * (1 - (1 - fade) * (1 - fade)) else 0f,
            )
            setFloatUniform("uBackgroundFallback", 0f, 0f, 0f, 0f)
            setFloatUniform("uCaptureOffset", 0f, 0f)
            setFloatUniform("uEdgeConfig", 0f, fade, dpr, 0f)
            setFloatUniform("uPlatformViewMode", 0f)
            setFloatUniform("uBodyMode", 1f)
            setFloatUniform("uTouchIntensity", (if (galleryButton) touch else pressed) * .125f)
            setFloatUniform(
                "uRimConfig",
                if (lens && !dark) .12f * fade else 0f,
                (if (galleryButton) 0f
                else if (dark) {
                    if (lens) 0f else .12f
                } else {
                    if (lens) .35f else 1f
                }) * fade,
                .2f,
            )
            setFloatUniform("uLensModel", 0f)
            setFloatUniform("uFrost", 0f, 0f, 0f, 1f)
            setFloatUniform("uBodyShade", 0f)
            setFloatUniform("uNativeEdge", if (!dark && lens) 1f else 0f)
        }
    }

    fun effect(): androidx.compose.ui.graphics.RenderEffect =
        RenderEffect.createRuntimeShaderEffect(shader, "background").asComposeRenderEffect()
}

private fun glassBlur(sigma: Float): BlurEffect {
    val radius = ((sigma - .5f) / .57735f).coerceAtLeast(.01f)
    return BlurEffect(radius, radius, TileMode.Clamp)
}

private fun DrawScope.recordGlassCrop(
    crop: GraphicsLayer,
    source: BackdropSource,
    coords: LayoutCoordinates,
    dimensions: IntSize,
    sceneColor: Color,
) {
    val origin = coords.localToWindow(Offset.Zero)
    val extent = coords.localToWindow(Offset(size.width, size.height)) - origin
    if (extent.x <= 0f || extent.y <= 0f) return
    crop.record(this, layoutDirection, dimensions) {
        drawRect(sceneColor)
        scale(size.width / extent.x, size.height / extent.y, Offset.Zero) {
            translate(source.offset.x - origin.x, source.offset.y - origin.y) {
                drawLayer(source.layer)
            }
        }
    }
}

@RequiresApi(33)
@Composable
internal fun ReferenceNavigationGlass(
    source: BackdropSource,
    bodyOptics: GlassOptics,
    waterOptics: GlassOptics,
    labels: GraphicsLayer,
    selectedLabels: GraphicsLayer,
    position: () -> Float,
    velocity: () -> Float,
    expansion: () -> Float,
    dark: Boolean,
    sceneColor: Color,
    modifier: Modifier,
) {
    val crop = rememberGraphicsLayer()
    val blurred = rememberGraphicsLayer()
    val body = rememberGraphicsLayer()
    val pillBlur = rememberGraphicsLayer()
    val combined = rememberGraphicsLayer()
    val water = rememberGraphicsLayer()
    var coordinates by remember { mutableStateOf<LayoutCoordinates?>(null) }
    Box(modifier.onGloballyPositioned { coordinates = it }.drawWithCache {
        val d = density
        val dimensions = IntSize(size.width.roundToInt(), size.height.roundToInt())
        val bar = Rect(20f * d, 15f * d, size.width - 20f * d, size.height - 15f * d)
        val mask = Path()
        var previousOrigin = Offset.Unspecified
        var previousExtent = Offset.Unspecified
        var previousSource = Offset.Unspecified
        var previousRest = -1f
        var previousPill = Rect.Zero
        var previousExpansion = -1f
        var waterRecorded = false
        combined.compositingStrategy = CompositingStrategy.Offscreen
        blurred.renderEffect = glassBlur(1.5f * d)
        pillBlur.renderEffect = glassBlur(6f * d)
        bodyOptics.configure(size, bar, d, dark)
        body.renderEffect = bodyOptics.effect()
        onDrawBehind {
            val coords = coordinates?.takeIf { it.isAttached } ?: return@onDrawBehind
            val origin = coords.localToWindow(Offset.Zero)
            val extent = coords.localToWindow(Offset(size.width, size.height)) - origin
            val sourceOrigin = source.offset
            if (extent.x <= 0f || extent.y <= 0f) return@onDrawBehind
            // The recorded layers reference live GPU display lists. Only the sampling transform needs a rebuild.
            if (origin != previousOrigin || extent != previousExtent || sourceOrigin != previousSource) {
                recordGlassCrop(crop, source, coords, dimensions, sceneColor)
                blurred.record(this, layoutDirection, dimensions) { drawLayer(crop) }
                body.record(this, layoutDirection, dimensions) { drawLayer(blurred) }
                pillBlur.record(this, layoutDirection, dimensions) {
                    drawLayer(crop)
                    drawLayer(body)
                }
                previousOrigin = origin
                previousExtent = extent
                previousSource = sourceOrigin
            }
            val fraction = expansion()
            val pill = navigationLensRect(bar.width, bar.height, position(), fraction, velocity(), d).translate(bar.topLeft)
            val rest = 1f - fraction
            val showWater = fraction > .001f
            val moved = pill != previousPill
            if (moved) {
                mask.reset()
                mask.addRoundRect(RoundRect(pill, CornerRadius(minOf(pill.width, pill.height) / 2f)))
            }
            if (rest != previousRest) {
                pillBlur.alpha = rest
                water.alpha = fraction
            }
            if (moved || fraction != previousExpansion) {
                water.renderEffect = if (showWater) {
                    if (previousExpansion != fraction) {
                        waterOptics.configure(size, pill, d, dark, lens = true, pressed = fraction, dragging = true)
                    } else {
                        waterOptics.moveShape(pill)
                    }
                    waterOptics.effect()
                } else null
            }
            if (moved || rest != previousRest) {
                combined.record(this, layoutDirection, dimensions) {
                    drawLayer(body)
                    if (rest > .001f) clipPath(mask) {
                        drawLayer(pillBlur)
                        drawRect((if (dark) Color.White else Color.Black).copy(alpha = 38f / 255f * rest))
                    }
                    clipPath(mask, ClipOp.Difference) { drawLayer(labels) }
                    clipPath(mask) { drawLayer(selectedLabels) }
                }
            }
            previousPill = pill
            previousRest = rest
            previousExpansion = fraction
            drawLayer(combined)
            if (showWater) {
                if (!waterRecorded) {
                    water.record(this, layoutDirection, dimensions) {
                        drawLayer(crop)
                        drawLayer(combined)
                    }
                    waterRecorded = true
                }
                drawLayer(water)
            }
        }
    })
}

@RequiresApi(33)
@Composable
internal fun ReferenceGalleryGlass(source: BackdropSource, optics: GlassOptics, press: Float, modifier: Modifier) {
    val crop = rememberGraphicsLayer()
    val blurred = rememberGraphicsLayer()
    val glass = rememberGraphicsLayer()
    var coordinates by remember { mutableStateOf<LayoutCoordinates?>(null) }
    Box(modifier, contentAlignment = Alignment.Center) {
        Box(Modifier.requiredSize(88.dp, 78.dp).onGloballyPositioned { coordinates = it }.drawWithCache {
            val dimensions = IntSize(size.width.roundToInt(), size.height.roundToInt())
            val shape = Rect(20f * density, 15f * density, size.width - 20f * density, size.height - 15f * density)
            blurred.renderEffect = glassBlur(2f * density)
            optics.configure(size, shape, density, dark = true, galleryButton = true, touch = press)
            glass.renderEffect = optics.effect()
            onDrawBehind {
                val coords = coordinates?.takeIf { it.isAttached } ?: return@onDrawBehind
                recordGlassCrop(crop, source, coords, dimensions, Color.Black)
                blurred.record(this, layoutDirection, dimensions) { drawLayer(crop) }
                glass.record(this, layoutDirection, dimensions) { drawLayer(blurred) }
                drawLayer(glass)
            }
        })
    }
}

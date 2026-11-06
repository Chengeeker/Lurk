package com.lurk

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlin.math.*

internal const val NAVIGATION_LABEL_INSET_DP = 4f

internal fun navigationTabPosition(x: Float, width: Float, inset: Float): Float =
    ((x - inset) / ((width - 2f * inset) / 4f).coerceAtLeast(1f) - .5f).coerceIn(0f, 3f)

internal fun navigationLensRect(width: Float, height: Float, position: Float, expansion: Float, velocity: Float, density: Float): Rect {
    val inset = NAVIGATION_LABEL_INSET_DP * density
    val labelSlot = (width - 2f * inset) / 4f
    val center = Offset(inset + labelSlot * (position + .5f), height / 2f)
    val jelly = jellyScale(velocity, expansion)
    val w = (labelSlot * (1 + .06f * expansion) + 24f * density * expansion) * jelly[0]
    val h = ((height - 8f * density) * (1 + .06f * expansion) + 16f * density * expansion) * jelly[1]
    return Rect(center.x - w / 2f, center.y - h / 2f, center.x + w / 2f, center.y + h / 2f)
}

private fun Modifier.lensClip(rect: Rect, inverse: Boolean = false) = drawWithContent {
    val path = Path().apply { addRoundRect(RoundRect(rect, CornerRadius(min(rect.width, rect.height) / 2f))) }
    clipPath(path, clipOp = if (inverse) ClipOp.Difference else ClipOp.Intersect) { this@drawWithContent.drawContent() }
}

internal fun Modifier.navigationLensPlacement(rect: Rect, density: Density) =
    wrapContentSize(Alignment.TopStart, unbounded = true)
        .offset { IntOffset(rect.left.roundToInt(), rect.top.roundToInt()) }
        .requiredSize(with(density) { rect.width.toDp() }, with(density) { rect.height.toDp() })

@Composable
internal fun LiquidNavigationContent(
    position: () -> Float, velocity: () -> Float, expansion: () -> Float, dark: Boolean,
    labels: List<String>, icons: List<ImageVector>, selectedIcons: List<ImageVector>, select: (Int) -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    val page = LocalBackdrop.current
    if (android.os.Build.VERSION.SDK_INT >= 33 && page != null) {
        val context = LocalContext.current
        val optics = remember(context) { runCatching { GlassOptics(context) to GlassOptics(context) }.getOrNull() }
        if (optics != null) {
            val regular = rememberGraphicsLayer()
            val selected = rememberGraphicsLayer()
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val width = maxWidth
                val height = maxHeight
                Box(Modifier.requiredSize(width + 40.dp, height + 30.dp).align(Alignment.Center)) {
                    for (isSelected in listOf(false, true)) {
                        val layer = if (isSelected) selected else regular
                        Box(Modifier.matchParentSize().then(if (isSelected) Modifier.clearAndSetSemantics {} else Modifier)
                            .drawWithContent { layer.record { this@drawWithContent.drawContent() } },
                            contentAlignment = Alignment.Center) {
                            NavigationLabels(Modifier.size(width, height), isSelected, expansion, dark, labels, icons, selectedIcons, select)
                        }
                    }
                    ReferenceNavigationGlass(page, optics.first, optics.second, regular, selected, position,
                        velocity, expansion, dark, colors.background, Modifier.matchParentSize())
                }
            }
            return
        }
    }
    // Flatten only the small bar layers before the moving lens samples their shaders.
    val track = rememberBackdrop(flatten = true)
    val content = rememberBackdrop(flatten = true)
    track.underlay = page
    content.underlay = page
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val density = LocalDensity.current
        val fraction = expansion()
        val rect = navigationLensRect(constraints.maxWidth.toFloat(), constraints.maxHeight.toFloat(), position(), fraction, velocity(), density.density)
        val rest = 1f - fraction
        val pinch = .7f * (1f - (1f - fraction).pow(2))
        fun Modifier.at(r: Rect) = navigationLensPlacement(r, density)
        Box(Modifier.fillMaxSize().backdropSource(content)) {
            Box(Modifier.fillMaxSize().backdropSource(track)) {
                Box(Modifier.fillMaxSize().then(if (dark) Modifier else Modifier.shadow(.55.dp, RoundedCornerShape(50)))
                    .clip(RoundedCornerShape(50)).backdrop(2f, material = LiquidMaterial(
                        tint = if (dark) Color(0x66000000) else Color(0xF0FFFFFF), rimLight = if (dark) 0f else 1f)))
            }
            if (rest > 0f) CompositionLocalProvider(LocalBackdrop provides track) {
                Box(Modifier.at(rect).graphicsLayer { alpha = rest }.clip(RoundedCornerShape(50)).backdrop(6f)
                    .background(if (dark) Color(0x26FFFFFF) else Color(0x26000000)))
            }
            for (selected in listOf(false, true)) {
                NavigationLabels(Modifier.fillMaxSize().then(if (selected) Modifier.clearAndSetSemantics {} else Modifier)
                    .lensClip(rect, inverse = !selected), selected, expansion, dark, labels, icons, selectedIcons, select)
            }
        }
        // The moving lens must sample the merged track AND glyphs, never the page alone.
        // Keep the shader/node alive across presses instead of constructing it on the long-press frame.
        CompositionLocalProvider(LocalBackdrop provides content) {
            Box(Modifier.at(rect).graphicsLayer { alpha = fraction }.clip(RoundedCornerShape(50)).backdrop(0f, material = LiquidMaterial(
                thickness = 20f, index = 1.18f, dispersion = .025f,
                tint = if (dark) Color(0x26FFFFFF) else Color(0x18000000), light = .5f,
                rimShade = if (dark) 0f else .12f, rimLight = if (dark) 0f else .35f,
                visibility = fraction, pinch = pinch)))
        }
        if (!dark) Box(Modifier.fillMaxSize().border(1.dp, Color(0xF5FFFFFF), RoundedCornerShape(50)))
    }
}

@Composable
private fun NavigationLabels(
    modifier: Modifier, selected: Boolean, expansion: () -> Float, dark: Boolean,
    labels: List<String>, icons: List<ImageVector>, selectedIcons: List<ImageVector>, select: (Int) -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    val foreground = if (selected) colors.primary else if (dark) Color.White else colors.onSurfaceVariant
    Row(modifier.padding(horizontal = NAVIGATION_LABEL_INSET_DP.dp)) {
        labels.forEachIndexed { index, label ->
            Column(Modifier.weight(1f).fillMaxHeight()
                .then(if (selected) Modifier else Modifier.feedbackClickable { select(index) })
                .graphicsLayer { val scale = if (selected) 1f + .15f * expansion() else 1f; scaleX = scale; scaleY = scale },
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Icon(if (selected) selectedIcons[index] else icons[index], if (selected) null else label, Modifier.size(24.dp), tint = foreground)
                Spacer(Modifier.height(4.dp))
                Text(label, fontSize = 11.sp, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium, color = foreground)
            }
        }
    }
}

internal fun galleryButtonTransform(stretch: Offset, press: Float): FloatArray {
    val x = abs(stretch.x) / 48f; val y = abs(stretch.y) / 48f
    val sx = (1f + (x * .8f).coerceAtMost(.3f)) * (1f - (y * .3f).coerceAtMost(.15f))
    val sy = (1f + (y * .8f).coerceAtMost(.3f)) * (1f - (x * .3f).coerceAtMost(.15f))
    fun pivot(v: Float): Float { val t = (abs(v) / 20f).coerceAtMost(1f); return 48f * (.5f - sign(v) * t * t * (3f - 2f * t) * .5f) }
    val growth = 1f + press * 17f / 48f
    return floatArrayOf(growth * sx, growth * sy,
        growth * ((pivot(stretch.x) - 24f) * (1f - sx) + sx * stretch.x * .15f),
        growth * ((pivot(stretch.y) - 24f) * (1f - sy) + sy * stretch.y * .15f))
}

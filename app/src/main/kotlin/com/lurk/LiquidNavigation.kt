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
import androidx.compose.ui.layout.positionInRoot
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
    labels: List<String>, icons: List<ImageVector>, selectedIcons: List<ImageVector>, translucent: Boolean = false, select: (Int) -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    val page = LocalBackdrop.current
    if (page == null) {
        NavigationLabels(Modifier.fillMaxSize(), false, expansion, dark, labels, icons, selectedIcons, select)
        return
    }
    val regular = rememberGraphicsLayer()
    val selected = rememberGraphicsLayer()
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val width = maxWidth
        val height = maxHeight
        Box(Modifier.requiredSize(width + 40.dp, height + 30.dp).align(Alignment.Center)) {
            for (isSelected in listOf(false, true)) {
                val layer = if (isSelected) selected else regular
                Box(Modifier.matchParentSize().then(if (isSelected) Modifier.clearAndSetSemantics {} else Modifier)
                    .drawWithContent { layer.record { this@drawWithContent.drawContent() } }, contentAlignment = Alignment.Center) {
                    NavigationLabels(Modifier.size(width, height), isSelected, expansion, dark, labels, icons, selectedIcons, select)
                }
            }
            NavigationGlassMaterial(page.layer, { page.coordinates?.positionInRoot() ?: Offset.Zero }, { page.revision },
                regular, selected, position(), expansion(), dark, colors.background,
                translucent, labels.size, Modifier.matchParentSize())
        }
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

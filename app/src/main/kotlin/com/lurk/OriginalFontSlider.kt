package com.lurk

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.*
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OriginalFontSlider(value: Float, onChange: (Float) -> Unit, onFinished: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val dragged by interaction.collectIsDraggedAsState()
    val activation by animateFloatAsState(if (pressed || dragged) 1f else 0f, tween(100), label = "font indicator")
    val label = rememberTextMeasurer().measure("${value.roundToInt()}%", MaterialTheme.typography.labelMedium.copy(color = colors.onPrimary))
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    Slider(value, { onChange(it.roundToInt().toFloat()) }, Modifier.padding(horizontal = 14.dp),
        valueRange = 80f..140f, steps = 11, onValueChangeFinished = onFinished, interactionSource = interaction,
        thumb = {
            Canvas(Modifier.size(20.dp)) {
                drawCircle(colors.primary.copy(alpha = .1f * activation), 24.dp.toPx())
                drawCircle(colors.primary)
                if (activation > 0f) {
                    // Flutter's DropSliderValueIndicatorShape (BSD license in third_party/flutter).
                    val width = maxOf(20.dp.toPx(), label.size.width.toFloat()) + 8.dp.toPx()
                    translate(center.x, center.y - 16.dp.toPx()) {
                        scale(activation, activation, Offset.Zero) {
                            val path = Path().apply {
                                moveTo(0f, 0f); lineTo(-10.dp.toPx(), -10.dp.toPx()); lineTo(10.dp.toPx(), -10.dp.toPx()); close()
                                addRoundRect(RoundRect(Rect(-width / 2, -34.dp.toPx(), width / 2, -6.dp.toPx()), CornerRadius(14.dp.toPx())))
                            }
                            drawPath(path, colors.primary)
                            drawText(label, topLeft = Offset(-label.size.width / 2f, (-36 + 28f / 1.75f).dp.toPx() - label.size.height / 2f))
                        }
                    }
                }
            }
        },
        track = { state ->
            Canvas(Modifier.fillMaxWidth().height(4.dp)) {
                val fraction = ((state.value - 80f) / 60f).coerceIn(0f, 1f)
                val start = Offset(if (rtl) size.width else 0f, center.y)
                val end = Offset(if (rtl) 0f else size.width, center.y)
                drawLine(colors.surfaceContainerHighest, start, end, size.height, StrokeCap.Round)
                drawLine(colors.primary, start, Offset(if (rtl) size.width * (1 - fraction) else size.width * fraction, center.y), size.height + 2.dp.toPx(), StrokeCap.Round)
                for (i in 0..12) {
                    val f = i / 12f
                    drawCircle((if (f <= fraction) colors.onPrimary else colors.onSurfaceVariant).copy(alpha = .38f), 1.dp.toPx(), Offset(if (rtl) size.width * (1 - f) else size.width * f, center.y))
                }
            }
        })
}

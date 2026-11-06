package com.lurk

import androidx.compose.animation.core.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import kotlin.math.*

// RedNote Compose GlassMotion and the navigation pressure transition.
internal fun glassSpring(milliseconds: Int, bounce: Float): SpringSpec<Float> =
    spring(
        dampingRatio = if (bounce > 0) 1 - bounce else 1 / (1 + bounce),
        stiffness = (4 * PI * PI / (milliseconds / 1000.0).pow(2)).toFloat(),
    )

internal fun jellyScale(velocity: Float, pressure: Float = 1f): FloatArray {
    val distortion =
        if (velocity.isFinite()) (abs(velocity) / 10).coerceIn(0f, 1f) * .8f * .7f * pressure
        else 0f
    return floatArrayOf(1 - distortion * .5f, 1 + distortion * .3f)
}

@Composable
internal fun navigationGlassPressure(water: Boolean): State<Float> =
    animateFloatAsState(
        if (water) 1f else 0f,
        if (water) glassSpring(300, .15f) else tween(240, easing = FastOutSlowInEasing),
        label = "glass-thickness",
    )

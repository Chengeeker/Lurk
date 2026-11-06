package com.lurk

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.MotionDurationScale
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.changedToUpIgnoreConsumed
import androidx.compose.ui.input.pointer.pointerInput
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.abs

internal class GalleryOpeningMotion(private val scope: CoroutineScope) {
    private var job: Job? = null
    private var onClosed: (() -> Unit)? = null
    private var openDurationMillis = 330f
    var position by mutableFloatStateOf(0f)
        private set
    var returning by mutableStateOf(false)
        private set
    var holdingGesture by mutableStateOf(false)

    fun open(durationMillis: Float = 330f) {
        onClosed = null
        openDurationMillis = durationMillis
        returning = false
        drive()
    }

    fun returnToSource(onClosed: () -> Unit) {
        this.onClosed = onClosed
        returning = true
        drive()
    }

    private fun drive() {
        if (job?.isActive == true) return
        job = scope.launch {
            val durationScale = coroutineContext[MotionDurationScale]
            var previousFrame: Long? = null
            while (isActive) {
                if (position == if (returning) 0f else 1f) {
                    if (!returning) break
                    snapshotFlow { !holdingGesture || !returning }.first { it }
                    if (returning) {
                        onClosed?.invoke()
                        break
                    }
                    previousFrame = null
                }
                withFrameNanos { frame ->
                    val previous = previousFrame ?: frame
                    val scale = durationScale?.scaleFactor ?: 1f
                    val duration = (if (returning) 200f else openDurationMillis) * 1_000_000f
                    val step = if (scale == 0f) 1f else (frame - previous) / (duration * scale)
                    position = (position + if (returning) -step else step).coerceIn(0f, 1f)
                    previousFrame = frame
                }
            }
        }
    }
}

internal fun Modifier.galleryOverlayInput(
    flightTarget: () -> Rect?,
    canSwipeFlight: () -> Boolean,
    onHoldFlight: (Boolean) -> Unit,
    onTapSource: () -> Unit,
    onSwipeFlight: (Float) -> Unit,
): Modifier = pointerInput(Unit) {
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        val target = flightTarget()?.takeIf { it.contains(down.position) && !down.isConsumed }
        var isTap = target != null
        var awaitingSwipe = !down.isConsumed && canSwipeFlight()
        var holding = isTap || awaitingSwipe
        if (!holding) return@awaitEachGesture
        down.consume()
        onHoldFlight(true)
        try {
            do {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val change = event.changes.firstOrNull { it.id == down.id }
                if (holding) {
                    if (change == null || change.isConsumed || event.changes.any { it.id != down.id && it.pressed }) {
                        isTap = false
                        awaitingSwipe = false
                    } else {
                        val delta = change.position - down.position
                        val slop = viewConfiguration.touchSlop
                        val dx = abs(delta.x)
                        val dy = abs(delta.y)
                        if (delta.getDistance() > slop || target?.contains(change.position) != true) isTap = false
                        if (awaitingSwipe) {
                            if (dx >= slop * 1.5f && dx > dy * 1.25f) {
                                awaitingSwipe = false
                                isTap = false
                                onSwipeFlight(delta.x)
                            } else if (!change.pressed || dy >= slop * 2f && dy > dx) {
                                awaitingSwipe = false
                            }
                        }
                    }
                    if (!isTap && !awaitingSwipe) {
                        holding = false
                        onHoldFlight(false)
                    }
                }
                event.changes.forEach { it.consume() }
                if (isTap && change?.changedToUpIgnoreConsumed() == true && flightTarget()?.contains(change.position) == true) onTapSource()
            } while (event.changes.any { it.pressed })
        } finally {
            if (holding) onHoldFlight(false)
        }
    }
}

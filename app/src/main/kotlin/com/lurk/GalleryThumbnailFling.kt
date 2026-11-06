package com.lurk

import androidx.compose.animation.core.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.pager.PagerState
import androidx.compose.runtime.*

@Composable
fun rememberGalleryThumbnailFling(pager: PagerState): TargetedFlingBehavior {
    val decay = ScrollableDefaults.flingBehavior()
    return remember(pager, decay) {
        object : TargetedFlingBehavior {
            override suspend fun ScrollScope.performFling(initialVelocity: Float, onRemainingDistanceUpdated: (Float) -> Unit): Float {
                val remainingVelocity = with(decay) { performFling(initialVelocity) }
                val distance = -pager.currentPageOffsetFraction * pager.layoutInfo.pageSize
                var consumed = 0f
                onRemainingDistanceUpdated(distance)
                AnimationState(0f).animateTo(distance, tween(120, easing = CubicBezierEasing(.215f, .61f, .355f, 1f))) {
                    consumed += scrollBy(value - consumed)
                    onRemainingDistanceUpdated(distance - consumed)
                }
                return remainingVelocity
            }
        }
    }
}

package com.lurk

import androidx.compose.foundation.clickable
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback

internal class AppHaptics(
    private val platform: HapticFeedback,
    private val enabled: () -> Boolean,
) : HapticFeedback {
    override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) {
        if (enabled()) platform.performHapticFeedback(hapticFeedbackType)
    }
}

@Composable
internal fun tapFeedback(action: () -> Unit): () -> Unit =
    tapFeedback(action, HapticFeedbackType.ContextClick)

@Composable
internal fun tapFeedback(action: () -> Unit, type: HapticFeedbackType): () -> Unit {
    val haptics = LocalHapticFeedback.current
    return {
        haptics.performHapticFeedback(type)
        action()
    }
}

@Composable
internal fun Modifier.feedbackClickable(
    enabled: Boolean = true,
    type: HapticFeedbackType = HapticFeedbackType.ContextClick,
    onClick: () -> Unit,
): Modifier = clickable(enabled = enabled, onClick = tapFeedback(onClick, type))

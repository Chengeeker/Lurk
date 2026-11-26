@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.lurk

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.CancellationSignal
import android.view.View
import android.view.Window
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreInterceptKeyBeforeSoftKeyboard
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.layout
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.graphics.Insets
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsAnimationControlListenerCompat
import androidx.core.view.WindowInsetsAnimationControllerCompat
import androidx.core.view.WindowInsetsCompat
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume
import kotlin.math.roundToInt

@Composable
@OptIn(ExperimentalLayoutApi::class)
fun ThreadCommentEditor(tid: String, initialText: String, onDraftChange: (String) -> Unit, close: () -> Unit, submit: (String) -> Unit) {
    val model = LocalState.current
    var text by rememberSaveable(tid, stateSaver = TextFieldValue.Saver) { mutableStateOf(TextFieldValue(initialText)) }
    LaunchedEffect(text.text) { onDraftChange(text.text) }
    var emoji by remember { mutableStateOf(false) }
    var emojiDockBottom by remember { mutableIntStateOf(0) }
    val reservedDock = remember { Animatable(0f) }
    val focus = remember { FocusRequester() }
    val colors = MaterialTheme.colorScheme
    val density = LocalDensity.current
    var closing by remember { mutableStateOf(false) }
    var allowSheetHide by remember { mutableStateOf(false) }
    var imeStart by remember { mutableIntStateOf(0) }
    var animatedIme by remember { mutableIntStateOf(0) }
    var visibleFraction by remember { mutableFloatStateOf(1f) }
    var sheetIme by remember { mutableStateOf<WindowInsets?>(null) }
    val opening = remember { Animatable(0f) }
    fun requestClose(): Boolean {
        if (closing || model.writing) return false
        closing = true
        return true
    }
    val dismiss: () -> Unit = { requestClose() }
    val latestDismiss by rememberUpdatedState(dismiss)
    val latestClose by rememberUpdatedState(close)
    val sheet = remember(density) {
        // Open at the editor anchor so only the keyboard drives the entrance motion.
        SheetState(skipPartiallyExpanded = true, initialValue = SheetValue.Expanded,
            positionalThreshold = { with(density) { 56.dp.toPx() } }, velocityThreshold = { with(density) { 125.dp.toPx() } },
            confirmValueChange = { target ->
                if (target != SheetValue.Hidden || allowSheetHide) true
                else { latestDismiss(); false }
            })
    }
    val canDismiss = !closing && !model.writing
    val scrim = BottomSheetDefaults.ScrimColor
    ModalBottomSheet(onDismissRequest = dismiss, dragHandle = null, sheetState = sheet,
        modifier = Modifier.graphicsLayer {
            // The sheet's anchored offset places it outside this layer's offscreen bounds.
            compositingStrategy = CompositingStrategy.ModulateAlpha
            alpha = opening.value * visibleFraction
            if (imeStart > 0) {
                val dock = reservedDock.value
                translationY = maxOf((sheetIme?.getBottom(density) ?: 0).toFloat(), dock) -
                    maxOf(animatedIme.toFloat(), dock * visibleFraction)
            }
        },
        shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp), containerColor = colors.surface,
        scrimColor = scrim.copy(alpha = scrim.alpha * opening.value * visibleFraction), sheetGesturesEnabled = canDismiss,
        properties = ModalBottomSheetProperties(shouldDismissOnBackPress = canDismiss, shouldDismissOnClickOutside = canDismiss)) {
        val focusManager = LocalFocusManager.current
        val keyboard = LocalSoftwareKeyboardController.current
        val ime = WindowInsets.ime
        val imeTarget = WindowInsets.imeAnimationTarget
        val navigationBars = WindowInsets.navigationBars
        val view = LocalView.current
        val windowInfo = LocalWindowInfo.current
        val closePulse = tapFeedback({})
        val window = (view.parent as? DialogWindowProvider)?.window
        SideEffect { sheetIme = ime }
        if (Build.VERSION.SDK_INT >= 33) DisposableEffect(window) {
            val dispatcher = window?.onBackInvokedDispatcher
            val callback = OnBackInvokedCallback { latestDismiss() }
            dispatcher?.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_OVERLAY, callback)
            onDispose { dispatcher?.unregisterOnBackInvokedCallback(callback) }
        }
        LaunchedEffect(emoji, closing) {
            if (closing) return@LaunchedEffect
            if (emoji) {
                val alreadyLifted = ime.getBottom(density) > navigationBars.getBottom(density) || reservedDock.value > 0f
                if (alreadyLifted) reservedDock.snapTo(emojiDockBottom.toFloat())
                focusManager.clearFocus()
                keyboard?.hide()
                if (!alreadyLifted) reservedDock.animateTo(emojiDockBottom.toFloat(), tween(180))
            } else if (emojiDockBottom > 0) {
                withTimeoutOrNull(750L) {
                    snapshotFlow {
                        val target = imeTarget.getBottom(density)
                        target > navigationBars.getBottom(density) && ime.getBottom(density) >= target
                    }.first { it }
                }
                reservedDock.animateTo(0f, tween(180))
                emojiDockBottom = 0
            }
        }
        LaunchedEffect(closing) {
            if (!closing) {
                launch { opening.animateTo(1f, tween(160)) }
                snapshotFlow { windowInfo.isWindowFocused }.first { it }
                focus.requestFocus()
                return@LaunchedEffect
            }
            imeStart = ime.getBottom(density)
            animatedIme = imeStart
            if (imeStart == 0) {
                keyboard?.hide()
                allowSheetHide = true
                sheet.hide()
            } else {
                val controller = if (Build.VERSION.SDK_INT >= 30 && window != null) {
                    requestCommentImeControl(window, view)
                } else null
                val shown = controller?.currentInsets ?: Insets.of(0, 0, 0, imeStart)
                val hidden = controller?.hiddenStateInsets ?: Insets.NONE
                if (controller == null) keyboard?.hide()
                try {
                    Animatable(0f).animateTo(1f, tween(CommentImeDismissMillis)) {
                        visibleFraction = 1f - value
                        animatedIme = (shown.bottom + (hidden.bottom - shown.bottom) * value).roundToInt()
                        if (controller?.isReady == true) {
                            controller.setInsetsAndAlpha(
                                Insets.of(shown.left, shown.top, shown.right, animatedIme), 1f, value,
                            )
                        }
                    }
                } finally {
                    if (controller?.isReady == true) controller.finish(false)
                }
                if (controller?.isCancelled == true) keyboard?.hide()
            }
            latestClose()
        }
        Column(Modifier.fillMaxWidth().onPreInterceptKeyBeforeSoftKeyboard { event ->
            if (event.key != Key.Back) false else {
                if (event.type == KeyEventType.KeyUp && !event.nativeKeyEvent.isCanceled) requestClose()
                true
            }
        }) {
            Row(Modifier.padding(start = 16.dp, top = 12.dp, end = 16.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("发表评论", Modifier.weight(1f), fontSize = 16.sp, fontWeight = FontWeight.Bold)
                IconButton(onClick = { if (requestClose()) closePulse() }, enabled = canDismiss) { Icon(Icons.Outlined.Close, "关闭", Modifier.size(20.dp)) }
            }
            OriginalDivider()
            BasicTextField(text, { if (it.text.length <= 10000 && (!emoji || it.text != text.text)) text = it },
                Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth()
                    .background(colors.surfaceContainerHighest.copy(alpha = .3f), RoundedCornerShape(12.dp)).padding(12.dp)
                    .focusRequester(focus).onFocusChanged { if (it.isFocused) emoji = false }, minLines = 2, maxLines = 4,
                textStyle = MaterialTheme.typography.bodyMedium.copy(fontSize = 15.sp, color = colors.onSurface), cursorBrush = SolidColor(colors.primary),
                decorationBox = { input -> Box { if (text.text.isEmpty()) Text("写下你的友善评论...", fontSize = 15.sp, color = colors.onSurfaceVariant.copy(alpha = .7f)); input() } })
            Row(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(enabled = !closing, onClick = tapFeedback {
                    if (emoji) {
                        emoji = false
                        focus.requestFocus()
                        keyboard?.show()
                    } else {
                        val navigationBottom = navigationBars.getBottom(density)
                        emojiDockBottom = maxOf(ime.getBottom(density), reservedDock.value.roundToInt())
                            .takeIf { it > navigationBottom } ?: with(density) { 240.dp.roundToPx() } + navigationBottom
                        emoji = true
                    }
                }) {
                    Icon(if (emoji) Icons.Outlined.Keyboard else Icons.Outlined.SentimentSatisfiedAlt, if (emoji) "切换键盘" else "插入表情", tint = if (emoji) colors.primary else colors.onSurfaceVariant)
                }
                Spacer(Modifier.weight(1f))
                Button(onClick = tapFeedback {
                    val submitted = text.text.trim()
                    if (submitted.isEmpty()) model.message("请输入评论内容") else submit(submitted)
                }, enabled = !model.writing && !closing, shape = RoundedCornerShape(20.dp), contentPadding = PaddingValues(horizontal = 20.dp, vertical = 10.dp)) {
                    if (model.writing) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp) else Text("发送", fontWeight = FontWeight.Bold)
                }
            }

            if (emojiDockBottom > 0) {
                val panelHeight = with(density) { (emojiDockBottom - navigationBars.getBottom(this)).coerceAtLeast(0).toDp() }
                Box(Modifier.fillMaxWidth().clipToBounds().layout { measurable, constraints ->
                    // Material already reserves the live IME inset. The panel fills only the uncovered space.
                    val occupied = maxOf(ime.getBottom(this), navigationBars.getBottom(this))
                    val height = (reservedDock.value.roundToInt() - occupied).coerceIn(0, constraints.maxHeight)
                    val panel = measurable.measure(constraints.copy(minHeight = height, maxHeight = height))
                    layout(panel.width, height) { panel.placeRelative(0, 0) }
                }) {
                    EmojiPanel(backspace = { text = text.erasePhrase() }, modifier = Modifier
                        .wrapContentHeight(Alignment.Top, unbounded = true).height(panelHeight)) { phrase ->
                        val inserted = text.insertPhrase(phrase)
                        if (inserted.text.length <= 10000) text = inserted
                    }
                }
            }
        }
    }
}

private const val CommentImeDismissMillis = 250

private suspend fun requestCommentImeControl(window: Window, view: View): WindowInsetsAnimationControllerCompat? =
    withTimeoutOrNull(180L) {
        suspendCancellableCoroutine { continuation ->
            val cancellation = CancellationSignal()
            continuation.invokeOnCancellation { cancellation.cancel() }
            WindowCompat.getInsetsController(window, view).controlWindowInsetsAnimation(
                WindowInsetsCompat.Type.ime(), CommentImeDismissMillis.toLong(), null, cancellation,
                object : WindowInsetsAnimationControlListenerCompat {
                    override fun onReady(controller: WindowInsetsAnimationControllerCompat, types: Int) {
                        if (continuation.isActive) continuation.resume(controller)
                        else if (controller.isReady) controller.finish(false)
                    }

                    override fun onFinished(controller: WindowInsetsAnimationControllerCompat) = Unit

                    override fun onCancelled(controller: WindowInsetsAnimationControllerCompat?) {
                        if (continuation.isActive) continuation.resume(null)
                    }
                },
            )
        }
    }

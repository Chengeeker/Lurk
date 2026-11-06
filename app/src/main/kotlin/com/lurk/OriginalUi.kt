package com.lurk

import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.graphics.graphicsLayer
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collectLatest
import kotlin.math.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import androidx.compose.ui.text.TextStyle

internal object NoPressIndication : IndicationNodeFactory {
    override fun create(interactionSource: androidx.compose.foundation.interaction.InteractionSource): androidx.compose.ui.node.DelegatableNode =
        object : Modifier.Node(), androidx.compose.ui.node.DrawModifierNode {
            override fun androidx.compose.ui.graphics.drawscope.ContentDrawScope.draw() = drawContent()
        }

    override fun equals(other: Any?) = other === this
    override fun hashCode() = System.identityHashCode(this)
}

@Composable
fun SectionCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLow) {
        Column(Modifier.fillMaxWidth(), content = content)
    }
}

@Composable
fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Text(title, Modifier.padding(start = 16.dp, end = 16.dp, bottom = 12.dp), color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.titleSmall)
    SectionCard(content)
    Spacer(Modifier.height(32.dp))
}

@Composable
fun SettingsRow(title: String, icon: ImageVector, detail: String = "", detailSize: androidx.compose.ui.unit.TextUnit = 13.sp, onClick: () -> Unit) {
    ListItem(headlineContent = { Text(title, style = MaterialTheme.typography.titleMedium.copy(fontSize = 16.sp)) },
        supportingContent = if (detail.isEmpty()) null else { { Text(detail, fontSize = detailSize) } },
        leadingContent = { Icon(icon, null, tint = MaterialTheme.colorScheme.onSurfaceVariant) },
        trailingContent = { Icon(Icons.Rounded.ChevronRight, null) },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent), modifier = Modifier.feedbackClickable(onClick = onClick).padding(end = 8.dp))
}

fun originalTypography(weightIndex: Int): Typography {
    val defaults = Typography()
    // Flutter stores typography heights as a multiple of the effective font size.
    fun TextStyle.relativeHeight() = copy(lineHeight = (lineHeight.value / fontSize.value).em)
    val base = defaults.copy(
        displayLarge = defaults.displayLarge.relativeHeight(), displayMedium = defaults.displayMedium.relativeHeight(), displaySmall = defaults.displaySmall.relativeHeight(),
        headlineLarge = defaults.headlineLarge.relativeHeight(), headlineMedium = defaults.headlineMedium.relativeHeight(), headlineSmall = defaults.headlineSmall.relativeHeight(),
        titleLarge = defaults.titleLarge.relativeHeight(), titleMedium = defaults.titleMedium.relativeHeight(), titleSmall = defaults.titleSmall.relativeHeight(),
        bodyLarge = defaults.bodyLarge.relativeHeight(), bodyMedium = defaults.bodyMedium.relativeHeight(), bodySmall = defaults.bodySmall.relativeHeight(),
        labelLarge = defaults.labelLarge.relativeHeight(), labelMedium = defaults.labelMedium.relativeHeight(), labelSmall = defaults.labelSmall.relativeHeight())
    if (weightIndex == 1) return base
    val normal = FontWeight(300 + weightIndex.coerceIn(0, 4) * 100)
    val bold = FontWeight(500 + weightIndex.coerceIn(0, 4) * 100)
    return base.copy(bodyLarge = base.bodyLarge.copy(fontWeight = normal), bodyMedium = base.bodyMedium.copy(fontWeight = normal), bodySmall = base.bodySmall.copy(fontWeight = normal),
        titleLarge = base.titleLarge.copy(fontWeight = bold), titleMedium = base.titleMedium.copy(fontWeight = bold), titleSmall = base.titleSmall.copy(fontWeight = bold),
        labelLarge = base.labelLarge.copy(fontWeight = normal), labelMedium = base.labelMedium.copy(fontWeight = normal), labelSmall = base.labelSmall.copy(fontWeight = normal),
        headlineMedium = base.headlineMedium.copy(fontWeight = bold), headlineSmall = base.headlineSmall.copy(fontWeight = bold))
}

@Composable
fun OriginalNavigation(selected: Int, dark: Boolean, onSelected: (Int) -> Unit) {
    val model = LocalState.current
    val floating = model.store.bool("key_use_floating_nav_bar", true)
    val glass = floating && model.store.bool("key_use_liquid_glass_effect")
    OriginalNavigationBar(selected, dark, floating, glass, onSelected)
}

@Composable
internal fun OriginalNavigationBar(selected: Int, dark: Boolean, floating: Boolean, glass: Boolean, onSelected: (Int) -> Unit) {
    val colors = MaterialTheme.colorScheme
    val icons = listOf(Icons.Outlined.Forum, Icons.Outlined.DynamicFeed, Icons.Outlined.Notifications, Icons.Rounded.PersonOutline)
    val selectedIcons = listOf(Icons.Rounded.Forum, Icons.Rounded.DynamicFeed, Icons.Rounded.Notifications, Icons.Rounded.Person)
    val labels = listOf("进吧", "动态", "消息", "我的")
    val haptics = LocalHapticFeedback.current
    if (!floating) {
        NavigationBar(containerColor = colors.background, tonalElevation = 0.dp, modifier = Modifier.navigationBarsPadding().height(80.dp), windowInsets = WindowInsets(0, 0, 0, 0)) {
            labels.forEachIndexed { index, title -> NavigationBarItem(index == selected, tapFeedback { onSelected(index) },
                icon = { Icon(if (index == selected) selectedIcons[index] else icons[index], title) }, label = { Text(title) },
                colors = NavigationBarItemDefaults.colors(selectedIconColor = colors.onPrimaryContainer, unselectedIconColor = colors.onSurfaceVariant, selectedTextColor = colors.onSurface, unselectedTextColor = colors.onSurfaceVariant, indicatorColor = if (dark) colors.secondaryContainer else colors.primaryContainer)) }
        }
        return
    }

    val width = (minOf(440f, LocalConfiguration.current.screenWidthDp - 40f) * 8 / 9).dp
    var longPressed by remember { mutableStateOf(false) }
    var dragging by remember { mutableStateOf(false) }; var finger by remember { mutableFloatStateOf(selected.toFloat()) }
    var settleFrom by remember { mutableStateOf<Float?>(null) }
    var dragVelocity by remember { mutableFloatStateOf(0f) }
    val callback by rememberUpdatedState(onSelected); val activeIndex by rememberUpdatedState(selected)
    val scope = rememberCoroutineScope()
    val position = remember { Animatable(selected.toFloat()) }
    val pressure = navigationGlassPressure(longPressed && glass)
    fun lensPosition() = if (dragging) finger else settleFrom ?: position.value
    LaunchedEffect(pressure) {
        snapshotFlow { pressure.value > .001f }.collectLatest { hasWater ->
            dragVelocity = 0f
            if (!hasWater) return@collectLatest
            var previousTime = withFrameNanos { it }
            var previous = lensPosition()
            while (isActive) {
                withFrameNanos { time ->
                    val next = lensPosition()
                    dragVelocity = (next - previous) * 1_000_000_000f / (time - previousTime).coerceAtLeast(1L)
                    previous = next
                    previousTime = time
                }
            }
        }
    }
    LaunchedEffect(dragging, selected) {
        if (!dragging) {
            settleFrom?.let {
                position.snapTo(it)
                settleFrom = null
            }
            position.animateTo(selected.toFloat(), if (glass) spring(stiffness = 322.27f, dampingRatio = .85f)
                else tween(240, easing = CubicBezierEasing(.215f, .61f, .355f, 1f)))
        }
    }
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    val bottomInset = WindowInsets.navigationBars.getBottom(LocalDensity.current) > 0
    val gesture = if (!glass) Modifier else Modifier.pointerInput(haptics, rtl) {
        fun tabPosition(x: Float): Float {
            val physical = if (rtl) size.width - x else x
            return navigationTabPosition(physical, size.width.toFloat(), NAVIGATION_LABEL_INSET_DP * density)
        }
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
            down.consume()
            longPressed = false
            val startIndex = activeIndex; var moved = false; var vertical = false; var released = false
            var held = false
            val tracker = VelocityTracker(); tracker.addPosition(down.uptimeMillis, down.position)
            val timer = scope.launch {
                delay(220)
                held = true
                longPressed = true
                finger = tabPosition(down.position.x)
                dragging = true
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            }
            var target = tabPosition(down.position.x).roundToInt()
            try {
                do {
                    val event = awaitPointerEvent(PointerEventPass.Initial); val change = event.changes.firstOrNull { it.id == down.id } ?: break
                    tracker.addPosition(change.uptimeMillis, change.position)
                    val delta = change.position - down.position
                    if (!moved && delta.getDistance() > viewConfiguration.touchSlop) {
                        moved = true; timer.cancel()
                        vertical = !dragging && abs(delta.y) >= abs(delta.x)
                        if (!vertical) dragging = true
                    }
                    if (dragging && !vertical) finger = tabPosition(change.position.x)
                    target = tabPosition(change.position.x).roundToInt()
                    if (!change.pressed) {
                        released = !change.isConsumed
                        change.consume()
                        break
                    }
                    change.consume()
                } while (event.changes.any { it.pressed })
            } finally {
                timer.cancel()
                longPressed = false
                val wasDragging = dragging
                if (wasDragging) settleFrom = finger
                dragging = false
                if (released && !vertical) {
                    val velocity = tracker.calculateVelocity().x / density
                    val result = if (!held && moved && abs(velocity) >= 1000f) target.coerceIn((startIndex - 1).coerceAtLeast(0), (startIndex + 1).coerceAtMost(3)) else target
                    if (!(wasDragging || moved) || result != startIndex) {
                        if (!held) haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
                        callback(result)
                    }
                }
            }
        }
    }
    Box(Modifier.fillMaxWidth().padding(bottom = if (glass) { if (bottomInset) 6.dp else 14.dp } else { if (bottomInset) 8.dp else 16.dp }), contentAlignment = Alignment.Center) {
        Box(Modifier.width(width).height(56.dp).then(gesture)) {
            if (glass) {
                LiquidNavigationContent(
                    position = {
                        val current = lensPosition()
                        if (rtl) 3f - current else current
                    },
                    velocity = { dragVelocity },
                    expansion = { pressure.value.coerceIn(0f, 1f) }, dark = dark,
                    labels = labels, icons = icons, selectedIcons = selectedIcons, select = callback,
                )
                return@Box
            }
            Box(Modifier.matchParentSize().shadow(8.dp, RoundedCornerShape(32.dp)).clip(RoundedCornerShape(32.dp))
                .background(if (dark) Color(0xFF222328) else colors.surfaceContainerHigh))
            Box(Modifier.offset { IntOffset((width.toPx() / 4f * position.value).roundToInt(), 0) }.width(width / 4).height(56.dp)
                .clip(RoundedCornerShape(40.dp)).background(if (dark) colors.secondaryContainer else colors.primaryContainer))
            Row {
                labels.forEachIndexed { index, label ->
                    val active = selected == index
                    val foreground = if (active) { if (dark) colors.onSecondaryContainer else colors.onPrimaryContainer } else colors.onSurfaceVariant
                    Column(Modifier.weight(1f).height(56.dp).clip(RoundedCornerShape(28.dp)).feedbackClickable { callback(index) }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                        Icon(if (active) selectedIcons[index] else icons[index], label, Modifier.size(22.dp), tint = foreground)
                        Spacer(Modifier.height(2.dp)); Text(label, fontSize = 11.sp, fontWeight = if (active) FontWeight.Bold else FontWeight.Medium, color = foreground)
                    }
                }
            }
        }
    }
}



@Composable
fun OriginalConfirmation(title: String, message: String, confirmLabel: String, dismiss: () -> Unit, confirm: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    AlertDialog(onDismissRequest = dismiss, shape = RoundedCornerShape(24.dp), title = { Text(title, fontSize = 18.sp, fontWeight = FontWeight.Bold) }, text = { Text(message, fontSize = 14.sp) },
        confirmButton = { Button(onClick = tapFeedback(confirm), enabled = !LocalState.current.writing, shape = RoundedCornerShape(12.dp), colors = ButtonDefaults.buttonColors(containerColor = colors.error, contentColor = colors.onError)) { Text(confirmLabel) } },
        dismissButton = { TextButton(onClick = tapFeedback(dismiss)) { Text("取消", color = colors.outline) } })
}

// Apply the app preference after Android's accessibility curve, as Flutter does.
internal class PreferenceDensity(private val system: androidx.compose.ui.unit.Density, private val preference: Float) : androidx.compose.ui.unit.Density {
    override val density get() = system.density
    override val fontScale get() = system.fontScale * preference
    override fun androidx.compose.ui.unit.TextUnit.toDp(): androidx.compose.ui.unit.Dp = with(system) { this@toDp.toDp() } * preference
    override fun androidx.compose.ui.unit.Dp.toSp(): androidx.compose.ui.unit.TextUnit = with(system) { (this@toSp / preference).toSp() }
}

val LocalDividerColor = staticCompositionLocalOf { Color.Unspecified }
@Composable
fun OriginalDivider(modifier: Modifier = Modifier, thickness: androidx.compose.ui.unit.Dp = .5.dp, color: Color = LocalDividerColor.current) {
    HorizontalDivider(modifier, thickness, if (color == Color.Unspecified) MaterialTheme.colorScheme.outlineVariant.copy(alpha = .3f) else color)
}

val LocalOriginalCardColor = staticCompositionLocalOf { Color.Unspecified }

@Composable
internal fun OriginalListCard(modifier: Modifier, content: @Composable ColumnScope.() -> Unit) {
    val color = LocalOriginalCardColor.current.takeUnless { it == Color.Unspecified }
        ?: MaterialTheme.colorScheme.surfaceContainerLow
    Card(modifier, shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = color), content = content)
}

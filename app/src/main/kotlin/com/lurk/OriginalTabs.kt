package com.lurk

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier

val LocalPageActive = staticCompositionLocalOf { true }

@Composable
fun OriginalTabs(selected: Int, count: Int, onSelected: (Int) -> Unit, content: @Composable (Int) -> Unit) {
    val pager = rememberPagerState(initialPage = selected) { count }
    val callback by rememberUpdatedState(onSelected)
    LaunchedEffect(selected) { if (pager.currentPage != selected) pager.animateScrollToPage(selected, animationSpec = tween(300, easing = CubicBezierEasing(.25f, .1f, .25f, 1f))) }
    LaunchedEffect(pager) { snapshotFlow { pager.settledPage }.collect { callback(it) } }
    HorizontalPager(pager, Modifier.fillMaxSize()) { page ->
        CompositionLocalProvider(LocalPageActive provides (page == selected)) { content(page) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OriginalTabBar(selected: Int, labels: List<String>, onSelect: (Int) -> Unit,
                   selectedStyle: TextStyle = MaterialTheme.typography.titleSmall, unselectedStyle: TextStyle = selectedStyle) {
    val colors = MaterialTheme.colorScheme
    val textWidth = with(LocalDensity.current) { rememberTextMeasurer().measure(labels[selected], selectedStyle).size.width.toDp() }.coerceAtLeast(24.dp)
    TabRow(selected, containerColor = Color.Transparent, contentColor = colors.primary,
        indicator = { tabs -> Box(Modifier.tabIndicatorOffset(tabs[selected]).wrapContentWidth(Alignment.CenterHorizontally).width(textWidth).height(3.dp).background(colors.primary, RoundedCornerShape(topStart = 3.dp, topEnd = 3.dp))) }) {
        labels.forEachIndexed { index, label -> Tab(index == selected, tapFeedback { onSelect(index) }, selectedContentColor = colors.primary, unselectedContentColor = colors.onSurfaceVariant,
            text = { Text(label, style = if (index == selected) selectedStyle else unselectedStyle) }) }
    }
}

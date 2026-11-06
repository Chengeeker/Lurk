package com.lurk

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class ClassicPhase { Pull, Armed, Loading, Success, Failed, NoMore }

@Composable
fun OriginalRefreshIndicator(phase: ClassicPhase, updated: Long, footer: Boolean = false) {
    val color = MaterialTheme.colorScheme.onSurface
    val rotation by animateFloatAsState(if (phase == ClassicPhase.Armed) -180f else 0f, tween(200), label = "refresh arrow")
    val time = remember(updated) { SimpleDateFormat("H:mm", Locale.ROOT).format(Date(updated)) }
    val label = when (phase) {
        ClassicPhase.Pull -> if (footer) "上拉加载" else "下拉刷新"
        ClassicPhase.Armed -> if (footer) "释放加载更多" else "释放即可刷新"
        ClassicPhase.Loading -> if (footer) "正在加载..." else "正在刷新..."
        ClassicPhase.Success -> if (footer) "加载完成" else "刷新成功"
        ClassicPhase.Failed -> if (footer) "加载失败" else "刷新失败"
        ClassicPhase.NoMore -> if (footer) "没有更多内容了" else "没有更多了"
    }
    Row(Modifier.fillMaxWidth().height(70.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) {
            AnimatedContent(if (phase == ClassicPhase.Armed) ClassicPhase.Pull else phase,
                transitionSpec = { (fadeIn(tween(300)) + scaleIn(tween(300))) togetherWith (fadeOut(tween(200)) + scaleOut(tween(200))) }, label = "refresh status") { iconPhase ->
                if (iconPhase == ClassicPhase.Loading) CircularProgressIndicator(Modifier.size(20.dp), color = color, strokeWidth = 2.dp)
                else Icon(when (iconPhase) { ClassicPhase.Success -> Icons.Filled.Done; ClassicPhase.Failed -> Icons.Outlined.ErrorOutline; ClassicPhase.NoMore -> Icons.Outlined.Inbox; else -> if (footer) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward }, null,
                    Modifier.size(24.dp).graphicsLayer { rotationZ = if (iconPhase == ClassicPhase.Pull) rotation else 0f }, tint = color)
            }
        }
        Spacer(Modifier.width(16.dp))
        Column { Text(label, style = MaterialTheme.typography.titleMedium); Spacer(Modifier.height(4.dp)); Text("最后更新于 $time", style = MaterialTheme.typography.bodySmall) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OriginalRefreshBox(isRefreshing: Boolean, onRefresh: () -> Unit, modifier: Modifier = Modifier, failed: Boolean = false, content: @Composable BoxScope.() -> Unit) {
    val state = rememberPullToRefreshState()
    var finishing by remember { mutableStateOf(false) }
    var updated by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(isRefreshing) {
        if (isRefreshing) finishing = true
        else if (finishing) { updated = System.currentTimeMillis(); delay(1000); finishing = false }
    }
    // shortcut: Compose owns drag resistance/rebound; exact EasyRefresh physics requires device gesture comparison.
    Box(modifier.clipToBounds().pullToRefresh(isRefreshing || finishing, state, threshold = 70.dp, onRefresh = tapFeedback(onRefresh))) {
        Box(Modifier.fillMaxSize().graphicsLayer { translationY = state.distanceFraction * 70.dp.toPx() }, content = content)
        if (state.distanceFraction > 0f) Box(Modifier.fillMaxWidth().padding(top = LocalContentTop.current).height((state.distanceFraction * 70f).dp).clipToBounds(), contentAlignment = Alignment.Center) {
            Box(Modifier.requiredHeight(70.dp)) {
                OriginalRefreshIndicator(when { isRefreshing -> ClassicPhase.Loading; finishing -> if (failed) ClassicPhase.Failed else ClassicPhase.Success; state.distanceFraction >= 1 -> ClassicPhase.Armed; else -> ClassicPhase.Pull }, updated)
            }
        }
    }
}

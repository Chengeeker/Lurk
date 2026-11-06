@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@file:androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
package com.lurk

import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import android.app.Activity
import android.content.pm.ActivityInfo
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.material.icons.rounded.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.*
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlin.math.abs

fun playbackTime(milliseconds: Long): String { val seconds = milliseconds.coerceAtLeast(0) / 1000; return "%02d:%02d".format(java.util.Locale.ROOT, seconds / 60, seconds % 60) }

internal fun Modifier.videoTapInput(key: Any, onTap: () -> Unit, onDoubleTap: (Float) -> Unit): Modifier = pointerInput(key) {
    var previousTap: PointerInputChange? = null
    awaitEachGesture {
        val down = awaitFirstDown()
        down.consume()
        val up = waitForUpOrCancellation()
        if (up == null || (up.position - down.position).getDistance() > viewConfiguration.touchSlop) {
            previousTap = null
            return@awaitEachGesture
        }
        up.consume()
        val previous = previousTap
        val doubleTap = previous != null &&
            down.uptimeMillis - previous.uptimeMillis in viewConfiguration.doubleTapMinTimeMillis..viewConfiguration.doubleTapTimeoutMillis &&
            (down.position - previous.position).getDistance() <= viewConfiguration.touchSlop * 4f
        if (doubleTap) {
            previousTap = null
            onDoubleTap(up.position.x / size.width.coerceAtLeast(1))
        } else {
            previousTap = up
            onTap()
        }
    }
}

@Composable
fun VideoPlayer(media: Media, allowSoleDetailVideo: Boolean, onControls: (Boolean) -> Unit, onFullscreen: (Boolean) -> Unit, onUrl: (String) -> Unit, onBottomHeight: (Int) -> Unit) {
    val context = LocalContext.current; val model = LocalState.current; val activity = androidx.activity.compose.LocalActivity.current
    val view = LocalView.current; val window = (view.parent as? DialogWindowProvider)?.window ?: activity?.window
    val lifecycle = LocalLifecycleOwner.current.lifecycle; val scope = rememberCoroutineScope()
    val player = remember { ExoPlayer.Builder(context).setMediaSourceFactory(DefaultMediaSourceFactory(DefaultHttpDataSource.Factory().setUserAgent("bdtb for Android 12.41.7.1").setDefaultRequestProperties(mapOf("Referer" to "https://tieba.baidu.com/")).setAllowCrossProtocolRedirects(true))).build().apply { volume = .5f } }
    var effective by remember { mutableStateOf(media.video) }
    var retry by remember { mutableIntStateOf(0) }
    val playbackErrors = remember(player) { Channel<Long>(Channel.CONFLATED) }
    var speed by remember { mutableFloatStateOf(1f) }; var fast by remember { mutableStateOf(false) }; var speedSheet by remember { mutableStateOf(false) }
    var controls by remember { mutableStateOf(true) }; var playing by remember { mutableStateOf(false) }; var fullscreen by remember { mutableStateOf(false) }
    var ready by remember { mutableStateOf(false) }; var buffering by remember { mutableStateOf(true) }; var failure by remember { mutableStateOf(false) }
    var position by remember { mutableLongStateOf(0) }; var duration by remember { mutableLongStateOf(0) }; var interaction by remember { mutableIntStateOf(0) }
    var scrubPosition by remember { mutableStateOf<Float?>(null) }
    var hud by remember { mutableStateOf("") }; var hudType by remember { mutableStateOf("seek") }; var hudEpoch by remember { mutableIntStateOf(0) }
    var brightness by remember { mutableFloatStateOf(runCatching { Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS) / 255f }.getOrDefault(.5f)) }
    var volume by remember { mutableFloatStateOf(.5f) }
    fun toggleOrientation() { fullscreen = !fullscreen; activity?.requestedOrientation = if (fullscreen) ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE else ActivityInfo.SCREEN_ORIENTATION_PORTRAIT; interaction++ }
    fun playPause() { if (player.playWhenReady) { player.pause(); controls = true } else player.play(); interaction++ }
    fun load(url: String, at: Long = 0) { effective = url; onUrl(url); failure = false; ready = false; buffering = true; scrubPosition = null; player.setMediaItem(MediaItem.fromUri(url), at); player.prepare(); player.playWhenReady = true }
    LaunchedEffect(media, retry) {
        playbackErrors.tryReceive()
        failure = false
        ready = false
        buffering = true
        try {
            val direct = videoStreamUrl(media.video)
            val resumeAt = if (direct.isNotEmpty()) {
                load(direct)
                playbackErrors.receive()
            } else 0L
            require(media.threadId.isNotEmpty())
            buffering = true
            val replacement = detailVideoUrl(model.api.detail(media.threadId), media, direct, allowSoleDetailVideo)
            require(replacement.isNotEmpty())
            load(replacement, resumeAt)
            playbackErrors.receive()
            failure = true
            buffering = false
        } catch (e: CancellationException) { throw e }
        catch (_: Exception) { failure = true; buffering = false }
    }
    DisposableEffect(player, lifecycle) {
        val previousOrientation = activity?.requestedOrientation; val previousBrightness = window?.attributes?.screenBrightness
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_STOP) player.pause() }
        val listener = object : Player.Listener {
            override fun onIsPlayingChanged(value: Boolean) { playing = value; if (!value) controls = true }
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY || state == Player.STATE_ENDED) ready = true
                buffering = state == Player.STATE_BUFFERING
            }
            override fun onPlayerError(error: PlaybackException) {
                playbackErrors.trySend(player.currentPosition)
            }
        }
        lifecycle.addObserver(observer); player.addListener(listener); view.keepScreenOn = true
        onDispose {
            lifecycle.removeObserver(observer); player.removeListener(listener); player.release(); view.keepScreenOn = false
            if (previousOrientation != null) activity?.requestedOrientation = previousOrientation
            if (previousBrightness != null) window?.let { it.attributes = it.attributes.apply { screenBrightness = previousBrightness } }
            window?.let { WindowCompat.getInsetsController(it, view).show(WindowInsetsCompat.Type.systemBars()) }
        }
    }
    LaunchedEffect(fullscreen) { onFullscreen(fullscreen); window?.let { win -> WindowCompat.getInsetsController(win, view).apply { systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE; if (fullscreen) hide(WindowInsetsCompat.Type.systemBars()) else show(WindowInsetsCompat.Type.systemBars()) } } }
    LaunchedEffect(controls) { onControls(controls) }
    val scrubbing = scrubPosition != null
    LaunchedEffect(playing, controls, interaction, speedSheet, scrubbing) { if (playing && controls && !speedSheet && !scrubbing) { delay(4000); controls = false } }
    LaunchedEffect(hudEpoch) { if (hud.isNotEmpty()) { delay(900); hud = "" } }
    LaunchedEffect(player) { while (true) { position = player.currentPosition; duration = player.duration.coerceAtLeast(0); delay(250) } }
    val haptics = LocalHapticFeedback.current
    var controlsBeforeTap by remember { mutableStateOf(true) }
    BackHandler(fullscreen) { toggleOrientation() }
    val save = rememberMediaSaver()
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        AndroidView(modifier = Modifier.fillMaxSize(), factory = { (android.view.LayoutInflater.from(it).inflate(R.layout.video_surface, android.widget.FrameLayout(it), false) as PlayerView).apply { this.player = player; useController = false; setShowBuffering(PlayerView.SHOW_BUFFERING_NEVER) } })
        if (ready) Box(Modifier.fillMaxSize().videoTapInput(player, onTap = {
            controlsBeforeTap = controls
            haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
            controls = !controls
            interaction++
        }, onDoubleTap = { horizontalPosition ->
            controls = controlsBeforeTap
            interaction++
            if (horizontalPosition < .35f || horizontalPosition > .65f) {
                val delta = if (horizontalPosition < .35f) -10 else 10
                val target = (player.currentPosition + delta * 1000L).coerceIn(0, player.duration.coerceAtLeast(0)); player.seekTo(target)
                hudType = "seek"; hud = "${if (delta > 0) "+" else ""}$delta 秒  ${playbackTime(target)}"; hudEpoch++
            } else playPause()
        }).pointerInput(player) {
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false); val start = down.position
                val initialBrightness = brightness; val initialVolume = volume
                var dragging = false; var job: Job? = null
                if (start.x < size.width * .45f || start.x > size.width * .55f) job = scope.launch { delay(250); fast = true; player.setPlaybackSpeed(2f); haptics.performHapticFeedback(HapticFeedbackType.LongPress) }
                try {
                    do {
                        val event = awaitPointerEvent(); val change = event.changes.firstOrNull { it.id == down.id } ?: break
                        if (event.changes.count { it.pressed } > 1 || change.isConsumed) break
                        val diff = change.position - start
                        if (diff.getDistance() > viewConfiguration.touchSlop) job?.cancel()
                        if (!dragging && abs(diff.y) > viewConfiguration.touchSlop && abs(diff.y) > abs(diff.x)) { dragging = true; job?.cancel(); fast = false; player.setPlaybackSpeed(speed) }
                        if (dragging) {
                            change.consume(); val delta = -diff.y / (size.height * .65f)
                            if (start.x < size.width / 2) { brightness = (initialBrightness + delta).coerceIn(.01f, 1f); window?.let { it.attributes = it.attributes.apply { screenBrightness = brightness } }; hudType = "brightness"; hud = "亮度 ${(brightness * 100).toInt()}%" }
                            else { volume = (initialVolume + delta).coerceIn(0f, 1f); player.volume = volume; hudType = "volume"; hud = "音量 ${(volume * 100).toInt()}%" }
                            hudEpoch++
                        } else if (fast) change.consume()
                    } while (event.changes.any { it.pressed })
                } finally { job?.cancel(); if (fast) { fast = false; player.setPlaybackSpeed(speed) }; hudEpoch++ }
            }
        })
        if (buffering && !failure) CircularProgressIndicator(Modifier.align(Alignment.Center), color = Color.White.copy(alpha = .7f))
        if (failure) Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) { Icon(Icons.Rounded.ErrorOutline, null, Modifier.size(48.dp), tint = Color.White.copy(alpha = .7f)); Spacer(Modifier.height(12.dp)); Text("视频加载失败或链接已失效", color = Color.White.copy(alpha = .7f)); Spacer(Modifier.height(16.dp)); FilledTonalButton(onClick = tapFeedback { retry++ }) { Text("重试") } }
        if (fast) Row(Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(top = 50.dp).background(Color.Black.copy(alpha = .87f), RoundedCornerShape(20.dp)).border(.8.dp, Color.White.copy(alpha = .24f), RoundedCornerShape(20.dp)).padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Rounded.FastForward, null, Modifier.size(20.dp), tint = Color(0xFFFFD740)); Spacer(Modifier.width(8.dp)); Text("2.0X 倍速快进中", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold, letterSpacing = .5.sp) }
        if (controls && fullscreen) Row(Modifier.align(Alignment.TopCenter).fillMaxWidth().background(Brush.verticalGradient(listOf(Color.Black.copy(alpha = .87f), Color.Black.copy(alpha = .38f), Color.Transparent))).statusBarsPadding().padding(start = 12.dp, top = 8.dp, end = 12.dp, bottom = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            VideoHeaderButton(Icons.Rounded.ArrowBackIosNew, "返回", 18, ::toggleOrientation); Column(Modifier.weight(1f).padding(horizontal = 10.dp)) { Text(media.title, color = Color.White, maxLines = 1, fontSize = 14.sp, fontWeight = FontWeight.Bold); if (media.folderName.isNotEmpty()) Text("@${media.folderName}", color = Color.White.copy(alpha = .7f), maxLines = 1, fontSize = 12.sp) }; VideoHeaderButton(Icons.Rounded.Download, "保存视频", 20) { save(media.copy(video = effective)) }
        }
        if (controls && ready && !failure) Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().onSizeChanged { onBottomHeight(it.height) }.background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = .87f)))).navigationBarsPadding().padding(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 8.dp)) {
            val displayedPosition = scrubPosition ?: position.toFloat()
            Row(verticalAlignment = Alignment.CenterVertically) { Text(playbackTime(displayedPosition.toLong()), color = Color.White, fontSize = 12.sp); Slider(displayedPosition.coerceIn(0f, duration.coerceAtLeast(1).toFloat()), { scrubPosition = it }, Modifier.weight(1f), onValueChangeFinished = {
                scrubPosition?.let { target -> player.seekTo(target.toLong()); position = target.toLong() }
                scrubPosition = null
                interaction++
            }, enabled = duration > 0, valueRange = 0f..duration.coerceAtLeast(1).toFloat(), thumb = { Box(Modifier.size(12.dp).background(Color(0xFFFFD740), androidx.compose.foundation.shape.CircleShape)) }, track = { state -> Canvas(Modifier.fillMaxWidth().height(3.dp)) { val end = Offset(size.width, size.height / 2); drawLine(Color.White.copy(alpha = .24f), Offset(0f, end.y), end, size.height, StrokeCap.Round); drawLine(Color(0xFFFFD740), Offset(0f, end.y), Offset(size.width * state.value / duration.coerceAtLeast(1), end.y), size.height, StrokeCap.Round) } }); Text(playbackTime(duration), color = Color.White.copy(alpha = .7f), fontSize = 12.sp) }
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) { IconButton(onClick = tapFeedback { playPause() }) { Icon(if (playing) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, "播放/暂停", Modifier.size(32.dp), tint = Color.White) }; Spacer(Modifier.weight(1f)); TextButton(onClick = tapFeedback { speedSheet = true }) { Text(if (speed == 1f) "倍速" else "${speed}X", color = if (speed == 1f) Color.White else Color(0xFFFFD740), fontSize = 13.sp, fontWeight = FontWeight.Bold) }; IconButton(onClick = tapFeedback { toggleOrientation() }) { Icon(if (fullscreen) Icons.Rounded.FullscreenExit else Icons.Rounded.Fullscreen, if (fullscreen) "退出横屏" else "横屏播放", tint = Color.White) } }
        }
        if (hud.isNotEmpty()) Column(Modifier.align(Alignment.Center).widthIn(min = 150.dp).background(Color.Black.copy(alpha = .82f), RoundedCornerShape(20.dp)).border(1.dp, Color.White.copy(alpha = .24f), RoundedCornerShape(20.dp)).padding(horizontal = 18.dp, vertical = 14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(when (hudType) { "brightness" -> Icons.Rounded.Brightness6; "volume" -> Icons.Rounded.VolumeUp; else -> if (hud.startsWith("-")) Icons.Rounded.Replay10 else Icons.Rounded.Forward10 }, null, Modifier.size(28.dp), tint = Color.White)
            Spacer(Modifier.height(8.dp)); Text(hud, color = Color.White, fontSize = 13.sp)
            if (hudType != "seek") { Spacer(Modifier.height(10.dp)); Canvas(Modifier.width(120.dp).height(3.dp)) { drawRect(Color.White.copy(alpha = .24f)); drawRect(Color.White, size = size.copy(width = size.width * if (hudType == "brightness") brightness else volume)) } }
        }
    }
    if (speedSheet) ModalBottomSheet(sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), onDismissRequest = { speedSheet = false }, containerColor = Color(0xFF212121), shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp), dragHandle = null) {
        Column(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("选择播放倍速", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.height(12.dp))
            listOf(.5f, .75f, 1f, 1.25f, 1.5f, 2f, 3f).forEach { value ->
                Box(Modifier.fillMaxWidth().heightIn(min = 56.dp).feedbackClickable { speed = value; player.setPlaybackSpeed(value); speedSheet = false; interaction++ }, contentAlignment = Alignment.Center) { Text("${value}X", color = if (speed == value) Color(0xFFFFD740) else Color.White, fontSize = 15.sp, fontWeight = if (speed == value) FontWeight.Bold else FontWeight.Normal, textAlign = TextAlign.Center) }
            }
        }
    }
}

@Composable
private fun VideoHeaderButton(icon: ImageVector, label: String, size: Int, click: () -> Unit) {
    Box(Modifier.size(38.dp).clip(androidx.compose.foundation.shape.CircleShape).background(Color.Black.copy(alpha = .55f)).border(.8.dp, Color.White.copy(alpha = .25f), androidx.compose.foundation.shape.CircleShape).feedbackClickable(onClick = click), contentAlignment = Alignment.Center) { Icon(icon, label, Modifier.size(size.dp), tint = Color.White) }
}

@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.lurk

import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import android.graphics.drawable.Drawable
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.*
import coil.compose.AsyncImage
import coil.imageLoader
import coil.memory.MemoryCache
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

data class GalleryOrigin(val rect: Rect, val item: Media, val radius: Float, val crop: Boolean, val scope: Any, val index: Int, val image: () -> Drawable?)
class GalleryOrigins {
    val sources = mutableMapOf<String, GalleryOrigin>()
    var selected: String? = null
    var hidden by mutableStateOf<String?>(null)
        private set
    private var hidingOwner: Any? = null
    fun hide(owner: Any, key: String) { hidingOwner = owner; hidden = key }
    fun reveal(owner: Any) {
        if (hidingOwner === owner) { hidingOwner = null; hidden = null }
    }
    fun returnTarget(scope: Any, index: Int, original: String, viewport: Rect) =
        sources.entries.firstOrNull { (_, source) ->
            source.scope === scope && source.index == index && source.item.original == original &&
                !source.rect.isEmpty && source.rect.overlaps(viewport) && source.image() != null
        }
}
val LocalGalleryOrigins = staticCompositionLocalOf { GalleryOrigins() }
@Composable
internal fun GalleryThumbnail(
    galleryScope: Any, media: List<Media>, index: Int, radius: Int, url: String, modifier: Modifier,
    crop: Boolean = true, overlay: @Composable BoxScope.() -> Unit,
) {
    val registry = LocalGalleryOrigins.current; val open = LocalMedia.current
    val key = remember(galleryScope, index, url) { java.util.UUID.randomUUID().toString() }; val density = LocalDensity.current
    var drawable by remember(key) { mutableStateOf<Drawable?>(null) }
    DisposableEffect(key) { onDispose { registry.sources.remove(key) } }
    Box(modifier.onGloballyPositioned {
        registry.sources[key] = GalleryOrigin(Rect(it.positionOnScreen(), it.size.toSize()), media[index],
            with(density) { radius.dp.toPx() }, crop, galleryScope, index) { drawable }
    }.drawWithContent { if (registry.hidden != key) drawContent() }.feedbackClickable {
        registry.selected = key
        open(media, index)
    }) {
        OriginalPicture(url, "图片 ${index + 1}", if (crop) Modifier.fillMaxSize() else Modifier,
            if (crop) ContentScale.Crop else ContentScale.Fit) { drawable = it }
        overlay()
    }
}

@Composable
internal fun GalleryIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, description: String, glass: Boolean, click: () -> Unit) {
    if (!glass) {
        PlainGalleryControl(description, true, tapFeedback(click)) { Icon(icon, null, Modifier.size(24.dp), tint = Color.White) }
        return
    }
    val source = LocalBackdrop.current
    val context = LocalContext.current
    val optics = if (glass && android.os.Build.VERSION.SDK_INT >= 33 && source != null) {
        remember(context) { runCatching { GlassOptics(context) }.getOrNull() }
    } else null
    var down by remember { mutableStateOf(false) }
    var drag by remember { mutableStateOf(Offset.Zero) }
    val press by animateFloatAsState(if (glass && down) 1f else 0f, spring(stiffness = if (down) 631.65f else 503.55f, dampingRatio = if (down) .75f else .55f), label = "gallery glass press")
    val resisted = drag / (1f + drag.getDistance() * .01f)
    val stretch by animateOffsetAsState(if (glass && down) resisted * .8f else Offset.Zero, spring(stiffness = if (down) 1754.6f else 157.91f, dampingRatio = if (down) .8f else .5f), label = "gallery glass stretch")
    Box(Modifier.size(48.dp).pointerInput(glass) {
        if (glass) awaitEachGesture {
            val first = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
            down = true
            try { do {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val change = event.changes.firstOrNull { it.id == first.id } ?: break
                drag = (change.position - first.position) / density
            } while (event.changes.any { it.pressed }) } finally { down = false; drag = Offset.Zero }
        }
    }.graphicsLayer {
        val transform = galleryButtonTransform(stretch, press)
        scaleX = transform[0]; scaleY = transform[1]; translationX = transform[2] * density; translationY = transform[3] * density
    }, contentAlignment = Alignment.Center) {
        if (glass && android.os.Build.VERSION.SDK_INT >= 33 && source != null && optics != null) {
            ReferenceGalleryGlass(source, optics, press, Modifier.matchParentSize())
        } else if (glass) Box(Modifier.matchParentSize().clip(CircleShape).backdrop(2f, material = LiquidMaterial(thickness = 32f, index = 1.24f, dispersion = .025f, tint = Color(0x66000000))))
        IconButton(onClick = tapFeedback { click() }, modifier = Modifier.fillMaxSize()) { Icon(icon, description, Modifier.size(22.dp), tint = Color.White) }
    }
}

@Composable
fun GalleryScreen(media: List<Media>, initial: Int, onBackReady: ((() -> Unit) -> Unit)? = null, close: () -> Unit) {
    val model = LocalState.current
    GalleryContent(media, initial, model.store.bool("key_use_liquid_glass_effect"), rememberMediaSaver(), onBackReady, close)
}

@Composable
internal fun GalleryContent(media: List<Media>, initial: Int, glass: Boolean, save: (Media) -> Unit, onBackReady: ((() -> Unit) -> Unit)? = null, close: () -> Unit) {
    if (media.isEmpty()) return
    val context = LocalContext.current; val registry = LocalGalleryOrigins.current
    val hidingOwner = remember { Any() }
    val haptics = LocalHapticFeedback.current
    val originKey = remember { registry.selected }
    val origin = remember { registry.sources[originKey] }
    val preview = remember { origin?.takeUnless { it.item.isVideo }?.image?.invoke()?.let(::snapshotGalleryDrawable) }
    val frames = remember { mutableMapOf<Int, () -> Pair<Drawable, ImageGeometry>?>() }
    var openingFlight by remember { mutableStateOf<ImageFlight?>(null) }
    var returnFlight by remember { mutableStateOf<ImageFlight?>(null) }
    var sourceKey by remember { mutableStateOf(originKey) }
    var playerMounted by remember { mutableStateOf(false) }
    var overlayBounds by remember { mutableStateOf<Rect?>(null) }
    val scope = rememberCoroutineScope()
    val backdrop = rememberBackdrop()
    val pager = rememberPagerState(initial.coerceIn(media.indices)) { media.size }
    val thumbnails = rememberPagerState(initial.coerceIn(media.indices)) { media.size }
    val mainDragging by pager.interactionSource.collectIsDraggedAsState(); val thumbDragging by thumbnails.interactionSource.collectIsDraggedAsState()
    var zoomed by remember { mutableStateOf(false) }; var controls by remember { mutableStateOf(true) }; var fullscreen by remember { mutableStateOf(false) }
    val exitFullscreen = remember { arrayOfNulls<() -> Unit>(1) }
    var currentVideo by remember { mutableStateOf(media[initial].video) }
    val motion = remember(scope) { GalleryOpeningMotion(scope) }
    val returning = motion.returning
    var slide by remember { mutableFloatStateOf(0f) }
    val openingFinished by remember { derivedStateOf { motion.position == 1f } }
    val pageDirection = if (LocalLayoutDirection.current == LayoutDirection.Rtl) -1f else 1f
    val currentControls by rememberUpdatedState(controls)
    var scrollOwner by remember { mutableIntStateOf(0) }
    var pendingFlightPage by remember { mutableStateOf<Int?>(null) }
    fun sourceHitTarget(): Rect? {
        if (!motion.returning && motion.position == 1f) return null
        val path = (if (playerMounted) returnFlight else openingFlight) ?: return null
        val bounds = overlayBounds ?: return null
        val source = registry.sources[sourceKey] ?: return null
        val frozen = if (playerMounted) path.to.viewport else path.from.viewport
        val live = source.rect.translate(-bounds.topLeft)
        if (source.scope !== origin?.scope || !source.rect.overlaps(bounds) || !live.overlaps(frozen)) return null
        return live
    }
    fun dismiss() {
        if (motion.returning) return
        pendingFlightPage = null
        if (playerMounted && motion.position == 1f && returnFlight == null) {
            val current = pager.currentPage
            val item = media[current]
            val bounds = overlayBounds
            val destination = if (origin != null && bounds != null) registry.returnTarget(origin.scope, current, item.original, bounds) else null
            val frame = frames[current]?.invoke()
            val bitmap = if (destination != null && !item.isVideo) frame?.first?.let(::snapshotGalleryDrawable) else null
            sourceKey = destination?.key
            if (destination != null && bitmap != null && frame != null && bounds != null) {
                val target = destination.value
                val viewport = target.rect.translate(-bounds.topLeft)
                val thumbnail = target.image()
                val targetPixels = thumbnail?.takeIf { it.intrinsicWidth > 0 && it.intrinsicHeight > 0 }
                    ?.let { Size(it.intrinsicWidth.toFloat(), it.intrinsicHeight.toFloat()) }
                    ?: Size(bitmap.width.toFloat(), bitmap.height.toFloat())
                val screen = Rect(Offset.Zero, bounds.size)
                val pageOffset = pager.currentPageOffsetFraction
                val start = visibleGalleryGeometry(frame.second, screen, slide - pageDirection * pageOffset * screen.width)
                returnFlight = ImageFlight(bitmap, start,
                    ImageGeometry(viewport, fittedImagePlane(viewport, targetPixels, target.crop), target.radius),
                    (thumbnail as? android.graphics.drawable.BitmapDrawable)?.bitmap)
                scrollOwner = 0
                if (pager.isScrollInProgress) pager.requestScrollToPage(current, pageOffset)
                registry.hide(hidingOwner, destination.key)
            }
        }
        motion.returnToSource {
            registry.reveal(hidingOwner)
            close()
        }
    }
    SideEffect { onBackReady?.invoke { if (fullscreen) exitFullscreen[0]?.invoke() else dismiss() } }
    val placed = overlayBounds != null
    val opening = !openingFinished && !returning
    val pagingBlocked by rememberUpdatedState(opening || returning || !playerMounted)
    LaunchedEffect(placed) { if (placed && !returning) motion.open() }
    DisposableEffect(Unit) { onDispose { registry.reveal(hidingOwner) } }
    LaunchedEffect(placed, openingFinished, returning, pendingFlightPage) {
        if (placed && (openingFinished && !returning || openingFlight == null)) playerMounted = true
        if (openingFinished && !returning) {
            returnFlight = null
            val target = pendingFlightPage
            try {
                coroutineScope {
                    if (slide != 0f) launch { animate(slide, 0f, animationSpec = tween(200)) { value, _ -> slide = value } }
                    if (target != null) pager.animateScrollToPage(target)
                    else if (pager.currentPageOffsetFraction != 0f) pager.animateScrollToPage(pager.currentPage)
                }
            } finally {
                if (target != null && pendingFlightPage == target) pendingFlightPage = null
            }
        }
    }
    LaunchedEffect(pager.settledPage) {
        zoomed = false
        currentVideo = media[pager.settledPage].video
    }
    LaunchedEffect(pager.settledPage, opening, returning) {
        if (opening || returning) return@LaunchedEffect
        delay(100)
        val requests = listOf(pager.settledPage - 1, pager.settledPage + 1).filter { it in media.indices }.mapNotNull { index -> media[index].takeIf { !it.isVideo && it.original.isNotEmpty() }?.let { context.imageLoader.enqueue(mediaRequest(context, it.original, 2400)) } }
        try { awaitCancellation() } finally { requests.forEach { it.dispose() } }
    }
    var videoBottomHeight by remember { mutableIntStateOf(0) }
    var frozenThumbBottom by remember { mutableStateOf<Dp?>(null) }
    val densityForControls = LocalDensity.current
    val thumbBottom = frozenThumbBottom ?: if (media[pager.currentPage].isVideo && videoBottomHeight > 0) with(densityForControls) { videoBottomHeight.toDp() } + 8.dp else WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 32.dp
    LaunchedEffect(mainDragging, thumbDragging) {
        if (thumbDragging) {
            frozenThumbBottom = thumbBottom
            zoomed = false
            scrollOwner = 2
            pager.stopScroll()
        } else if (mainDragging) {
            frozenThumbBottom = null
            scrollOwner = 1
            thumbnails.stopScroll()
        }
    }
    LaunchedEffect(thumbnails) {
        snapshotFlow { thumbDragging || thumbnails.isScrollInProgress }.collectLatest { moving ->
            if (!moving) { delay(32); frozenThumbBottom = null }
        }
    }
    LaunchedEffect(scrollOwner, opening, returning) {
        if (scrollOwner != 0 && !opening && !returning) {
            val owner = scrollOwner; val source = if (owner == 1) pager else thumbnails; val target = if (owner == 1) thumbnails else pager
            var previous = source.currentPage
            var lastTick = -12L
            snapshotFlow { source.currentPage to source.currentPageOffsetFraction }.collect { (page, offset) ->
                val now = android.os.SystemClock.uptimeMillis()
                if (owner == 2 && page != previous && now - lastTick >= 12L) {
                    haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    lastTick = now
                }
                previous = page
                val position = (page + offset).coerceIn(0f, target.pageCount - 1f)
                val nearest = position.roundToInt()
                val fraction = position - nearest
                if (target.currentPage != nearest || abs(target.currentPageOffsetFraction - fraction) > .001f) {
                    target.requestScrollToPage(nearest, fraction)
                }
            }
        }
    }
    Box(Modifier.fillMaxSize().onGloballyPositioned {
        val bounds = Rect(it.positionOnScreen(), it.size.toSize())
        if (bounds.isEmpty) return@onGloballyPositioned
        if (overlayBounds == null && origin != null && preview != null && !origin.item.isVideo &&
            !origin.rect.isEmpty && origin.rect.overlaps(bounds) && !returning) {
            val from = origin.rect.translate(-bounds.topLeft)
            val viewport = Rect(Offset.Zero, bounds.size)
            val pixels = Size(preview.width.toFloat(), preview.height.toFloat())
            openingFlight = ImageFlight(preview, ImageGeometry(from, fittedImagePlane(from, pixels, origin.crop), origin.radius),
                ImageGeometry(viewport, fittedImagePlane(viewport, pixels, false)))
        }
        overlayBounds = bounds
    }.galleryOverlayInput(
        flightTarget = ::sourceHitTarget,
        canSwipeFlight = { pagingBlocked && media.size > 1 && !fullscreen && !zoomed && !media[pager.currentPage].isVideo },
        onHoldFlight = { motion.holdingGesture = it },
        onTapSource = {
            if (motion.returning) motion.open() else dismiss()
            haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
        },
        onSwipeFlight = { dx ->
            val current = pendingFlightPage ?: pager.currentPage
            val target = current + if (dx * pageDirection < 0f) 1 else -1
            if (target in media.indices) {
                pendingFlightPage = target
                scrollOwner = 1
                motion.open(durationMillis = 120f)
            }
        },
    )) {
        BackHandler(!fullscreen) { dismiss() }
        CompositionLocalProvider(LocalBackdrop provides backdrop) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val width = constraints.maxWidth.toFloat(); val height = constraints.maxHeight.toFloat(); val density = LocalDensity.current
            val viewport = Rect(0f, 0f, width, height)
            val exitPath = returnFlight
            val imageFlight = if (playerMounted) exitPath else openingFlight
            val showHero = (opening || returning) && imageFlight != null
            val anchorKey = sourceKey
            SideEffect {
                if (showHero && anchorKey != null) registry.hide(hidingOwner, anchorKey)
                else registry.reveal(hidingOwner)
            }
            Box(Modifier.fillMaxSize().graphicsLayer {
                alpha = galleryBackdropAlpha(motion.position, abs(slide) / (size.width / 2f).coerceAtLeast(1f))
            }.background(Color.Black))
            if ((playerMounted || openingFinished) && !(returning && media[pager.currentPage].isVideo)) HorizontalPager(pager, userScrollEnabled = !zoomed && !fullscreen && !returning && !opening && !thumbDragging, beyondViewportPageCount = 0, modifier = Modifier.fillMaxSize().graphicsLayer { alpha = if (showHero) 0f else motion.position; translationX = slide }.backdropSource(backdrop)) { index ->
                val item = media[index]
                if (item.isVideo && pager.settledPage == index) CompositionLocalProvider(LocalBackdrop provides null) {
                    VideoPlayer(item, item.fromThreadPreview && media.count { it.isVideo } == 1,
                        { controls = it }, { fullscreen = it }, { currentVideo = it }, { videoBottomHeight = it }, { exitFullscreen[0] = it })
                }
                else {
                    var scale by remember { mutableFloatStateOf(1f) }; var offset by remember { mutableStateOf(Offset.Zero) }; var zoomJob by remember { mutableStateOf<Job?>(null) }
                    var imageFailed by remember { mutableStateOf(false) }; var imageReady by remember { mutableStateOf(false) }
                    var displayedDrawable by remember { mutableStateOf<android.graphics.drawable.Drawable?>((if (index == initial) preview else context.imageLoader.memoryCache?.get(MemoryCache.Key(item.original))?.bitmap)?.let { android.graphics.drawable.BitmapDrawable(context.resources, it) }) }
                    var retry by remember { mutableIntStateOf(0) }
                    DisposableEffect(index) { onDispose { zoomJob?.cancel(); frames.remove(index) } }
                    val fitted = displayedDrawable?.takeIf { it.intrinsicWidth > 0 && it.intrinsicHeight > 0 }?.let {
                        fittedImagePlane(viewport, Size(it.intrinsicWidth.toFloat(), it.intrinsicHeight.toFloat()), false)
                    }
                    val currentPlane by rememberUpdatedState(fitted)
                    SideEffect {
                        frames[index] = {
                            val drawable = displayedDrawable
                            val plane = currentPlane
                            if (drawable == null || plane == null) null else drawable to
                                ImageGeometry(viewport, transformedImagePlane(plane, viewport, scale, offset))
                        }
                    }
                    LaunchedEffect(pager.currentPage) { if (pager.currentPage != index) { zoomJob?.cancel(); scale = 1f; offset = Offset.Zero } }
                    LaunchedEffect(returning) { if (returning) zoomJob?.cancel() }
                    Box(Modifier.fillMaxSize().pointerInput(index, opening, returning) {
                        if (opening || returning) return@pointerInput
                        detectTapGestures(onTap = { haptics.performHapticFeedback(HapticFeedbackType.ContextClick); controls = !currentControls }, onDoubleTap = { point ->
                            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            zoomJob?.cancel(); val before = scale; val target = when { before <= 1.05f -> 2.5f; before <= 3.6f -> 6f; else -> 1f }; val startOffset = offset
                            zoomJob = scope.launch { animate(before, target, animationSpec = tween(260, easing = CubicBezierEasing(.215f, .61f, .355f, 1f))) { value, _ ->
                                if (pager.currentPage == index) {
                                    scale = value
                                    val focus = point - viewport.center
                                    offset = boundedImagePan((startOffset - focus) * (value / before) + focus, currentPlane ?: viewport, viewport, value)
                                    zoomed = value > 1f
                                }
                            } }
                        })
                    }.pointerInput(index, opening, returning) {
                        if (opening || returning) return@pointerInput
                        awaitEachGesture {
                            val down = awaitFirstDown(requireUnconsumed = false)
                            zoomJob?.cancel()
                            val start = down.position
                            val tracker = VelocityTracker().apply { addPosition(down.uptimeMillis, start) }
                            var draggingOut = false
                            var panned = false
                            var pinched = false
                            var released = false
                            try {
                                do {
                                    val event = awaitPointerEvent(); val multi = event.changes.count { it.pressed } > 1; val change = event.changes.firstOrNull { it.id == down.id } ?: break
                                    tracker.addPosition(change.uptimeMillis, change.position)
                                    released = event.changes.none { it.pressed }
                                    if (released) break
                                    if (multi || scale > 1f) {
                                        zoomJob?.cancel(); val zoom = event.calculateZoom(); val pan = event.calculatePan(); val old = scale
                                        pinched = pinched || multi
                                        panned = panned || (change.position - start).getDistance() > viewConfiguration.touchSlop
                                        scale = (scale * zoom).coerceIn(1f, 8f)
                                        val center = event.calculateCentroid(useCurrent = true) - Offset(size.width / 2f, size.height / 2f)
                                        offset = boundedImagePan((offset - center) * (scale / old) + center + pan, currentPlane ?: viewport, viewport, scale)
                                        if (pager.currentPage == index) zoomed = scale > 1f
                                        event.changes.forEach { it.consume() }
                                    } else {
                                        val diff = change.position - start
                                        if (!draggingOut && abs(diff.x) > viewConfiguration.touchSlop && abs(diff.x) > abs(diff.y) && ((index == 0 && diff.x > 0) || (index == media.lastIndex && diff.x < 0))) draggingOut = true
                                        if (draggingOut) { slide = diff.x; change.consume() }
                                    }
                                } while (event.changes.any { it.pressed })
                            } finally {
                                if (draggingOut) {
                                    if (released && abs(slide) > size.width * .22f) dismiss()
                                    else scope.launch { animate(slide, 0f, animationSpec = tween(200)) { value, _ -> slide = value } }
                                }
                            }
                            if (released && panned && !pinched && !draggingOut && scale > 1f) {
                                val velocity = tracker.calculateVelocity()
                                val direction = Offset(velocity.x, velocity.y)
                                val speed = direction.getDistance()
                                if (speed.isFinite() && speed >= 400f * density.density) {
                                    val initialPan = offset
                                    val travel = direction * (120f * density.density / speed)
                                    zoomJob = scope.launch {
                                        val startFrame = withFrameNanos { it }
                                        do {
                                            val t = withFrameNanos { (it - startFrame) / 1_000_000_000f }
                                            val progress = galleryPanProgress(t)
                                            offset = boundedImagePan(initialPan + travel * progress, currentPlane ?: viewport, viewport, scale)
                                        } while (progress < 1f)
                                    }
                                }
                            }
                        }
                    }, contentAlignment = Alignment.Center) {
                        val transform = Modifier.fillMaxSize().graphicsLayer { scaleX = scale; scaleY = scale; translationX = offset.x; translationY = offset.y }
                        if (!imageReady) {
                            val retained = (displayedDrawable as? android.graphics.drawable.BitmapDrawable)?.bitmap
                            if (retained != null) Image(retained.asImageBitmap(), null, transform, contentScale = ContentScale.Fit)
                            else AsyncImage(mediaRequest(context, item.thumbnail.ifEmpty { item.original }), null, transform,
                                onSuccess = { result -> if (!imageReady) displayedDrawable = result.result.drawable })
                        }
                        if (openingFlight != null || !opening && !returning || imageReady) key(retry) { AsyncImage(mediaRequest(context, item.original.ifEmpty { item.thumbnail }, 2400), "图片 ${index + 1}", transform, onSuccess = { result -> displayedDrawable = result.result.drawable; imageReady = true; imageFailed = false }, onError = { imageFailed = true }) }
                        if (imageFailed) Column(horizontalAlignment = Alignment.CenterHorizontally) { Icon(Icons.Rounded.BrokenImage, null, tint = Color.White.copy(alpha = .54f)); Text("图片加载失败", color = Color.White.copy(alpha = .7f)); OutlinedButton(onClick = tapFeedback { imageFailed = false; retry++ }) { Icon(Icons.Rounded.Refresh, null, tint = Color.White); Text("点击重试", color = Color.White) } }
                        else if (!imageReady && displayedDrawable == null && !showHero) CircularProgressIndicator(Modifier.size(32.dp), color = Color.White.copy(alpha = .7f), strokeWidth = 2.5.dp)
                    }
                }
            }
            if (showHero) {
                GalleryImageFlight(imageFlight) {
                    galleryHeroProgress(if (exitPath != null) 1f - motion.position else motion.position)
                }
            }
            val thumbnailAlpha by animateFloatAsState(if (controls && !opening && !returning) 1f else 0f, tween(160, easing = CubicBezierEasing(0f, 0f, .58f, 1f)), label = "thumbnail visibility")
            if (playerMounted && !fullscreen && !(glass && (opening || returning))) {
                if (media.size > 1) {
                    val thumbWidth = with(density) { (width * .16f).toDp() }
                    HorizontalPager(thumbnails, flingBehavior = rememberGalleryThumbnailFling(thumbnails), userScrollEnabled = controls && !opening && !returning, pageSize = PageSize.Fixed(thumbWidth), contentPadding = PaddingValues(horizontal = with(density) { (width * .42f).toDp() }), modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = thumbBottom).fillMaxWidth().height(64.dp).graphicsLayer { alpha = thumbnailAlpha * motion.position }) { index ->
                        val item = media[index]; val selected = pager.currentPage == index
                        Box(Modifier.fillMaxSize().padding(horizontal = 3.dp, vertical = 2.dp).clip(RoundedCornerShape(8.dp)).border(2.dp, if (selected) Color.White else Color.Transparent, RoundedCornerShape(8.dp)).feedbackClickable(enabled = controls && !opening && !returning) { scrollOwner = 0; frozenThumbBottom = null; zoomed = false; pager.requestScrollToPage(index); thumbnails.requestScrollToPage(index) }) { AsyncImage(mediaRequest(context, item.thumbnail.ifEmpty { item.original }, 160), "第 ${index + 1} 项", Modifier.fillMaxSize().padding(2.dp).clip(RoundedCornerShape(6.dp)), contentScale = ContentScale.Crop); if (item.isVideo) Icon(Icons.Rounded.PlayCircleFilled, null, Modifier.align(Alignment.Center).size(28.dp), tint = Color.White); if (!selected) Box(Modifier.matchParentSize().padding(2.dp).clip(RoundedCornerShape(6.dp)).background(Color.White.copy(alpha = .5f))) }
                    }
                }
                if (controls && !opening && !returning) Row(Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(horizontal = 16.dp, vertical = 10.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.width(96.dp)) { GalleryIcon(Icons.Rounded.ArrowBack, "关闭", glass, ::dismiss) }
                    Box(Modifier.weight(1f), contentAlignment = Alignment.Center) { Text("${pager.currentPage + 1} / ${media.size}", Modifier.background(Color.Black.copy(alpha = .45f), RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 6.dp), color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold) }
                    Row(Modifier.width(96.dp), horizontalArrangement = Arrangement.End) { val item = media[pager.currentPage].let { if (it.isVideo) it.copy(video = currentVideo) else it }; GalleryIcon(Icons.Rounded.Download, if (!item.isVideo) "保存图片" else "保存视频", glass, { save(item) }) }
                }
            }
        }
        }
    }
}


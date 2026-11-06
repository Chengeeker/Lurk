package com.lurk

import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalHapticFeedback
import android.content.Intent
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import androidx.lifecycle.viewmodel.compose.viewModel
import android.os.Build
import android.net.Uri
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.input.pointer.pointerInput
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.coroutineScope
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.semantics.*

class MainActivity : ComponentActivity() {
    private var incoming by mutableStateOf<String?>(null)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        incoming = intent?.dataString
        setContent { LurkApp(incoming) { incoming = null } }
    }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); incoming = intent.dataString }
}

data class ScreenTarget(val route: Route?, val tab: Int, val depth: Int)
// Flutter's easeInCubic is evaluated on a controller running from 1 to 0.
internal val routePopEasing = CubicBezierEasing(.325f, .81f, .45f, .945f)
data class Route(val kind: String, val id: String = "", val extra: String = "", val entry: String = java.util.UUID.randomUUID().toString())
val LocalState = staticCompositionLocalOf<LurkState> { error("No state") }
val LocalOpen = staticCompositionLocalOf<(Route) -> Unit> { {} }
val LocalMedia = staticCompositionLocalOf<(List<Media>, Int) -> Unit> { { _, _ -> } }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LurkApp(incoming: String?, consumeIncoming: () -> Unit) {
    val model: LurkState = viewModel()
    val lifecycle = androidx.lifecycle.compose.LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event -> if (event == androidx.lifecycle.Lifecycle.Event.ON_STOP) model.backgrounded() }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    val context = LocalContext.current
    val activity = androidx.activity.compose.LocalActivity.current
    val routeDirection = if (LocalLayoutDirection.current == LayoutDirection.Rtl) -1 else 1
    val systemDark = isSystemInDarkTheme()
    val revision = model.revision
    LaunchedEffect(revision, model.ready) {
        val display = activity?.window?.decorView?.display
        val requested = model.store.int("key_selected_display_mode_id")
        val modes = display?.supportedModes.orEmpty()
        val current = display?.mode
        val mode = modes.firstOrNull { it.modeId == requested } ?: modes.filter { it.physicalWidth == current?.physicalWidth && it.physicalHeight == current?.physicalHeight }.maxByOrNull { it.refreshRate }
        if (mode != null) activity?.window?.let { window -> window.attributes = window.attributes.apply { preferredDisplayModeId = mode.modeId } }
    }
    val dark = when (model.store.int("key_theme_mode")) { 1 -> false; 2 -> true; else -> systemDark }
    val dynamic = model.store.bool("key_use_dynamic_color") && Build.VERSION.SDK_INT >= 31
    val colors = when { dynamic && dark -> originalDynamicDarkColorScheme(context); dynamic -> dynamicLightColorScheme(context)
        else -> originalColorScheme(model.store.int("key_theme_color_index"), dark) }
    val scheme = if (dark && model.store.bool("key_is_pure_black_dark")) colors.copy(background = Color.Black, surface = Color.Black,
        surfaceContainer = Color(0xFF121212), surfaceContainerHigh = Color(0xFF181818), surfaceContainerHighest = Color(0xFF222222))
        else colors.copy(background = if (dark) Color(0xFF111215) else colors.surface)
    val density = LocalDensity.current
    val scale = (model.fontSizePreview ?: model.store.int("key_font_size_percent", 100)).coerceIn(80, 140) / 100f
    val stack = remember { mutableStateListOf<Route>() }
    val savedPages = rememberSaveableStateHolder()
    val pageSessions = remember(model.accountGeneration) { mutableMapOf<String, PageSession>() }
    val platformHaptics = LocalHapticFeedback.current
    val haptics = remember(model, platformHaptics) {
        AppHaptics(platformHaptics) { model.store.bool("key_enable_haptics", true) }
    }
    fun pop() { stack.removeLastOrNull() }
    var tab by rememberSaveable { mutableIntStateOf(model.store.int("key_habit_initial_tab_index", 1).coerceIn(0, 3)) }
    LaunchedEffect(model.ready) { if (model.ready) tab = model.store.int("key_habit_initial_tab_index", 1).coerceIn(0, 3) }
    var gallery by remember { mutableStateOf<Pair<List<Media>, Int>?>(null) }
    SideEffect { activity?.window?.let { window -> androidx.core.view.WindowCompat.getInsetsController(window, window.decorView).apply { isAppearanceLightStatusBars = !dark && gallery == null; isAppearanceLightNavigationBars = !dark && gallery == null } } }
    var galleryEpoch by remember { mutableIntStateOf(0) }
    val backdrop = rememberBackdrop()
    val origins = remember { GalleryOrigins() }
    val snackbar = remember { SnackbarHostState() }
    var bottomNotice by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { model.bottomMessages.collectLatest { bottomNotice = it; delay(2000); bottomNotice = null } }
    LaunchedEffect(Unit) { model.messages.collectLatest { text -> coroutineScope { launch { delay(2000); snackbar.currentSnackbarData?.dismiss() }; snackbar.showSnackbar(text, duration = SnackbarDuration.Indefinite) } } }
    val open: (Route) -> Unit = { route ->
        if (route.kind == "url") {
            val url = targetUrl(route.id)
            val native = nativeLink(url)
            when {
                url.isEmpty() -> model.message("无法打开此链接")
                native != null -> stack.add(Route(native.first, native.second))
                model.store.bool("key_use_internal_browser", true) -> stack.add(Route("browser", url))
                else -> runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }.onFailure { model.message("没有可打开链接的应用") }
            }
        } else stack.add(route)
    }
    LaunchedEffect(incoming, model.ready) { if (incoming != null && model.ready) { open(Route("url", incoming)); consumeIncoming() } }
    BackHandler(stack.isNotEmpty() || gallery != null) { if (gallery != null) gallery = null else pop() }
    var lastTabTap by remember { mutableLongStateOf(0L) }
    val scope = rememberCoroutineScope()
    var tabTapJob by remember { mutableStateOf<Job?>(null) }
    val selectTab: (Int) -> Unit = { target ->
        val now = android.os.SystemClock.uptimeMillis()
        tabTapJob?.cancel()
        if (target != tab) { tab = target; lastTabTap = 0 }
        else if (tab == 1) {
            if (lastTabTap != 0L && now - lastTabTap < 300) { pageSessions["tab:1"]?.commands?.tryEmit(model.store.bool("key_habit_double_tap_feed_refresh", true)); lastTabTap = 0 }
            else { lastTabTap = now; tabTapJob = scope.launch { delay(300); pageSessions["tab:1"]?.timelineToggle?.tryEmit(Unit); lastTabTap = 0 } }
        }
    }
    CompositionLocalProvider(LocalState provides model, LocalOpen provides open,
        LocalMedia provides { items, index -> if (index in items.indices) { val route = stack.lastOrNull(); if (origins.sources[origins.selected]?.item?.original != items[index].original) origins.selected = null; galleryEpoch++; gallery = items.map { if (it.threadId.isEmpty() && route?.kind == "thread") it.copy(threadId = route.id) else it } to index } },
        LocalGalleryOrigins provides origins, LocalBackdrop provides backdrop,
        LocalHapticFeedback provides haptics,
        LocalDensity provides remember(density, scale) { PreferenceDensity(density, scale) }, LocalRippleConfiguration provides null) {
        MaterialTheme(colorScheme = scheme, typography = originalTypography(model.store.int("key_font_weight_index", 1))) {
            CompositionLocalProvider(LocalOriginalCardColor provides (if (dark && model.store.bool("key_is_pure_black_dark")) Color(0xFF121212) else scheme.surfaceContainerLow), LocalDividerColor provides (if (dark && model.store.bool("key_is_pure_black_dark")) Color.White.copy(alpha = .1f) else scheme.outlineVariant.copy(alpha = if (dark) .2f else .3f)), LocalTextStyle provides MaterialTheme.typography.bodyMedium, androidx.compose.foundation.LocalIndication provides NoPressIndication) {
            Surface(Modifier.fillMaxSize()) {
                if (!model.ready) Box(Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) { CircularProgressIndicator() }
                else Scaffold(contentWindowInsets = WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal), snackbarHost = { SnackbarHost(snackbar) { data -> Snackbar(data, modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp), shape = RoundedCornerShape(16.dp), containerColor = Color(0xFF323232), contentColor = Color.White) } }, bottomBar = {
                    if (stack.isEmpty() && !model.store.bool("key_use_floating_nav_bar", true)) OriginalNavigation(tab, dark, selectTab)
                }) { padding ->
                    Box(Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding)) {
                        val target = ScreenTarget(stack.lastOrNull(), tab, stack.size)
                        Box(Modifier.fillMaxSize().backdropSource(backdrop)) {
                        AnimatedContent(targetState = target, contentKey = { it.route?.entry ?: "tab:${it.tab}" }, transitionSpec = {
                            if (targetState.depth > initialState.depth) slideInHorizontally(tween(320, easing = CubicBezierEasing(.215f, .61f, .355f, 1f))) { it * routeDirection } togetherWith fadeOut(tween(320), targetAlpha = 1f)
                            else if (targetState.depth < initialState.depth) (fadeIn(tween(220), initialAlpha = 1f) togetherWith slideOutHorizontally(tween(220, easing = routePopEasing)) { it * routeDirection }).apply { targetContentZIndex = -1f }
                            else if (targetState.route == null && initialState.route == null && targetState.tab != initialState.tab) {
                                val direction = (if (targetState.tab > initialState.tab) 1 else -1) * routeDirection
                                slideInHorizontally(tween(260, easing = CubicBezierEasing(.215f, .61f, .355f, 1f))) { it * direction } togetherWith slideOutHorizontally(tween(260, easing = CubicBezierEasing(.215f, .61f, .355f, 1f))) { -it * direction }
                            } else EnterTransition.None togetherWith ExitTransition.None
                        }, label = "page") { visible ->
                        val route = visible.route; val visibleTab = visible.tab
                        val back: () -> Unit = { if (route?.entry == stack.lastOrNull()?.entry) pop() }
                        val pageId = route?.entry ?: "tab:$visibleTab"
                        val pageSession = pageSessions.getOrPut(pageId) { PageSession() }
                        DisposableEffect(pageId) { onDispose { if (route != null && stack.none { it.entry == pageId }) { pageSessions.remove(pageId); savedPages.removeState(pageId) } } }
                        savedPages.SaveableStateProvider(pageId) {
                        CompositionLocalProvider(LocalPage provides pageSession) {
                        Surface(Modifier.fillMaxSize().then(if (route != null || model.store.bool("key_use_floating_nav_bar", true) && !model.store.bool("key_use_liquid_glass_effect")) Modifier.navigationBarsPadding() else Modifier), color = scheme.background) {
                        key(pageId, model.accountGeneration) {
                            when (route?.kind) {
                                "thread" -> ThreadScreen(route.id, route.extra, back)
                                "forum" -> ForumScreen(route.id, back)
                                "search" -> SearchScreen(route.id, back, route.extra)
                                "profile" -> ProfileScreen(route.id, back)
                                "myPosts" -> MyPostsScreen(back)
                                "list" -> UserListScreen(route.id, route.extra, back)
                                "login" -> LoginScreen(back)
                                "webLogin" -> BrowserScreen("https://wappass.baidu.com/passport?login&u=https%3A%2F%2Ftieba.baidu.com%2Findex%2Ftbwise%2Fmine", true, back) { if (stack.lastOrNull()?.entry == route.entry) { pop(); if (stack.lastOrNull()?.kind == "login") pop() } }
                                "browser" -> BrowserScreen(route.id, false, back)
                                "settings" -> SettingsScreen(route.id, back)
                                "backup" -> BackupScreen(back)
                                "saved", "history" -> SavedScreen(route.kind == "saved", back)
                                "compose" -> EditorScreen(route.id, route.extra, back) { if (stack.lastOrNull()?.entry == route.entry) { stack.getOrNull(stack.lastIndex - 1)?.let { pageSessions[it.entry]?.let { session -> session.invalidation++ } }; pop() } }
                                else -> when (visibleTab) { 0 -> OriginalFollowedScreen(); 1 -> FeedScreen(); 2 -> NotificationScreen(); else -> OriginalMeScreen() }
                            }
                        }
                        }
                        }
                        }
                        }
                        }
                        if (stack.isEmpty() && model.store.bool("key_use_floating_nav_bar", true)) Box(Modifier.align(androidx.compose.ui.Alignment.BottomCenter).then(if (model.store.bool("key_use_liquid_glass_effect")) Modifier else Modifier.navigationBarsPadding())) { OriginalNavigation(tab, dark, selectTab) }
                    }
                }
                bottomNotice?.let { text -> Box(Modifier.fillMaxSize().navigationBarsPadding().padding(horizontal = 16.dp, vertical = 12.dp), contentAlignment = androidx.compose.ui.Alignment.BottomCenter) { Text(text, Modifier.fillMaxWidth().background(Color(0xFF323232), RoundedCornerShape(16.dp)).semantics { liveRegion = LiveRegionMode.Polite }.padding(16.dp), color = Color.White) } }
                gallery?.let { (items, index) -> val epoch = galleryEpoch; key(epoch) { GalleryScreen(items, index) { if (galleryEpoch == epoch) gallery = null } } }
            }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PageBar(title: String, back: (() -> Unit)? = null, titleSize: androidx.compose.ui.unit.TextUnit = 18.sp, titleWeight: FontWeight? = null, frosted: Boolean = true, actions: @Composable RowScope.() -> Unit = {}) {
    val page = LocalPage.current
    val model = LocalState.current
    val colors = MaterialTheme.colorScheme
    val goToTop = tapFeedback { page.commands.tryEmit(false) }
    TopAppBar(title = { Text(title, Modifier.padding(start = if (back != null) 8.dp else 0.dp), maxLines = 1, fontSize = titleSize, fontWeight = titleWeight ?: FontWeight(500 + model.store.int("key_font_weight_index", 1).coerceIn(0, 4) * 100)) }, expandedHeight = 56.dp,
        colors = TopAppBarDefaults.topAppBarColors(containerColor = if (frosted) Color.Transparent else colors.background),
        modifier = (if (LocalFrostedHeader.current || !frosted) Modifier else Modifier.frostedTint(colors.background, colors.outlineVariant)).pointerInput(page) { detectTapGestures(onDoubleTap = { if (model.store.bool("key_habit_double_tap_top", true)) goToTop() }) }, navigationIcon = {
        if (back != null) IconButton(onClick = tapFeedback(back)) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "返回") }
    }, actions = actions, windowInsets = WindowInsets.statusBars)
}





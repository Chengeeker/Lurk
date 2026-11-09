package com.lurk

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.pager.*
import kotlinx.coroutines.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class NavigationAppearanceTest {
    @get:Rule val compose = createComposeRule()

    @Test fun opaqueFloatingSelectionLeavesShellVisibleAboveAndBelow() {
        val palette = originalColorScheme(0, false)
        var density = 1f
        compose.setContent {
            density = LocalDensity.current.density
            MaterialTheme(colorScheme = palette) {
                Box(Modifier.fillMaxWidth().testTag("floating-nav")) {
                    OriginalNavigationBar(1, dark = false, floating = true, glass = false) {}
                }
            }
        }
        val image = compose.onNodeWithTag("floating-nav").captureToImage().asAndroidBitmap()
        val x = compose.onNodeWithText("动态", useUnmergedTree = true).fetchSemanticsNode().boundsInRoot.center.x.toInt()
        assertEquals(palette.surfaceContainerHigh.toArgb(), image.getPixel(x, (2 * density).toInt()))
        assertEquals(palette.primaryContainer.toArgb(), image.getPixel(x - (14 * density).toInt(), (10 * density).toInt()))
        assertEquals(palette.surfaceContainerHigh.toArgb(), image.getPixel(x, (54 * density).toInt()))
    }

    @Test fun glassPressureStartsClosingOnReleaseAndSettlesWithinTheReferenceDuration() {
        var held by mutableStateOf(false)
        var pressure = 0f
        compose.mainClock.autoAdvance = false
        compose.setContent {
            val value = navigationGlassPressure(held).value.coerceIn(0f, 1f)
            SideEffect { pressure = value }
        }
        compose.runOnIdle { assertEquals(0f, pressure); held = true }
        repeat(40) {
            compose.mainClock.advanceTimeByFrame()
            compose.waitForIdle()
        }
        compose.runOnIdle { assertEquals(1f, pressure, .001f); held = false }
        repeat(5) {
            compose.mainClock.advanceTimeByFrame()
            compose.waitForIdle()
        }
        var previous = compose.runOnIdle { pressure }
        assertTrue("water must start shrinking immediately after release", previous in .001f.. .99f)
        repeat(13) {
            compose.mainClock.advanceTimeByFrame()
            val current = compose.runOnIdle { pressure }
            assertTrue(current <= previous)
            previous = current
        }
        assertEquals(0f, previous, .001f)
    }

    @Test fun allGlassSlotsUseThePaddedLabelCentersAndTheSameTapCoordinates() {
        for (density in listOf(1f, 2.625f, 3.5f)) {
            val width = 300f * density
            val expected = listOf(40.5f, 113.5f, 186.5f, 259.5f)
            for ((index, center) in expected.withIndex()) {
                val pill = navigationLensRect(width, 56f * density, index.toFloat(), 0f, 0f, density)
                assertEquals(center * density, pill.center.x, .001f)
                assertEquals(index.toFloat(), navigationTabPosition(pill.center.x, width, 4f * density), .001f)
            }
        }
    }

    @Test fun nestedReplySurfaceAndBackButtonEachFeedbackOnceAndRespectTheSwitch() {
        var enabled = true
        val events = mutableListOf<HapticFeedbackType>()
        val actions = mutableListOf<String>()
        val haptics = AppHaptics(object : HapticFeedback {
            override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) { events.add(hapticFeedbackType) }
        }) { enabled }
        compose.setContent {
            MaterialTheme {
                CompositionLocalProvider(LocalHapticFeedback provides haptics, androidx.compose.foundation.LocalIndication provides NoPressIndication) {
                    Column {
                        androidx.compose.material3.IconButton(onClick = tapFeedback { actions.add("back") }) {
                            androidx.compose.material3.Text("返回")
                        }
                        Column(Modifier.feedbackClickable { actions.add("article") }) {
                            androidx.compose.material3.Text("文章")
                            androidx.compose.material3.Surface(onClick = tapFeedback { actions.add("replies") }) {
                                androidx.compose.material3.Text("共 3 条回复")
                            }
                        }
                    }
                }
            }
        }
        compose.onNodeWithText("共 3 条回复").performTouchInput { click(center) }
        compose.onNodeWithText("返回").performClick()
        compose.runOnIdle {
            assertEquals(listOf("replies", "back"), actions)
            assertEquals(listOf(HapticFeedbackType.ContextClick, HapticFeedbackType.ContextClick), events)
            enabled = false
        }
        compose.onNodeWithText("共 3 条回复").performClick()
        compose.runOnIdle {
            assertEquals(listOf("replies", "back", "replies"), actions)
            assertEquals(2, events.size)
        }
    }

    @Test fun scaledBackdropSamplesTheSameScreenPixelsInsteadOfStretchingThem() {
        var scale by mutableFloatStateOf(1f)
        var sample by mutableStateOf(false)
        var density = 1f
        compose.setContent {
            density = LocalDensity.current.density
            val page = rememberBackdrop()
            Box(Modifier.size(240.dp, 180.dp)) {
                Canvas(Modifier.fillMaxSize().backdropSource(page)) {
                    for (i in 0..11) drawRect(if (i % 2 == 0) Color.Red else Color.Blue, Offset(i * 20.dp.toPx(), 0f), Size(20.dp.toPx(), size.height))
                }
                CompositionLocalProvider(LocalBackdrop provides page) {
                    Box(Modifier.offset(40.dp, 70.dp).size(100.dp, 60.dp).graphicsLayer { scaleX = scale; scaleY = scale }.then(if (sample) Modifier.backdrop(0f) else Modifier))
                }
            }
        }
        val original = compose.onRoot().captureToImage().asAndroidBitmap()
        for (factor in listOf(1.06f, 2f)) {
            compose.runOnIdle { scale = factor; sample = true }
            val result = compose.onRoot().captureToImage().asAndroidBitmap()
            for (x in listOf(50, 70, 90, 110, 130)) for (y in listOf(90, 110)) {
                val px = (x * density).toInt(); val py = (y * density).toInt()
                assertEquals("screen sampling at scale $factor / $x,$y", original.getPixel(px, py), result.getPixel(px, py))
            }
        }
    }

    @Test fun expandedLensKeepsItsActualSizeOutsideTheBar() {
        var measured = androidx.compose.ui.unit.IntSize.Zero
        var top = 0f
        var pixels = 1f
        compose.setContent {
            val density = LocalDensity.current; pixels = density.density
            Box(Modifier.size(340.dp, 120.dp)) {
                Box(Modifier.offset(20.dp, 30.dp).size(300.dp, 56.dp)) {
                    val rect = navigationLensRect(300f * pixels, 56f * pixels, 0f, 1f, 0f, pixels)
                    Box(Modifier.navigationLensPlacement(rect, density).onGloballyPositioned { measured = it.size; top = it.positionInRoot().y })
                }
            }
        }
        compose.runOnIdle {
            assertEquals(101.38f, measured.width / pixels, .6f)
            assertEquals(66.88f, measured.height / pixels, .6f)
            assertEquals(24.56f, top / pixels, .6f)
        }
    }

    @Test fun heldNavigationFollowsBothDirectionsAndCanReleaseAtTheFarEnd() {
        var selected by mutableIntStateOf(0)
        var ticks = 0
        val events = mutableListOf<HapticFeedbackType>()
        val haptics = object : HapticFeedback {
            override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) { events.add(hapticFeedbackType) }
        }
        compose.mainClock.autoAdvance = false
        compose.setContent {
            MaterialTheme(colorScheme = originalColorScheme(0, true)) {
                val page = rememberBackdrop()
                LaunchedEffect(Unit) { repeat(200) { withFrameNanos { ticks++ } } }
                Box(Modifier.size(340.dp, 180.dp)) {
                    Canvas(Modifier.fillMaxSize().backdropSource(page)) { drawRect(Color(0xFF111215)) }
                    CompositionLocalProvider(LocalBackdrop provides page, LocalHapticFeedback provides haptics) {
                        Box(Modifier.align(androidx.compose.ui.Alignment.BottomCenter).testTag("navigation")) { OriginalNavigationBar(selected, true, true, true) { selected = it } }
                    }
                }
            }
        }
        compose.mainClock.advanceTimeBy(32)
        val first = compose.onNodeWithText("进吧")
        val last = compose.onNodeWithText("我的")
        val distance = last.fetchSemanticsNode().boundsInRoot.center.x - first.fetchSemanticsNode().boundsInRoot.center.x
        first.performTouchInput { down(center) }
        compose.mainClock.advanceTimeBy(400)
        val before = ticks
        compose.mainClock.advanceTimeBy(400)
        assertTrue("held press must not block frame callbacks", ticks > before + 10)
        val atLeft = compose.onRoot().captureToImage().asAndroidBitmap()
        first.performTouchInput { moveBy(Offset(1f, -26f)) }
        first.performTouchInput { moveBy(Offset(distance - 1f, 0f)) }
        compose.mainClock.advanceTimeByFrame()
        val atRight = compose.onRoot().captureToImage().asAndroidBitmap()
        first.performTouchInput { moveBy(Offset(-distance, 0f)) }
        compose.mainClock.advanceTimeByFrame()
        val backAtLeft = compose.onRoot().captureToImage().asAndroidBitmap()
        fun differences(a: android.graphics.Bitmap, b: android.graphics.Bitmap): Int {
            var changed = 0
            for (y in 0 until a.height) for (x in 0 until a.width) if (a.getPixel(x, y) != b.getPixel(x, y)) changed++
            return changed
        }
        assertTrue(differences(atLeft, atRight) > 100)
        assertTrue(differences(atRight, backAtLeft) > 100)
        compose.runOnIdle { assertEquals(0, selected) }
        first.performTouchInput { moveBy(Offset(distance, 0f)); up() }
        compose.mainClock.advanceTimeBy(800)
        compose.runOnIdle {
            assertEquals(3, selected)
            assertEquals(listOf(HapticFeedbackType.LongPress), events)
        }
        first.performClick()
        compose.runOnIdle {
            assertEquals(0, selected)
            assertEquals(listOf(HapticFeedbackType.LongPress, HapticFeedbackType.ContextClick), events)
        }
        compose.mainClock.advanceTimeBy(800)
        val barTop = compose.onNodeWithTag("navigation").fetchSemanticsNode().boundsInRoot.top.toInt()
        val beforeDrag = compose.onRoot().captureToImage().asAndroidBitmap()
        first.performTouchInput {
            down(center)
            moveBy(Offset(distance, 0f))
        }
        compose.mainClock.advanceTimeBy(400)
        val directDrag = compose.onRoot().captureToImage().asAndroidBitmap()
        for (x in 0 until directDrag.width) {
            assertEquals("ordinary drag must not bloom above the bar", beforeDrag.getPixel(x, barTop - 3), directDrag.getPixel(x, barTop - 3))
        }
        compose.runOnIdle { assertEquals(2, events.size) }
        first.performTouchInput { cancel() }
    }

    @Test fun galleryThumbnailsSettleFromEitherSideAndCancelWithoutAnOldSnap() {
        lateinit var pager: PagerState
        lateinit var fling: TargetedFlingBehavior
        lateinit var scope: CoroutineScope
        compose.setContent {
            pager = rememberPagerState(initialPage = 2) { 10 }
            fling = rememberGalleryThumbnailFling(pager)
            scope = rememberCoroutineScope()
            HorizontalPager(pager, pageSize = PageSize.Fixed(60.dp), flingBehavior = fling, modifier = Modifier.size(300.dp, 64.dp)) { Box(Modifier.fillMaxSize()) }
        }
        compose.mainClock.autoAdvance = false
        for (offset in listOf(.3f, -.3f)) {
            lateinit var job: Job
            compose.runOnIdle { job = scope.launch { pager.scrollToPage(2, offset); pager.scroll { with(fling) { performFling(0f) {} } } } }
            compose.mainClock.advanceTimeBy(64)
            compose.runOnIdle { assertTrue(kotlin.math.abs(pager.currentPageOffsetFraction) < .3f); assertFalse(job.isCompleted) }
            compose.mainClock.advanceTimeBy(160)
            compose.runOnIdle { assertEquals(2, pager.currentPage); assertEquals(0f, pager.currentPageOffsetFraction, .001f); assertTrue(job.isCompleted) }
        }
        lateinit var moving: Job
        compose.runOnIdle { moving = scope.launch { pager.scrollToPage(2, .4f); pager.scroll { with(fling) { performFling(0f) {} } } } }
        compose.mainClock.advanceTimeBy(48)
        compose.runOnIdle { moving.cancel(); scope.launch { pager.scrollToPage(5, -.2f) } }
        compose.mainClock.advanceTimeBy(200)
        compose.runOnIdle { assertEquals(5, pager.currentPage); assertEquals(-.2f, pager.currentPageOffsetFraction, .001f) }
    }

    @Test fun restingAndDraggingUseDifferentGlyphAndGlassLayers() {
        var active by mutableStateOf(false)
        var background by mutableStateOf(Color(0xFF111215))
        compose.setContent {
            MaterialTheme(colorScheme = originalColorScheme(0, true)) {
                val page = rememberBackdrop()
                Box(Modifier.size(340.dp, 200.dp)) {
                    Canvas(Modifier.fillMaxSize().backdropSource(page)) {
                        drawRect(background)
                        for (i in 0..16) drawRect(if (i % 2 == 0) Color(0xFF59668E) else Color(0xFF998877), Offset(i * 20.dp.toPx(), 0f), Size(6.dp.toPx(), size.height))
                    }
                    CompositionLocalProvider(LocalBackdrop provides page) {
                        Box(Modifier.offset(20.dp, 100.dp).size(300.dp, 56.dp).graphicsLayer { scaleX = if (active) 1.06f else 1f; scaleY = scaleX }) {
                            LiquidNavigationContent({ if (active) 1.4f else 1f }, { if (active) 4f else 0f }, { if (active) 1f else 0f }, true,
                                listOf("进吧", "动态", "消息", "我的"),
                                listOf(Icons.Outlined.Forum, Icons.Outlined.DynamicFeed, Icons.Outlined.Notifications, Icons.Outlined.PersonOutline),
                                listOf(Icons.Rounded.Forum, Icons.Rounded.DynamicFeed, Icons.Rounded.Notifications, Icons.Rounded.Person)) {}
                        }
                    }
                }
            }
        }
        val rest = compose.onRoot().captureToImage().asAndroidBitmap()
        // A held water lens samples motion every frame; advance it explicitly instead of waiting for idle.
        compose.mainClock.autoAdvance = false
        compose.runOnIdle { active = true }
        compose.mainClock.advanceTimeByFrame()
        val drag = compose.onRoot().captureToImage().asAndroidBitmap()
        compose.runOnIdle { background = Color(0xFFB80019) }
        compose.mainClock.advanceTimeByFrame()
        val live = compose.onRoot().captureToImage().asAndroidBitmap()
        val sampleX = live.width / 2
        val sampleY = (live.height * .65f).toInt()
        assertNotEquals("the cached layers must still sample live page content", drag.getPixel(sampleX, sampleY), live.getPixel(sampleX, sampleY))
        var changed = 0
        for (y in 0 until rest.height) for (x in 0 until rest.width) if (rest.getPixel(x, y) != drag.getPixel(x, y)) changed++
        assertTrue("moving lens must change the composited image", changed > 300)
        val directory = java.io.File("build/reports/appearance").apply { mkdirs() }
        java.io.File(directory, "navigation-rest.png").outputStream().use { rest.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        java.io.File(directory, "navigation-drag.png").outputStream().use { drag.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
    }

    @Test fun fontSliderRetainsOriginalStepsAndMirrorsTouchInRtl() {
        var value by mutableFloatStateOf(100f)
        var rtl by mutableStateOf(false)
        compose.setContent {
            MaterialTheme {
                CompositionLocalProvider(androidx.compose.ui.platform.LocalLayoutDirection provides
                    if (rtl) androidx.compose.ui.unit.LayoutDirection.Rtl else androidx.compose.ui.unit.LayoutDirection.Ltr) {
                    Box(Modifier.width(300.dp).padding(top = 60.dp)) { OriginalFontSlider(value, { value = it }, {}) }
                }
            }
        }
        val slider = compose.onNode(SemanticsMatcher.keyIsDefined(androidx.compose.ui.semantics.SemanticsProperties.ProgressBarRangeInfo))
        slider.performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.SetProgress) { assertTrue(it(117f)) }
        compose.runOnIdle { assertEquals(115f, value, .01f) }
        slider.performTouchInput { click(Offset(width * .9f, center.y)) }
        compose.runOnIdle { assertEquals(140f, value, .01f); rtl = true }
        slider.performTouchInput { click(Offset(width * .9f, center.y)) }
        compose.runOnIdle { assertEquals(80f, value, .01f) }
    }

    @Test fun buttonGrowthAndAnchoredStretchStayContinuousAtDirectionReversal() {
        assertArrayEquals(floatArrayOf(1f, 1f, 0f, 0f), galleryButtonTransform(Offset.Zero, 0f), .0001f)
        val held = galleryButtonTransform(Offset.Zero, 1f)
        assertEquals(65f / 48f, held[0], .0001f)
        val right = galleryButtonTransform(Offset(20f, 0f), 1f)
        val left = galleryButtonTransform(Offset(-20f, 0f), 1f)
        assertEquals(right[0], left[0], .0001f); assertEquals(right[2], -left[2], .0001f)
        assertTrue(right[0] > held[0] && right[1] < held[1])
        assertEquals(0f, galleryButtonTransform(Offset(.001f, -.001f), 1f)[2], .001f)
    }

    @Test fun originalIndicatorInsetsExpansionAndVelocityDeformation() {
        val rest = navigationLensRect(300f, 56f, 1f, 0f, 0f, 1f)
        assertEquals(androidx.compose.ui.geometry.Rect(77f, 4f, 150f, 52f), rest)
        val expanded = navigationLensRect(300f, 56f, 1f, 1f, 0f, 1f)
        assertEquals(101.38f, expanded.width, .001f); assertEquals(66.88f, expanded.height, .001f)
        val moving = navigationLensRect(300f, 56f, 1f, 1f, 10f, 1f)
        assertEquals(expanded.center.x, moving.center.x, .001f)
        assertEquals(expanded.center.y, moving.center.y, .001f)
        assertTrue(moving.width < expanded.width && moving.height > expanded.height)
    }
}

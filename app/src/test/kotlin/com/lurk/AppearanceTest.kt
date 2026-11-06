package com.lurk

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.material.icons.rounded.PersonOutline
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
class AppearanceTest {
    @get:Rule val compose = createComposeRule()

    @Test fun whitespaceOnlyPostBodyDoesNotPushTheVideoDown() {
        var body by mutableStateOf(listOf(Segment("\n"), Segment("", media = Media("poster", isVideo = true))))
        compose.setContent {
            MaterialTheme {
                Column(Modifier.testTag("body-and-video")) {
                    RichText(body, Modifier.padding(top = 3.dp, bottom = 13.dp))
                    Box(Modifier.size(32.dp).testTag("video-cover"))
                }
            }
        }
        val bodyTop = compose.onNodeWithTag("body-and-video").fetchSemanticsNode().boundsInRoot.top
        fun videoTop() = compose.onNodeWithTag("video-cover").fetchSemanticsNode().boundsInRoot.top
        assertEquals(bodyTop, videoTop(), .01f)
        compose.runOnIdle { body = listOf(Segment("第一段\n\n第二段")) }
        compose.onNodeWithText("第一段\n\n第二段").assertExists()
        assertTrue(videoTop() > bodyTop)
    }

    @Test fun followedForumAndSharedListCardsPaintTheDarkNeutralSurface() {
        val app = org.robolectric.RuntimeEnvironment.getApplication()
        val palette = originalDynamicDarkColorScheme(app)
        val cardColor = app.getColor(android.R.color.system_neutral1_900)
        val background = Color(0xFF111215)
        assertEquals(cardColor, palette.surfaceContainerLow.toArgb())
        assertNotEquals(background.toArgb(), cardColor)
        compose.setContent {
            MaterialTheme(colorScheme = palette) {
                CompositionLocalProvider(LocalOriginalCardColor provides palette.surfaceContainerLow) {
                    Surface(color = background) {
                        Column(Modifier.width(260.dp)) {
                            Box(Modifier.testTag("forum-card")) {
                                ForumTile(Forum("1", "关注吧", 11, true, org.json.JSONObject()), true, false) {}
                            }
                            Box(Modifier.testTag("shared-card")) {
                                OriginalListCard(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                                    Spacer(Modifier.height(72.dp))
                                }
                            }
                        }
                    }
                }
            }
        }
        for (tag in listOf("forum-card", "shared-card")) {
            val bitmap = compose.onNodeWithTag(tag).captureToImage().asAndroidBitmap()
            assertEquals(background.toArgb(), bitmap.getPixel(bitmap.width / 2, 0))
            assertEquals(cardColor, bitmap.getPixel(bitmap.width * 4 / 5, bitmap.height / 3))
        }
    }

    @Test fun followedForumBadgesStayWholeOnNarrowCardsAndLargeFonts() {
        var width by mutableStateOf(163.dp)
        var scale by mutableFloatStateOf(1f)
        var clicks = 0
        compose.setContent {
            val density = androidx.compose.ui.platform.LocalDensity.current
            CompositionLocalProvider(androidx.compose.ui.platform.LocalDensity provides PreferenceDensity(density, scale)) {
                MaterialTheme(colorScheme = originalColorScheme(0, true), typography = originalTypography(1)) {
                    androidx.compose.material3.ProvideTextStyle(MaterialTheme.typography.bodyMedium) {
                        Box(Modifier.width(width)) { ForumTile(Forum("1", "用于检验长名称省略的关注吧", 11, true, org.json.JSONObject()), false, true) { clicks++ } }
                    }
                }
            }
        }
        for (size in listOf(163.dp, 143.dp, 200.dp)) for (fontScale in listOf(1f, 1.4f)) {
            compose.runOnIdle { width = size; scale = fontScale }
            for (text in listOf("Lv.11", "已签到")) {
                val layouts = mutableListOf<TextLayoutResult>()
                compose.onNodeWithText(text, useUnmergedTree = true).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
                assertEquals(text, layouts.single().layoutInput.text.text)
                assertEquals(1, layouts.single().lineCount)
                val layout = layouts.single()
                assertFalse("$text height at $size / $fontScale", layout.didOverflowHeight)
                assertTrue("$text width at $size / $fontScale", layout.getLineRight(0) <= layout.size.width + 1f)
                compose.onNodeWithText(text, useUnmergedTree = true).assertIsDisplayed()
            }
            if (size == 163.dp) {
                val directory = java.io.File("build/reports/appearance").apply { mkdirs() }
                java.io.File(directory, "followed-${(fontScale * 100).toInt()}.png").outputStream().use {
                    compose.onRoot().captureToImage().asAndroidBitmap().compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it)
                }
            }
        }
        compose.onNodeWithText("已签到").performClick()
        compose.runOnIdle { assertEquals(1, clicks) }
    }

    @Test fun inheritedLineHeightTracksFontSizeAndExplicitLeadingWins() {
        var fontScale by mutableFloatStateOf(1f)
        var pixelsPerDp = 1f
        compose.setContent {
            val density = androidx.compose.ui.platform.LocalDensity.current
            SideEffect { pixelsPerDp = density.density }
            CompositionLocalProvider(androidx.compose.ui.platform.LocalDensity provides PreferenceDensity(density, fontScale)) {
                MaterialTheme(typography = originalTypography(1)) {
                    CompositionLocalProvider(LocalTextStyle provides MaterialTheme.typography.bodyMedium) {
                        Column { Text("Small\nline", fontSize = 12.sp); Text("Large\nline", fontSize = 24.sp); Text("Explicit\nline", fontSize = 12.sp, lineHeight = 18.sp) }
                    }
                }
            }
        }
        fun leading(label: String): Float {
            val layouts = mutableListOf<TextLayoutResult>()
            compose.onNodeWithText(label).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
            return layouts.single().let { it.getLineBaseline(1) - it.getLineBaseline(0) }
        }
        val small = leading("Small\nline")
        assertEquals(small * 2, leading("Large\nline"), 1f)
        val explicit = leading("Explicit\nline")
        compose.runOnIdle { fontScale = 1.4f }
        assertEquals(12f * 20f / 14f * 1.4f * pixelsPerDp, leading("Small\nline"), 1f)
        assertEquals(18f * 1.4f * pixelsPerDp, leading("Explicit\nline"), 1f)
    }

    @Test fun classicRefreshShowsCompletionThenReturnsContentToItsOrigin() {
        var refreshing by mutableStateOf(true)
        var failed by mutableStateOf(false)
        compose.setContent {
            MaterialTheme {
                OriginalRefreshBox(refreshing, {}, Modifier.size(320.dp, 400.dp), failed) { Text("List content") }
            }
        }
        compose.onNodeWithText("正在刷新...").assertExists()
        compose.runOnIdle { refreshing = false }
        compose.onNodeWithText("刷新成功").assertExists()
        compose.mainClock.advanceTimeBy(1400)
        compose.waitForIdle()
        compose.onNodeWithText("刷新成功").assertDoesNotExist()
        compose.runOnIdle { refreshing = true; failed = true }
        compose.onNodeWithText("正在刷新...").assertExists()
        compose.runOnIdle { refreshing = false }
        compose.onNodeWithText("刷新失败").assertExists()
    }

    @Test fun profileAndFloorLevelBadgesRetainTheirDifferentTypography() {
        compose.setContent { MaterialTheme { Column { LevelBadge("12"); LevelBadge("12", profile = true) } } }
        for ((text, size) in listOf("12" to 9.5f, "Lv.12" to 10f)) {
            val layouts = mutableListOf<TextLayoutResult>()
            compose.onNodeWithText(text).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
            assertEquals(size, layouts.single().layoutInput.style.fontSize.value, .001f)
            assertEquals(1.1f, layouts.single().layoutInput.style.lineHeight.value, .001f)
        }
    }

    @Test fun notificationEmptyAndFailureUseTheOriginalTopOffsetAndRetry() {
        var failure by mutableStateOf<String?>(null)
        var retries = 0
        compose.setContent { MaterialTheme { Box(Modifier.size(320.dp, 500.dp)) { NotificationEmptyState("暂无回复消息", false, failure) { retries++ } } } }
        compose.onNodeWithText("暂无回复消息").assertTopPositionInRootIsEqualTo(156.dp)
        compose.runOnIdle { failure = "获取消息失败" }
        compose.onNodeWithText("获取消息失败").assertExists()
        compose.onNodeWithText("重试").performClick()
        compose.runOnIdle { assertEquals(1, retries) }
    }

    @Test fun denseBackupFieldKeepsEditingAndShowsInlineValidation() {
        var value by mutableStateOf("")
        var error by mutableStateOf<String?>(null)
        compose.setContent { MaterialTheme { Box(Modifier.width(320.dp)) {
            BackupTextField(value, { value = it }, "账号 / 邮箱", androidx.compose.material.icons.Icons.Rounded.PersonOutline, error = error)
        } } }
        val input = compose.onNode(hasSetTextAction())
        input.assertHeightIsEqualTo(48.dp)
        input.performTextInput("account")
        compose.runOnIdle { assertEquals("account", value); error = "请输入账号" }
        compose.onNodeWithText("请输入账号").assertExists()
        input.assertHeightIsEqualTo(48.dp)
        compose.runOnIdle { error = null }
        compose.onNodeWithText("请输入账号").assertDoesNotExist()
    }

    @Test fun feedEmptyAndErrorActionsMatchTheSelectedSection() {
        var error by mutableStateOf<String?>(null)
        var following by mutableStateOf(false)
        var retries = 0
        compose.setContent { MaterialTheme { Box(Modifier.size(320.dp, 400.dp), contentAlignment = androidx.compose.ui.Alignment.Center) {
            FeedEmptyState(following, error) { retries++ }
        } } }
        compose.onNodeWithText("暂无内容").assertDoesNotExist()
        compose.runOnIdle { error = "加载失败" }
        compose.onNodeWithText("加载失败").assertExists()
        compose.onNodeWithText("重试").performClick()
        compose.runOnIdle { following = true }
        compose.onNodeWithText("重试").assertDoesNotExist()
        compose.onNodeWithText("刷新").performClick()
        compose.runOnIdle { assertEquals(2, retries) }
    }

    @Test fun emptyImageUrlUsesOriginalPlaceholderWithoutADeadRetryAction() {
        compose.setContent {
            MaterialTheme { OriginalPicture("", "无效图片", Modifier.size(80.dp, 60.dp), androidx.compose.ui.layout.ContentScale.Crop) }
        }
        compose.onNodeWithContentDescription("无效图片").assertExists()
        compose.onNodeWithText("重新加载").assertDoesNotExist()
        compose.onRoot().assertWidthIsEqualTo(80.dp).assertHeightIsEqualTo(60.dp)
    }

    @Test fun appFontPreferenceIsAppliedAfterSystemAccessibilityScaling() {
        val system = androidx.compose.ui.unit.Density(3f, 2f)
        val preference = PreferenceDensity(system, 1.4f)
        listOf(12.sp, 24.sp, 48.sp).forEach { size ->
            val expected = with(system) { size.toDp() } * 1.4f
            assertEquals(expected.value, with(preference) { size.toDp() }.value, .001f)
            assertEquals(size.value, with(preference) { expected.toSp() }.value, .001f)
        }
    }

    @Test fun forumLabelsRemainReadableAcrossPalettesAndThemeSwitches() {
        var palette by mutableStateOf(originalColorScheme(0, false))
        compose.setContent {
            MaterialTheme(colorScheme = palette) {
                Surface(color = palette.surface) { Column(Modifier.width(320.dp)) {
                    ForumRuleBanner("本吧规则") {}
                    Surface(color = palette.surfaceContainerLow) { PinnedCount(1) }
                } }
            }
        }
        val context = androidx.test.core.app.ApplicationProvider.getApplicationContext<android.content.Context>()
        val palettes = (0..6).flatMap { listOf(originalColorScheme(it, false), originalColorScheme(it, true)) } +
            listOf(dynamicLightColorScheme(context), dynamicDarkColorScheme(context))
        palettes.forEach { colors ->
            compose.runOnIdle { palette = colors }
            listOf("吧规: 本吧规则" to colors.tertiaryContainer.copy(alpha = .35f).compositeOver(colors.surface), "1 篇置顶帖" to colors.surfaceContainerLow).forEach { (label, background) ->
                val layouts = mutableListOf<TextLayoutResult>()
                compose.onNodeWithText(label).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
                val a = layouts.single().layoutInput.style.color.luminance()
                val b = background.luminance()
                val contrast = (maxOf(a, b) + .05f) / (minOf(a, b) + .05f)
                assertTrue("$label contrast $contrast", contrast >= 4.5f)
            }
        }
        compose.runOnIdle { palette = originalColorScheme(0, true) }
        val file = java.io.File("build/reports/appearance/forum-dark.png").apply { parentFile?.mkdirs() }
        file.outputStream().use { compose.onRoot().captureToImage().asAndroidBitmap().compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
    }

    @Test fun switchingToDarkUpdatesInheritedTextInCardsAndPages() {
        var dark by mutableStateOf(false)
        compose.setContent {
            val colors = originalColorScheme(0, dark).copy(background = if (dark) Color(0xFF111215) else originalColorScheme(0, false).surface)
            MaterialTheme(colorScheme = colors, typography = originalTypography(1)) {
                Surface { Surface(color = colors.background) {
                    Column(Modifier.width(320.dp)) {
                        Text("Page")
                        SectionCard { Text("Settings") }
                        Card(colors = CardDefaults.cardColors(containerColor = colors.surfaceContainerLow)) { Text("Post") }
                        RichText(listOf(Segment("Body")))
                    }
                } }
            }
        }
        fun checkText(expectedLight: Boolean) {
            listOf("Page", "Settings", "Post", "Body").forEach { label ->
                val layouts = mutableListOf<TextLayoutResult>()
                compose.onNodeWithText(label).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
                val color = layouts.single().layoutInput.style.color
                assertEquals("$label uses $color", expectedLight, color.luminance() > .5f)
            }
        }
        checkText(false)
        compose.runOnIdle { dark = true }
        checkText(true)
    }
}

package com.lurk

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class)
class FilterScrollTest {
    @get:Rule val compose = createComposeRule()

    @Test fun changingCommentFilterDoesNotRepeatInitialTargetNavigation() {
        var selected by mutableIntStateOf(0)
        val session = PageSession()
        compose.setContent {
            CompositionLocalProvider(LocalPage provides session) {
                MaterialTheme {
                    Box(Modifier.size(320.dp, 400.dp)) {
                        PagedContent(identity = "comments", reloadKey = selected, targetId = "target", load = {
                            List(20) { org.json.JSONObject().put("id", if (selected == 1 && it == 10) "target" else "$it") } to false
                        }, header = {
                            Column {
                                Spacer(Modifier.height(600.dp))
                                TextButton(onClick = { selected = 1 }) { Text("只看楼主") }
                            }
                        }) { Text(it.s("id"), Modifier.height(50.dp)) }
                    }
                }
            }
        }
        compose.onNodeWithText("只看楼主").performScrollTo()
        val before = compose.onNodeWithText("只看楼主").fetchSemanticsNode().boundsInRoot
        compose.onNodeWithText("只看楼主").performClick()
        compose.waitForIdle()
        assertEquals(before, compose.onNodeWithText("只看楼主").fetchSemanticsNode().boundsInRoot)
    }

    @Test fun filterRetainsBothScrollAxesWhileLoadingAndAfterReplacement() {
        var selected by mutableIntStateOf(0)
        val next = CompletableDeferred<Pair<List<String>, Boolean>>()
        val session = PageSession()
        lateinit var tabs: androidx.compose.foundation.ScrollState
        compose.setContent {
            CompositionLocalProvider(LocalPage provides session) {
                MaterialTheme {
                    Box(Modifier.size(320.dp, 400.dp)) {
                        PagedContent(identity = "test", reloadKey = selected, load = {
                            if (selected == 0) List(20) { "old$it" } to false else next.await()
                        }, header = {
                            Column {
                                Spacer(Modifier.height(600.dp))
                                tabs = rememberScrollState()
                                Row(Modifier.horizontalScroll(tabs)) {
                                    repeat(10) { index ->
                                        TextButton(onClick = { selected = index }, modifier = Modifier.width(80.dp)) { Text("分类$index") }
                                    }
                                }
                            }
                        }) { Text(it, Modifier.height(50.dp)) }
                    }
                }
            }
        }
        compose.onNodeWithText("分类8").performScrollTo()
        val before = compose.onNodeWithText("分类8").fetchSemanticsNode().boundsInRoot
        val horizontal = tabs.value
        compose.onNodeWithText("分类8").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("正在刷新...").assertDoesNotExist()
        assertEquals(before, compose.onNodeWithText("分类8").fetchSemanticsNode().boundsInRoot)
        assertEquals(horizontal, tabs.value)
        compose.runOnIdle { next.complete(emptyList<String>() to false) }
        compose.waitForIdle()
        compose.onNodeWithText("刷新成功").assertDoesNotExist()
        assertEquals(before, compose.onNodeWithText("分类8").fetchSemanticsNode().boundsInRoot)
        assertEquals(horizontal, tabs.value)
    }

    @Test fun rapidFilterChangesDiscardCancelledResponsesAndRetainRowsOnFailure() {
        var selected by mutableIntStateOf(0)
        val stale = CompletableDeferred<Pair<List<String>, Boolean>>()
        val latest = CompletableDeferred<Pair<List<String>, Boolean>>()
        var fail = true
        val calls = mutableListOf<Pair<Int, Int>>()
        val session = PageSession()
        compose.setContent {
            CompositionLocalProvider(LocalPage provides session) {
                MaterialTheme {
                    PagedContent(identity = "test", reloadKey = selected, load = { page ->
                        calls.add(selected to page)
                        when (selected) {
                            0 -> listOf("initial") to false
                            1 -> withContext(NonCancellable) { stale.await() }
                            2 -> latest.await()
                            else -> if (fail) throw java.io.IOException() else listOf("retried") to false
                        }
                    }) { Text(it, Modifier.testTag("result")) }
                }
            }
        }
        compose.onNodeWithText("initial").assertExists()
        compose.runOnIdle { selected = 1 }
        compose.waitForIdle()
        compose.runOnIdle { selected = 2 }
        compose.waitForIdle()
        compose.runOnIdle { latest.complete(listOf("latest") to false) }
        compose.onNodeWithText("latest").assertExists()
        compose.runOnIdle { stale.complete(listOf("stale") to false) }
        compose.waitForIdle()
        compose.onNodeWithText("latest").assertExists()
        compose.onNodeWithText("stale").assertDoesNotExist()
        compose.runOnIdle { selected = 3 }
        compose.waitForIdle()
        compose.onNodeWithText("latest").assertExists()
        compose.onNodeWithText("加载失败，请重试").assertExists()
        compose.runOnIdle { fail = false }
        compose.onNodeWithText("重试").performScrollTo().performClick()
        compose.onNodeWithText("retried").assertExists()
        compose.onNodeWithText("latest").assertDoesNotExist()
        assertEquals(3 to 1, calls.last())
        val count = calls.size
        compose.runOnIdle { session.commands.tryEmit(true) }
        compose.waitForIdle()
        assertEquals(count + 1, calls.size)
        assertEquals(3 to 1, calls.last())
    }
}

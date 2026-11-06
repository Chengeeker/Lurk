package com.lurk

import androidx.compose.runtime.*
import kotlinx.coroutines.flow.MutableSharedFlow

class PageSession {
    val values = mutableMapOf<String, Any>()
    val commands = MutableSharedFlow<Boolean>(extraBufferCapacity = 1)
    val timelineToggle = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    var invalidation by mutableIntStateOf(0)
}

val LocalPage = staticCompositionLocalOf { PageSession() }

@Composable
@Suppress("UNCHECKED_CAST")
fun <T> pageState(key: String, initial: () -> T): MutableState<T> {
    val page = LocalPage.current
    return remember(page, key) { page.values.getOrPut(key) { mutableStateOf(initial()) } as MutableState<T> }
}

class PageItems<T> {
    var items by mutableStateOf(emptyList<T>())
    var number by mutableIntStateOf(0)
    var more by mutableStateOf(true)
}

@Composable
fun rememberPageScrollState(): androidx.compose.foundation.ScrollState {
    val state = androidx.compose.foundation.rememberScrollState(); val page = LocalPage.current
    LaunchedEffect(page) { page.commands.collect { state.animateScrollTo(0) } }
    return state
}

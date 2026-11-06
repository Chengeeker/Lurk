package com.lurk

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.json.JSONObject

internal class MyProfileLoad(private val scope: CoroutineScope) {
    var profile by mutableStateOf(JSONObject())
        private set
    var refreshing by mutableStateOf(false)
        private set
    var failed by mutableStateOf(false)
        private set
    private var requested = false
    private var request: Job? = null

    fun load(manual: Boolean, fetch: suspend () -> JSONObject) {
        if (manual) {
            refreshing = true
            failed = false
        }
        if (request?.isActive == true || (!manual && requested)) return
        requested = true
        request = scope.launch(start = CoroutineStart.LAZY) {
            val current = coroutineContext[Job]
            try {
                val result = fetch()
                if (request === current) profile = result
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                if (request === current && refreshing) failed = true
            } finally {
                if (request === current) refreshing = false
            }
        }
        request?.start()
    }

    fun clear() {
        val previous = request
        request = null
        previous?.cancel()
        requested = false
        profile = JSONObject()
        refreshing = false
        failed = false
    }
}

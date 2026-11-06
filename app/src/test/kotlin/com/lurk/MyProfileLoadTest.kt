package com.lurk

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.yield
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class MyProfileLoadTest {
    @Test fun tabReentryReusesSilentRequestAndOnlyPullShowsRefreshing() = runBlocking {
        val cache = MyProfileLoad(this)
        val response = CompletableDeferred<JSONObject>()
        var requests = 0
        val fetch: suspend () -> JSONObject = { requests++; response.await() }
        cache.load(manual = false, fetch)
        yield()
        assertFalse(cache.refreshing)
        cache.load(manual = false, fetch)
        cache.load(manual = true, fetch)
        assertTrue(cache.refreshing)
        assertEquals(1, requests)
        response.complete(JSONObject().put("user", "first"))
        yield()
        assertFalse(cache.refreshing)
        assertEquals("first", cache.profile.getString("user"))
        cache.load(manual = false, fetch)
        yield()
        assertEquals(1, requests)
        cache.load(manual = true) { requests++; throw java.io.IOException() }
        yield()
        assertEquals(2, requests)
        assertTrue(cache.failed)
        assertFalse(cache.refreshing)
        assertEquals("first", cache.profile.getString("user"))
    }

    @Test fun accountSwitchDoesNotPublishOldProfileOrClearTheNewRefresh() = runBlocking {
        val cache = MyProfileLoad(this)
        val old = CompletableDeferred<JSONObject>()
        val new = CompletableDeferred<JSONObject>()
        cache.load(manual = false) { withContext(NonCancellable) { old.await() } }
        yield()
        cache.clear()
        cache.load(manual = true) { new.await() }
        yield()
        old.complete(JSONObject().put("user", "old"))
        yield()
        assertFalse(cache.profile.has("user"))
        assertTrue(cache.refreshing)
        new.complete(JSONObject().put("user", "new"))
        yield()
        assertEquals("new", cache.profile.getString("user"))
        assertFalse(cache.refreshing)
    }
}

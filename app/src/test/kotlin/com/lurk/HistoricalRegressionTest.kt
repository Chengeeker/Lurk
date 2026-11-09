package com.lurk

import android.app.Application
import android.content.Context
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class HistoricalRegressionTest {
    @Test fun unavailableKeyStoreDoesNotBreakPreferencesOrEraseEncryptedData() {
        val context = RuntimeEnvironment.getApplication()
        val prefs = context.getSharedPreferences("lurk_compose", Context.MODE_PRIVATE)
        prefs.edit().clear().putString("_secret_accounts", "unreadable-ciphertext").commit()
        val store = AppStore(context)
        store.put("key_theme_mode", 2)
        assertEquals(2, store.int("key_theme_mode"))
        assertFalse(store.backup(false).getJSONObject("preferences").has("_secret_accounts"))
        store.importFlutter()
        assertNotNull(store.importError)
        assertFalse(store.bool("compose_import_done"))
        assertEquals("unreadable-ciphertext", prefs.getString("_secret_accounts", null))
        assertThrows(Exception::class.java) { store.backup(true) }
    }

    @Test fun floorAgreementUpdatesBeforeNetworkAndRollsBackOnFailure() = runBlocking {
        var visible = false to 4
        val response = CompletableDeferred<Unit>()
        val task = async {
            runCatching { optimisticAgreement(visible, { visible = it }) { enabled -> assertTrue(enabled); response.await() } }
        }
        yield()
        assertEquals(true to 5, visible)
        response.completeExceptionally(java.io.IOException())
        assertTrue(task.await().isFailure)
        assertEquals(false to 4, visible)
        optimisticAgreement(true to 0, { visible = it }) { assertFalse(it) }
        assertEquals(false to 0, visible)
    }
}

package com.lurk
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.CancellationException
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],manifest=Config.NONE,shadows=[ReplacingAtomicFileShadow::class])
class BackupLoginRestoreTest {
    private val context=ApplicationProvider.getApplicationContext<Context>()

    private val key=javax.crypto.KeyGenerator.getInstance("AES").apply{init(256)}.generateKey()
    private val store=AppStore(context,keyProvider={key})
    private fun account(id:String)=Account(JSONObject().put("uid",id).put("bduss","synthetic-$id").put("name","synthetic-$id"))
    private fun data(full:Boolean=true)=JSONObject().put("app","Lurk").put("version","2.0").put("backup_mode",if(full)"full"else"safe")
        .put("preferences",JSONObject().put("key_theme_mode",2).apply{if(full){put("key_accounts_list",org.json.JSONArray().put(account("2").raw.toString()));put("key_active_account_uid","2");put("key_active_account_name","synthetic-2");put("key_webdav_password","")}})
    private fun seed(){store.saveAccounts(listOf(account("1")),"1");store.put("key_theme_mode",0)}
    private fun uid()=store.active()?.uid
    private fun theme()=store.int("key_theme_mode",0)

    @Test fun verifiedLoginCommitsAndSurvivesARead()=runBlocking{seed();val result=store.restore(data()){it};assertTrue(result.contains("通过验证"));assertEquals("2",uid());assertEquals(2,theme())}
    @Test fun validationFailureRestoresOnlyNonLoginData()=runBlocking{seed();val result=store.restore(data()){error("synthetic validation failure")};assertTrue(result.contains("账号登录未恢复"));assertEquals("1",uid());assertEquals(2,theme())}
    @Test fun safeRestoreKeepsCurrentLogin()=runBlocking{seed();store.restore(data(false)){error("Safe restore must not verify")};assertEquals("1",uid());assertEquals(2,theme())}
    @Test fun newLoginDuringValidationOwnsTheState()=runBlocking{
        seed();try{store.restore(data()){store.saveAccounts(listOf(account("3")),"3");it};fail("Stale restore must stop")}catch(_:IllegalStateException){}
        assertEquals("3",uid());assertEquals(0,theme())
    }
    @Test fun cancellationDoesNotLookLikePartialSuccess()=runBlocking{
        seed();try{store.restore(data()){throw CancellationException()};fail("Cancellation must propagate")}catch(_:CancellationException){}
        assertEquals("1",uid());assertEquals(0,theme())
    }
}

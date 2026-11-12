package com.lurk
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],manifest=Config.NONE,shadows=[ReplacingAtomicFileShadow::class])
class FreshLoginRecoveryTest {
    private val context=ApplicationProvider.getApplicationContext<Context>()
    private fun newKey()=KeyGenerator.getInstance("AES").apply{init(256)}.generateKey()
    private var deviceKey:SecretKey?=newKey()
    private val keys:(Boolean)->SecretKey={create->deviceKey?:if(create)newKey().also{deviceKey=it}else throw SecretReadFailure(SecretFailureKind.MISSING_KEY)}
    private fun archived(bytes:ByteArray)=File(context.noBackupFilesDir,"account-recovery").listFiles().orEmpty().any{it.readBytes().contentEquals(bytes)}

    private val store=AppStore(context,keyProvider=keys)
    private val file get()=File(context.applicationInfo.dataDir,"shared_prefs/lurk_compose.xml")
    private fun account(id:String)=Account(org.json.JSONObject().put("uid",id).put("bduss","synthetic-$id").put("name","synthetic"))
    private fun seed():ByteArray{store.saveAccounts(listOf(account("1")),"1");store.put("key_theme_mode",2);return file.readBytes()}
    @Test fun newLoginAfterTransferArchivesOldCiphertextAndPersists()=runBlocking {
        val old=seed();deviceKey=null
        store.login("synthetic-new-cookie"){account("2")}
        assertEquals("2",store.active()!!.uid);assertTrue(archived(old));assertTrue(store.bool("compose_import_done"))
        assertEquals(2,store.int("key_theme_mode"));assertNull(store.importError)
        assertEquals("2",AppStore(context,keyProvider=keys).active()!!.uid)
    }
    @Test fun wrongDeviceKeyDoesNotBlockNewLogin()=runBlocking {
        val old=seed();deviceKey=newKey();store.login("synthetic"){account("2")}
        assertEquals("2",store.active()!!.uid);assertTrue(archived(old))
    }
    @Test fun readableOtherAccountsAreRetained()=runBlocking {
        val old=seed();store.login("synthetic"){account("2")}
        assertEquals(listOf("1","2"),store.accounts().map{it.uid});assertFalse(archived(old))
    }
    @Test fun failedValidationAndCancellationDoNotTouchOldData()=runBlocking {
        val old=seed();deviceKey=null
        try{store.login("synthetic"){throw IllegalArgumentException("synthetic rejected login")};fail()}catch(_:IllegalArgumentException){}
        try{store.login("synthetic"){throw CancellationException()};fail()}catch(_:CancellationException){}
        assertArrayEquals(old,file.readBytes());assertNull(deviceKey);assertFalse(archived(old))
    }
    @Test fun archiveFailureStopsBeforeCreatingKeyOrOverwritingAccount()=runBlocking {
        val old=seed();deviceKey=null
        File(context.noBackupFilesDir,"account-recovery").writeText("synthetic obstruction")
        try{store.login("synthetic"){account("2")};fail()}catch(_:IllegalStateException){}
        assertArrayEquals(old,file.readBytes());assertNull(deviceKey)
    }
    @Test fun newerLoginWinsDuringValidation()=runBlocking {
        seed()
        try{store.login("synthetic"){store.saveAccounts(listOf(account("3")),"3");account("2")};fail()}catch(_:IllegalStateException){}
        assertEquals("3",store.active()!!.uid)
    }
    @Test fun corruptDataStillRequiresExplicitRecoveryInsteadOfSilentLoss()=runBlocking {
        seed();context.getSharedPreferences("lurk_compose",0).edit().putString("_secret_accounts","bad").commit()
        val old=file.readBytes();deviceKey=null
        try{store.login("synthetic"){account("2")};fail()}catch(e:SecretReadFailure){assertEquals(SecretFailureKind.FORMAT,e.kind)}
        assertArrayEquals(old,file.readBytes());assertNull(deviceKey)
    }
}

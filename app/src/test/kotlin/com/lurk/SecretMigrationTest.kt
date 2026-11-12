package com.lurk
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],manifest=Config.NONE,shadows=[ReplacingAtomicFileShadow::class])
class SecretMigrationTest {
    private val context=ApplicationProvider.getApplicationContext<Context>()
    private var deviceKey:SecretKey?=KeyGenerator.getInstance("AES").apply{init(256)}.generateKey()
    private var creates=0
    private val keys:(Boolean)->SecretKey={create->
        deviceKey?:if(create){creates++;KeyGenerator.getInstance("AES").apply{init(256)}.generateKey().also{deviceKey=it}}
        else throw SecretReadFailure(SecretFailureKind.MISSING_KEY)
    }
    private val store=AppStore(context, keyProvider=keys)
    private val file get()=java.io.File(context.applicationInfo.dataDir,"shared_prefs/lurk_compose.xml")
    private suspend fun save(value:String){store.saveSecret("webdav",value)}
    private suspend fun load():String?=store.secret("webdav")
    private suspend fun failure(expected:SecretFailureKind,action:suspend ()->Unit){
        try{action();fail("Expected protected failure")}catch(e:SecretReadFailure){assertEquals(expected,e.kind)}
    }
    @Test fun missingKeyAndWrongKeyDoNotReplaceOriginalAndRestoredKeyWorks()=runBlocking {
        save("synthetic-portable-secret")
        val original=file.readBytes();val old=deviceKey
        deviceKey=null
        failure(SecretFailureKind.MISSING_KEY){load()}
        failure(SecretFailureKind.MISSING_KEY){save("replacement")}
        assertEquals(0,creates);assertArrayEquals(original,file.readBytes())
        deviceKey=KeyGenerator.getInstance("AES").apply{init(256)}.generateKey()
        failure(SecretFailureKind.AUTHENTICATION){load()}
        assertArrayEquals(original,file.readBytes())
        deviceKey=old;assertEquals("synthetic-portable-secret",load())
    }
    @Test fun malformedCiphertextNeverCreatesAKey()=runBlocking {
        save("synthetic")
        context.getSharedPreferences("lurk_compose",0).edit().putString("_secret_webdav","bad").commit()
        val original=file.readBytes();deviceKey=null
        failure(SecretFailureKind.FORMAT){load()}
        failure(SecretFailureKind.FORMAT){save("replacement")}
        assertArrayEquals(original,file.readBytes());assertEquals(0,creates)
    }

}

@org.robolectric.annotation.Implements(android.util.AtomicFile::class)
class ReplacingAtomicFileShadow {
    companion object {
        @JvmStatic @org.robolectric.annotation.Implementation
        fun rename(source:File,target:File){java.nio.file.Files.move(source.toPath(),target.toPath(),java.nio.file.StandardCopyOption.REPLACE_EXISTING)}
    }
}

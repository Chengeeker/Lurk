package com.lurk

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ObjectInputStream
import java.io.ObjectStreamClass
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.IvParameterSpec

class AppStore(val context: Context, private val keyProvider: ((Boolean)->SecretKey)? = null) {
    @Volatile var bookmarkVersion = 0L
    private val prefs = context.getSharedPreferences("lurk_compose", Context.MODE_PRIVATE)
    private val secrets = context.getSharedPreferences("lurk_compose_secrets", Context.MODE_PRIVATE)
    private val keyStore by lazy { KeyStore.getInstance("AndroidKeyStore").apply { load(null) } }
    var importError: String? = null
        private set

    fun value(key: String): Any? = prefs.all[key]
    fun string(key: String, default: String = "") = runCatching { prefs.getString(key, default) ?: default }.getOrDefault(default)
    fun bool(key: String, default: Boolean = false) = runCatching { prefs.getBoolean(key, default) }.getOrDefault(default)
    fun int(key: String, default: Int = 0) = runCatching { prefs.getInt(key, default) }.getOrElse { runCatching { prefs.getLong(key, default.toLong()).toInt() }.getOrDefault(default) }
    fun list(key: String): List<String> = JSONArray(string(key, "[]")).strings()
    fun put(key: String, value: Any) = putAll(mapOf(key to value))
    @Synchronized fun putAll(values: Map<String, Any>) {
        val edit = prefs.edit()
        values.forEach { (key, value) ->
        when (value) {
            is Boolean -> edit.putBoolean(key, value)
            is Int -> edit.putInt(key, value)
            is Long -> edit.putLong(key, value)
            is List<*> -> edit.putString(key, JSONArray(value).toString())
            else -> edit.putString(key, value.toString())
        }
        }
        check(edit.commit()) { "保存失败，请检查存储空间后重试" }
        if (values.keys.any { it.startsWith("key_bookmark_pending_") }) bookmarkVersion++
    }

    private fun secretKey(create: Boolean = false): SecretKey {
        keyProvider?.let { return it(create) }
        val alias = "lurk.compose.credentials.v1"
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        if (!create) throw SecretReadFailure(SecretFailureKind.MISSING_KEY)
        return KeyGenerator.getInstance("AES", "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }

    @Synchronized fun secret(name: String): String? = readEncrypted {
        val stored = prefs.getString("_secret_$name", null) ?: secrets.getString(name, null) ?: return@readEncrypted null
        if(stored.isEmpty())return@readEncrypted null
        val bytes = Base64.decode(stored, Base64.NO_WRAP)
        require(bytes.size in 28..(16 * 1024 * 1024)) { "凭据存储损坏" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8)
    }

    private fun encodeSecret(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey(create = true))
        return Base64.encodeToString(cipher.iv + cipher.doFinal(value.toByteArray()), Base64.NO_WRAP)
    }
    @Synchronized fun saveSecret(name: String, value: String) {
        secret(name)
        put("_secret_$name", encodeSecret(value))
    }

    fun accounts(): List<Account> {
        val group = secret("accounts") ?: return emptyList()
        val j = JSONObject(group)
        return validatedAccounts(j.getJSONArray("accounts"), j.getString("active"))
    }
    fun active(): Account? {
        val group = secret("accounts") ?: return null
        val j = JSONObject(group)
        return validatedAccounts(j.getJSONArray("accounts"), j.getString("active")).firstOrNull { it.uid == j.s("active") }
    }
    @Synchronized fun saveAccounts(accounts: List<Account>, active: String) {
        val list = JSONArray(accounts.map { it.raw.toString() })
        validatedAccounts(list, active)
        saveSecret("accounts", JSONObject().put("accounts", list).put("active", active).toString())
    }

    suspend fun login(cookie: String, verify: suspend (String) -> Account = { NativeApi().login(it) }) {
        val before = synchronized(this) { prefs.all.toMap() }
        val oldSecrets = synchronized(this) { secrets.all.toMap() }
        val verified = verify(cookie)
        require(verified.uid.isNotBlank() && verified.uid != "0" && verified.bduss.isNotBlank()) { "登录凭据无效" }
        validatedAccounts(JSONArray().put(verified.raw.toString()), verified.uid)
        kotlinx.coroutines.currentCoroutineContext().ensureActive()
        synchronized(this) {
            check(prefs.all == before && secrets.all == oldSecrets) { "账号或设置已改变，请重新登录" }
            val existing = try { accounts() } catch (failure: SecretReadFailure) {
                if (!failure.recoverable) throw failure
                listOf("lurk_compose", "lurk_compose_secrets").forEach { name ->
                    val source = java.io.File(context.applicationInfo.dataDir, "shared_prefs/$name.xml")
                    if (source.exists()) archiveEncryptedFile(context, source)
                }
                emptyList()
            }
            val accounts = existing.filterNot { it.uid == verified.uid } + verified
            val encoded = encodeSecret(JSONObject().put("accounts", JSONArray(accounts.map { it.raw.toString() }))
                .put("active", verified.uid).toString())
            try { putAll(mapOf("_secret_accounts" to encoded, "compose_import_done" to true)) }
            catch (failure: Exception) {
                try {
                    val rollback = prefs.edit()
                    listOf("_secret_accounts", "compose_import_done").forEach { name ->
                        when (val value = before[name]) {
                            is String -> rollback.putString(name, value)
                            is Boolean -> rollback.putBoolean(name, value)
                            else -> rollback.remove(name)
                        }
                    }
                    check(rollback.commit()) { "登录保存失败，回滚未完成" }
                } catch (rollback: Exception) { failure.addSuppressed(rollback) }
                throw failure
            }
            importError = null
        }
    }

    fun importFlutter() {
        if (bool("compose_import_done")) return
        try {
            val legacy = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val converted = legacy.all.filterKeys { it.startsWith("flutter.") }.mapKeys { it.key.removePrefix("flutter.") }
                .mapValues { (_, v) -> decodeLegacy(v) }
            // Validate all legacy lists before committing anything to the independent store.
            val secure = readFlutterAccounts()
            val fallback = converted["key_accounts_list"] as? List<*>
            val accountList = when {
                secure != null -> JSONArray(secure)
                fallback != null -> JSONArray(fallback)
                else -> JSONArray()
            }
            val active = (converted["key_active_account_uid"] as? String).orEmpty()
                .ifEmpty { accountList.optString(0).takeIf { it.isNotEmpty() }?.let { JSONObject(it).s("uid") }.orEmpty() }
            val accounts = validatedAccounts(accountList, if (accountList.length() == 0) "" else active)
            if (secure != null && !fallback.isNullOrEmpty()) {
                val other = validatedAccounts(JSONArray(fallback), active)
                require(other.associate { it.uid to (it.bduss to it.stoken) } == accounts.associate { it.uid to (it.bduss to it.stoken) }) { "旧凭据副本冲突，请先在 Flutter 中核对" }
            }
            converted.forEach { (key, v) -> if ((BackupSchema.allowed(key) || key == "key_selected_display_mode_id") && value(key) == null && v != null) put(key, v) }
            if (secret("accounts") == null) saveAccounts(accounts, if (accounts.isEmpty()) "" else active)
            if (secret("webdav") == null) saveSecret("webdav", converted["key_webdav_password"] as? String ?: "")
            put("compose_import_done", true)
            importError = null
        } catch (_: Exception) {
            importError = "旧数据读取失败，Flutter 原数据已保留。可重新尝试或导入原版全量备份。"
        }
    }

    private fun readFlutterAccounts(): String? {
        val old = context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE)
        val entry = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg_lurk_auth_accounts_v1"
        val encoded = old.getString(entry, null) ?: return null
        // Read-only legacy decryption: never instantiate a plugin cipher that can replace failed keys.
        val wrapped = context.getSharedPreferences("FlutterSecureKeyStorage", Context.MODE_PRIVATE)
            .getString("VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK", null)
        require(wrapped != null) { "旧安全密钥缺失" }
        val rsa = Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidKeyStoreBCWorkaround")
        rsa.init(Cipher.UNWRAP_MODE, keyStore.getKey("${context.packageName}.FlutterSecureStoragePluginKey", null))
        val aes = rsa.unwrap(Base64.decode(wrapped, Base64.DEFAULT), "AES", Cipher.SECRET_KEY)
        val bytes = Base64.decode(encoded, Base64.DEFAULT)
        require(bytes.size > 16)
        val cipher = Cipher.getInstance("AES/CBC/PKCS7Padding")
        cipher.init(Cipher.DECRYPT_MODE, aes, IvParameterSpec(bytes.copyOfRange(0, 16)))
        return String(cipher.doFinal(bytes.copyOfRange(16, bytes.size)), Charsets.UTF_8)
    }

    @Synchronized fun backup(full: Boolean): JSONObject {
        val values = JSONObject()
        prefs.all.forEach { (key, v) -> if (BackupSchema.allowed(key)) values.put(key,
            if (BackupSchema.isList(key)) JSONArray(v as String) else v) }
        if (full) {
            check(importError == null) { "旧安全存储尚未成功读取，不能导出全量备份" }
            val activeUid=active()?.uid
            val accounts = accounts().map{account->if(account.uid==activeUid)account.raw else JSONObject(account.raw.toString()).apply{listOf("bduss","stoken","baiduid","tbs").forEach(::remove);put("bduss","")}}
            values.put("key_accounts_list", JSONArray(accounts.map { it.toString() }))
                .put("key_active_account_uid", active()?.uid.orEmpty()).put("key_active_account_name", active()?.name.orEmpty())
                .put("key_webdav_password", secret("webdav").orEmpty())
        }
        return JSONObject().put("app", "Lurk").put("version", "2.0").put("backup_mode", if (full) "full" else "safe")
            .put("exported_at", java.time.Instant.now().toString()).put("preferences", values)
            .put("accountMode",if(full && active()!=null)"COOKIE"else"GUEST")
    }

    suspend fun restore(data: JSONObject, verify: suspend (Account) -> Account = { NativeApi().login(it.cookie) }): String = restoreMutex.withLock {
        val values = BackupSchema.validate(data)
        val full = data.s("backup_mode") == "full"
        val before = synchronized(this) { prefs.all.toMap() }
        val oldSecrets = synchronized(this) { secrets.all.toMap() }
        val incoming = if (full) validatedAccounts(values.getJSONArray("key_accounts_list"), values.getString("key_active_account_uid")) else emptyList()
        val active = incoming.firstOrNull { it.uid == values.s("key_active_account_uid") }
        var verified: Account? = null
        if(active != null) {
            try { verified=verify(active).also { check(it.uid == active.uid) { "登录校验账号不匹配" } } }
            catch(e:kotlinx.coroutines.CancellationException){throw e}
            catch(_:Exception){ }
        }
        kotlinx.coroutines.currentCoroutineContext().ensureActive()
        synchronized(this) {
            check(prefs.all == before && secrets.all == oldSecrets) { "账号或设置已改变，请重新恢复" }
            val updates = values.keys().asSequence().filter { BackupSchema.allowed(it) }.associateWith { values.get(it) }.toMutableMap()
            val secretUpdates = mutableMapOf<String,String>()
            if (full) {
                secretUpdates["webdav"]=values.getString("key_webdav_password")
                if(verified != null) {
                    val accounts=incoming.map { if(it.uid==verified!!.uid)verified!! else it }
                    secretUpdates["accounts"]=JSONObject().put("accounts",JSONArray(accounts.map { it.raw.toString() })).put("active",verified!!.uid).toString()
                    updates["compose_import_done"]=true
                }
                var archive=false
                secretUpdates.keys.forEach { name ->
                    try { secret(name) }
                    catch(e:SecretReadFailure){if(!e.recoverable)throw e;archive=true}
                }
                if(archive) {
                    listOf("lurk_compose", "lurk_compose_secrets").forEach { name ->
                        val source=java.io.File(context.applicationInfo.dataDir,"shared_prefs/$name.xml")
                        if(source.exists())archiveEncryptedFile(context,source)
                    }
                }
                secretUpdates.forEach { (name,value)->updates["_secret_$name"]=encodeSecret(value) }
            } else if(listOf("key_webdav_url","key_webdav_username").any { updates.containsKey(it) && updates[it]!=before[it] }) {
                updates["_secret_webdav"]=""
            }
            try { putAll(updates) }
            catch(e:Exception) {
                try {
                    val edit=prefs.edit().clear()
                    before.forEach { (key,value)->when(value){is Boolean->edit.putBoolean(key,value);is Int->edit.putInt(key,value);is Long->edit.putLong(key,value);is String->edit.putString(key,value)} }
                    check(edit.commit()) { "恢复失败，本机回滚未完成" }
                }catch(_:Exception){error("恢复失败且本机回滚未完成，请检查存储空间后重试")}
                throw e
            }
            if(verified != null)importError=null
        }
        when {
            verified != null -> "设置和本地资料已恢复，账号登录已通过验证并恢复。"
            full && active != null -> "资料已恢复，但账号登录未恢复，请重试或重新登录。当前会话保持不变。"
            full -> "设置和本地资料已恢复。备份没有可验证的登录凭据，当前会话保持不变。"
            else -> "设置和本地资料已恢复，当前账号登录保持不变。"
        }
    }

    @Synchronized fun history(item: ThreadItem) {
        if (bool("key_habit_do_not_save_history")) return
        val key = "key_browsing_history_list"
        val old = list(key).filter { runCatching { ThreadItem.parse(JSONObject(it)).id != item.id }.getOrDefault(true) }
        put(key, (old + item.raw.toString()).takeLast(200))
    }
    fun migrateBookmarks(uid: String) {
        if (uid.isEmpty()) return
        val old = list("key_bookmarks_list")
        if (old.isEmpty()) return
        val key = "key_bookmarks_list_$uid"; val pendingKey = "key_bookmark_pending_adds_$uid"
        val records = list(key).toMutableList()
        fun id(raw: String) = runCatching { ThreadItem.parse(JSONObject(raw)).id }.getOrDefault("")
        val ids = records.map(::id).toMutableSet(); val pending = list(pendingKey).toMutableSet()
        old.forEach { raw -> val tid = id(raw); if (tid.isNotEmpty() && ids.add(tid)) { records.add(raw); pending.add(tid) } }
        putAll(mapOf(key to records, pendingKey to pending.toList(), "key_bookmarks_list" to emptyList<String>()))
    }
    @Synchronized fun updatePreview(tid: String, content: JSONArray, uid: String) {
        val updates = mutableMapOf<String, Any>()
        listOf("key_browsing_history_list", "key_bookmarks_list" + uid.takeIf(String::isNotEmpty)?.let { "_$it" }.orEmpty()).forEach { key ->
            var changed = false
            val rows = list(key).map { raw ->
                runCatching {
                    val row = ThreadItem.parse(JSONObject(raw))
                    if (row.id == tid && row.segments.none { it.link.isNotEmpty() }) { changed = true; JSONObject(raw).removeSnippet().put("first_post_content", content).toString() } else raw
                }.getOrDefault(raw)
            }
            if (changed) updates[key] = rows
        }
        if (updates.isNotEmpty()) putAll(updates)
    }
    fun blocked(item: ThreadItem, followedForums: Set<String>? = null): Boolean {
        if (bool("key_block_video_threads") && item.media.any { it.isVideo }) return true
        if (bool("key_recommend_followed_only") && followedForums != null && item.forum.isNotEmpty() && item.forum !in followedForums) return true
        val content = item.title + " " + item.segments.joinToString { it.text } + " " + item.author.name
        if (list("key_white_words_list").any { it.isNotEmpty() && content.contains(it, true) }) return false
        return list("key_block_words_list").any { it.isNotEmpty() && content.contains(it, true) }
    }

    companion object {
        private val restoreMutex = kotlinx.coroutines.sync.Mutex()
        fun decodeLegacy(value: Any?): Any? {
            if (value !is String) return value
            val prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"
            if (value.startsWith("$prefix!")) return JSONArray(value.removePrefix("$prefix!")).strings()
            if (!value.startsWith(prefix)) return value
            val bytes = Base64.decode(value.removePrefix(prefix), Base64.DEFAULT)
            require(bytes.size <= 16 * 1024 * 1024)
            val input = object : ObjectInputStream(ByteArrayInputStream(bytes)) {
                override fun resolveClass(desc: ObjectStreamClass): Class<*> {
                    require(desc.name in setOf("java.util.ArrayList", "java.lang.String", "[Ljava.lang.String;")) { "无效的旧列表类型" }
                    return super.resolveClass(desc)
                }
            }
            val list = input.use { it.readObject() } as? List<*> ?: error("无效的旧列表")
            require(list.all { it is String })
            return list
        }
    }
}

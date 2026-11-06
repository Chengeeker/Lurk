package com.lurk

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.compose.runtime.*
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

class LurkState(app: Application) : AndroidViewModel(app) {
    val store = AppStore(app)
    var ready by mutableStateOf(false)
        private set
    var account by mutableStateOf<Account?>(null)
        private set
    var revision by mutableIntStateOf(0)
        private set
    var fontSizePreview by mutableStateOf<Int?>(null)
    var accountGeneration by mutableIntStateOf(0)
        private set
    var writing by mutableStateOf(false)
        private set
    private val notices = Channel<String>(Channel.BUFFERED)
    val messages = notices.receiveAsFlow()
    val bottomMessages = kotlinx.coroutines.flow.MutableSharedFlow<String>(extraBufferCapacity = 1)
    fun bottomMessage(text: String) { bottomMessages.tryEmit(text) }
    val api get() = NativeApi(account)
    internal val myProfile = MyProfileLoad(viewModelScope)

    fun loadMyProfile(manual: Boolean = false) {
        val user = account ?: return
        val client = api
        myProfile.load(manual) {
            client.post("/c/u/user/profile", mapOf("uid" to user.uid, "need_post_count" to "1"))
        }
    }
    private val bookmarkSync = Mutex()
    private val previewLanes = Semaphore(2)
    private val previews = linkedMapOf<String, Deferred<JSONObject?>>()
    suspend fun recoverPreview(item: ThreadItem): ThreadItem {
        if (item.segments.any { it.link.isNotEmpty() } || item.segments.any { it.text.isNotBlank() } && !Regex("网页链接|网盘|下载地址|查看链接").containsMatchIn(item.segments.joinToString { it.text })) return item
        val generation = accountGeneration; val client = api; val uid = account?.uid.orEmpty()
        val request = previews.getOrPut("$uid:${item.id}") {
            viewModelScope.async { previewLanes.withPermit { try { resolvePostAuthors(client.detail(item.id)).firstOrNull { it.s("floor") == "1" } } catch (e: CancellationException) { throw e } catch (_: Exception) { null } } }
        }
        if (previews.size > 64) previews.remove(previews.keys.first())
        val first = request.await() ?: return item
        if (!stillCurrent(generation) || parseContent(first.opt("content")).none { it.link.isNotEmpty() }) return item
        val updated = ThreadItem.parse(JSONObject(item.raw.toString()).removeSnippet().put("first_post_content", first.opt("content")))
        withContext(Dispatchers.IO) { store.updatePreview(item.id, first.optJSONArray("content") ?: JSONArray(), uid) }
        return updated
    }
    val agrees = mutableStateMapOf<String, Pair<Boolean, Int>>()
    val agreeing = mutableStateMapOf<String, Boolean>()
    var followedNames by mutableStateOf<Set<String>?>(null)
    private val signedForums = mutableStateMapOf<String, String>()
    private val signReadDays = mutableMapOf<String, String>()
    var followedSnapshot by mutableStateOf<List<Forum>>(emptyList()); private set
    var followedRevision by mutableIntStateOf(0); private set
    private var followedDay = ""
    fun invalidateFollowed() { followedNames = null; followedSnapshot = emptyList(); followedDay = ""; followedRevision++ }
    fun observeForum(forum: Forum) { signReadDays[forum.name] = today() }
    suspend fun loadFollowed(client: NativeApi = api): List<Forum> {
        val day = today(); val generation = accountGeneration; val rows = client.followedForums()
        if (stillCurrent(generation) && client.account?.uid == account?.uid && day == today()) { rows.forEach(::observeForum); followedSnapshot = rows; followedDay = day; followedNames = rows.map { it.name }.toSet() }
        return rows
    }
    fun signed(forum: Forum) = (forum.signed && signReadDays[forum.name] == today()) || signedForums[forum.name] == "${account?.uid}:${today()}"
    fun confirmSign(name: String) { signedForums[name] = "${account?.uid}:${today()}" }
    fun signOne(forum: Forum) = action { client, generation ->
        val day = today()
        client.signForum(forum.name, forum.id)
        if (stillCurrent(generation) && today() == day) { confirmSign(forum.name); message("签到成功") }
    }
    fun toggleAgree(item: ThreadItem) {
        if (account == null) { message("请先登录后再点赞"); return }
        if (agreeing[item.id] == true) return
        val previous = agrees[item.id] ?: (item.agreed to (item.agrees.toIntOrNull() ?: 0))
        val next = !previous.first to (previous.second + if (previous.first) -1 else 1).coerceIn(0, 999999)
        val client = api; val generation = accountGeneration
        agrees[item.id] = next; agreeing[item.id] = true
        viewModelScope.launch {
            try { client.agree(item.id, "", next.first) }
            catch (e: CancellationException) { throw e }
            catch (_: Exception) { if (stillCurrent(generation)) { agrees[item.id] = previous; message("点赞未完成，请刷新确认") } }
            finally { if (stillCurrent(generation)) agreeing.remove(item.id) }
        }
    }

    init {
        viewModelScope.launch {
            withContext(Dispatchers.IO) { store.importFlutter() }
            runCatching { autoClearCache(store) }
            try { account = withContext(Dispatchers.IO) { store.active() } }
            catch (_: Exception) { message("账号凭据读取失败，原数据已保留，请从全量备份恢复") }
            try { account?.let { withContext(Dispatchers.IO) { store.migrateBookmarks(it.uid) } } }
            catch (_: Exception) { message("本机收藏迁移未完成，原记录已保留") }
            ready = true
            store.importError?.let { message(it) }
        }
    }
    fun message(text: String) { notices.trySend(text) }
    @OptIn(coil.annotation.ExperimentalCoilApi::class)
    fun backgrounded() { if (store.bool("key_auto_clear_cache_on_exit")) viewModelScope.launch { runCatching { withContext(Dispatchers.IO) { coil.Coil.imageLoader(store.context).memoryCache?.clear(); coil.Coil.imageLoader(store.context).diskCache?.clear() } } } }
    fun setting(key: String, value: Any) {
        viewModelScope.launch {
            try { withContext(Dispatchers.IO) { store.put(key, value) }; revision++ }
            catch (_: Exception) { message("设置保存失败") }
        }
    }
    fun changeAccount(uid: String) = action(requireLogin = false) { _, _ ->
        withContext(Dispatchers.IO) { store.saveAccounts(store.accounts(), uid) }
        reloadAccount()
    }
    suspend fun reloadAccount() {
        account = withContext(Dispatchers.IO) { store.active() }
        agrees.clear(); agreeing.clear(); followedNames = null; followedSnapshot = emptyList(); followedDay = ""; signReadDays.clear(); signedForums.clear()
        accountGeneration++; revision++
        myProfile.clear()
        account?.let { withContext(Dispatchers.IO) { store.migrateBookmarks(it.uid) } }
    }
    fun login(cookie: String, done: () -> Unit) = action(requireLogin = false) { _, _ ->
        val a = NativeApi().login(cookie)
        withContext(Dispatchers.IO) { store.saveAccounts(store.accounts().filterNot { it.uid == a.uid } + a, a.uid) }
        reloadAccount(); done(); message("登录成功")
    }
    fun logout(uid: String) = action { _, _ ->
        withContext(Dispatchers.IO) {
            val remaining = store.accounts().filterNot { it.uid == uid }
            store.saveAccounts(remaining, if (account?.uid == uid) remaining.firstOrNull()?.uid.orEmpty() else account!!.uid)
        }
        reloadAccount()
    }

    fun action(requireLogin: Boolean = true, bottomErrors: Boolean = false, work: suspend (NativeApi, Int) -> Unit) {
        if (writing) return
        if (requireLogin && account == null) { message("请先登录"); return }
        val generation = accountGeneration
        val client = api
        writing = true
        viewModelScope.launch {
            try { work(client, generation) }
            catch (e: CancellationException) { throw e }
            catch (e: Exception) { val text = if (e is ApiFailure || e is IllegalArgumentException) e.message ?: "操作失败" else "操作未完成，网络写入结果可能未知，请先刷新核对"; if (bottomErrors) bottomMessage(text) else message(text) }
            finally { writing = false }
        }
    }
    fun stillCurrent(generation: Int) = generation == accountGeneration
    fun savedKey() = "key_bookmarks_list" + account?.uid?.let { "_$it" }.orEmpty()
    fun recordHistory(item: ThreadItem) { viewModelScope.launch { try { withContext(Dispatchers.IO) { store.history(item) }; revision++ } catch (_: Exception) { message("浏览记录保存失败") } } }
    fun saved(): List<ThreadItem> = store.list(savedKey()).mapNotNull { runCatching { ThreadItem.parse(JSONObject(it)) }.getOrNull() }

    fun bookmark(item: ThreadItem, desired: Boolean? = null) = action(requireLogin = false) { client, generation ->
        val key = savedKey()
        val old = saved()
        val add = desired ?: old.none { it.id == item.id }
        withContext(Dispatchers.IO) {
          synchronized(store) {
            val old = savedRows(store, key)
            val updates = mutableMapOf<String, Any>(key to (if (add) listOf(item) + old else old.filterNot { it.id == item.id }).map { it.raw.toString() })
            client.account?.uid?.let { uid ->
                val pending = "key_bookmark_pending_${if (add) "adds" else "removes"}_$uid"
                val opposite = "key_bookmark_pending_${if (add) "removes" else "adds"}_$uid"
                updates[pending] = (store.list(pending) + item.id).distinct()
                updates[opposite] = store.list(opposite).filterNot { it == item.id }
            }
            store.putAll(updates)
          }
        }
        revision++
        if (client.account == null) { message(if (add) "已收藏到本机" else "已取消本机收藏"); return@action }
        syncBookmarks(client)
        if (stillCurrent(generation)) message(if (add) "已收藏" else "已取消收藏")
    }

    suspend fun syncBookmarks(client: NativeApi = api, officialIds: Set<String> = emptySet()) = bookmarkSync.withLock {
        val uid = client.account?.uid ?: return@withLock
        for (add in listOf(true, false)) {
            val key = "key_bookmark_pending_${if (add) "adds" else "removes"}_$uid"
            for (id in store.list(key).take(100)) {
                val args = if (add) mapOf("data" to JSONArray().put(JSONObject().put("pid", "0").put("tid", id).put("status", "0").put("type", "0")).toString()) else mapOf("tid" to id)
                if (!add || id !in officialIds) client.write(if (add) "/c/c/post/addstore" else "/c/c/post/rmstore", args)
                withContext(Dispatchers.IO) { store.put(key, store.list(key).filterNot { it == id }) }
            }
        }
    }

    private fun today(): String {
        val c = Calendar.getInstance(TimeZone.getTimeZone("Asia/Shanghai"))
        return "${c.get(Calendar.YEAR)}-${c.get(Calendar.DAY_OF_YEAR)}"
    }

    fun batchSign(done: () -> Unit) = action(bottomErrors = true) { client, generation ->
        fun complete(rows: List<Forum>) = batchTargets(rows).let { it.isNotEmpty() && it.all(::signed) }
        if (followedDay == today() && complete(followedSnapshot)) { bottomMessage("已完成签到（≥7级吧）"); done(); return@action }
        val day = today()
        val before = if (followedDay == day && followedSnapshot.isNotEmpty()) followedSnapshot else loadFollowed(client)
        if (!stillCurrent(generation)) return@action
        if (day != today()) throw ApiFailure("日期已变化，请刷新签到状态后重试")
        if (complete(before)) { bottomMessage("已完成签到（≥7级吧）"); done(); return@action }
        val token = client.tbs()
        if (!stillCurrent(generation)) return@action
        val earlyMessage = "普通用户在北京时间00:00–01:00暂不支持一键签到，请01:00后重试，或进入贴吧单独签到"
        fun early() = Calendar.getInstance(TimeZone.getTimeZone("Asia/Shanghai")).get(Calendar.HOUR_OF_DAY) == 0
        var member: Boolean? = null
        if (early()) {
            try {
                val user = client.post("/c/u/user/profile", mapOf("uid" to client.account!!.uid, "need_post_count" to "1")).obj("user")
                if (user.s("id") == client.account.uid) member = user.s("is_mem").toIntOrNull()?.takeIf { it >= 0 }?.let { it > 0 }
            } catch (e: CancellationException) { throw e } catch (_: Exception) { }
            if (!stillCurrent(generation)) return@action
            if (early() && member == false) throw ApiFailure(earlyMessage)
        }
        val result = try { client.post("/c/c/forum/msign", mapOf("tbs" to token), false) }
            catch (e: CancellationException) { throw e } catch (_: Exception) { null }
        if (!stillCurrent(generation)) return@action
        val success = result != null && signComplete(result.s("error_code"), result.s("error_msg")) &&
            (!result.has("error") || result.optJSONObject("error")?.let { signComplete(it.s("errno"), it.s("errmsg")) } == true)
        val verified = !success || day != today()
        if (verified) {
            val verifyDay = today(); val after = client.followedForums()
            if (!stillCurrent(generation)) return@action
            val confirmed = after.map { it.copy(signed = it.signed || signedForums[it.name] == "${account?.uid}:$verifyDay") }
            if (verifyDay != today() || !verifyBatchSigns(before, confirmed)) throw ApiFailure(if (member == null && early()) "一键签到未完成。$earlyMessage" else "未确认全部签到完成，请稍后查看")
            after.forEach(::observeForum); followedSnapshot = after; followedDay = verifyDay
        }
        if (!stillCurrent(generation)) return@action
        followedSnapshot.filter { it.level >= 7 }.forEach { confirmSign(it.name) }
        if (!verified) { try { loadFollowed(client) } catch (e: CancellationException) { throw e } catch (_: Exception) { } }
        if (stillCurrent(generation)) { bottomMessage("已完成签到（≥7级吧）"); done(); revision++ }
    }
}

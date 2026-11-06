package com.lurk

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import java.io.IOException

class ApiFailure(message: String) : Exception(message)

class NativeApi(val account: Account? = null) {
    companion object {
        const val BASE = "https://c.tieba.baidu.com"
        const val CUID = "baidutiebaapp4134907038753229"
        // Uncertain writes must never be retried by the HTTP client.
        val http = OkHttpClient.Builder().connectTimeout(15, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS).callTimeout(90, TimeUnit.SECONDS)
            .retryOnConnectionFailure(false).followRedirects(false).build()
    }

    suspend fun bytes(request: Request): ByteArray = suspendCancellableCoroutine { continuation ->
        val call = http.newCall(request)
        continuation.invokeOnCancellation { call.cancel() }
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) { if (continuation.isActive) continuation.resumeWithException(ApiFailure("网络请求失败，请检查连接")) }
            override fun onResponse(call: Call, response: Response) {
                try {
                    val result = response.use {
            if (!it.isSuccessful) throw ApiFailure("网络请求失败（${it.code}）")
            val body = it.body ?: throw ApiFailure("服务器返回空内容")
            if (body.contentLength() > 16 * 1024 * 1024) throw ApiFailure("响应过大")
            body.byteStream().use { stream ->
                val out = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val n = stream.read(buffer)
                    if (n < 0) break
                    if (out.size() + n > 16 * 1024 * 1024) throw ApiFailure("响应过大")
                    out.write(buffer, 0, n)
                }
                out.toByteArray()
            }
                    }
                    if (continuation.isActive) continuation.resume(result)
                } catch (e: Exception) { if (continuation.isActive) continuation.resumeWithException(e) }
            }
        })
    }

    fun request(url: String, auth: Boolean = true) = Request.Builder().url(url)
        .header("User-Agent", "bdtb for Android 12.41.7.1").apply {
            if (auth && account != null) {
                header("Cookie", account.cookie)
                header("client_logid", System.currentTimeMillis().toString())
                header("client_user_token", account.uid)
            }
        }

    suspend fun post(path: String, args: Map<String, String> = emptyMap(), check: Boolean = true): JSONObject {
        require(path.startsWith("/c/"))
        val params = args.toMutableMap()
        account?.let { a ->
            listOf("BDUSS", "bduss", "bdusstoken").forEach { params.putIfAbsent(it, a.bduss) }
            params.putIfAbsent("stoken", a.stoken)
        }
        params.putIfAbsent("_client_version", "12.41.7.1")
        params.putIfAbsent("_client_type", "2")
        params.putIfAbsent("cuid", CUID)
        params.putIfAbsent("timestamp", System.currentTimeMillis().toString())
        params["sign"] = sign(params)
        val form = FormBody.Builder().apply { params.forEach { (k, v) -> add(k, v) } }.build()
        val result = JSONObject(String(bytes(request(BASE + path).post(form).build()), Charsets.UTF_8))
        if (check) checkResult(result)
        return result
    }

    fun checkResult(j: JSONObject, required: Boolean = false) {
        val code = j.s("error_code").ifEmpty { j.obj("error").s("errno", "error_code") }
        val nested = j.obj("error").s("errno", "error_code")
        if ((code.isNotEmpty() && code != "0") || (nested.isNotEmpty() && nested != "0") || required && code != "0") {
            throw ApiFailure(j.s("error_msg", "msg").ifEmpty { j.obj("error").s("user_msg", "errmsg") }.ifEmpty { "请求失败（${code.ifEmpty { "未知" }}）" })
        }
    }

    suspend fun web(path: String, args: Map<String, String> = emptyMap()): JSONObject {
        val url = HttpUrl.Builder().scheme("https").host("tieba.baidu.com").encodedPath(path)
            .apply { args.forEach { (k, v) -> addQueryParameter(k, v) } }.build()
        return JSONObject(String(bytes(request(url.toString()).build()), Charsets.UTF_8))
    }

    suspend fun tbs(): String {
        require(account != null) { "请先登录" }
        val mobile = try { post("/c/s/login", mapOf("bdusstoken" to account.bduss)) }
            catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (_: Exception) { JSONObject() }
        return mobile.obj("anti").s("tbs").takeIf { mobile.obj("user").s("id") == account.uid }.orEmpty().ifEmpty {
            val fallback = web("/dc/common/tbs")
            if (!fallback.flag("is_login")) throw ApiFailure("登录已失效")
            fallback.s("tbs").ifEmpty { throw ApiFailure("无法获取登录凭据") }
        }
    }

    suspend fun login(cookie: String): Account {
        val pairs = cookie.split(';').mapNotNull { it.trim().split('=', limit = 2).takeIf { it.size == 2 } }
            .associate { it[0] to it[1] }
        val bduss = pairs["BDUSS"] ?: pairs["BDUSS_BFESS"] ?: cookie.trim().takeIf { !it.contains(';') }.orEmpty()
        require(bduss.isNotEmpty() && !bduss.contains('\n') && !bduss.contains('\r')) { "请输入有效的登录凭据" }
        val candidate = Account(JSONObject().put("uid", "").put("bduss", bduss).put("stoken", pairs["STOKEN"].orEmpty())
            .put("baiduid", pairs["BAIDUID"] ?: pairs["BAIDUID_BFESS"].orEmpty()))
        val j = NativeApi(candidate).post("/c/s/login")
        checkResult(j, true)
        val user = j.obj("user")
        require(user.s("id").isNotEmpty() && user.s("id") != "0") { "登录结果缺少用户信息" }
        return Account(candidate.raw.put("uid", user.s("id")).put("name", user.s("name"))
            .put("nameShow", user.s("name_show")).put("portrait", user.s("portrait"))
            .put("tbs", j.obj("anti").s("tbs")).put("isLogin", true))
    }

    fun threads(j: JSONObject, key: String = "thread_list"): List<ThreadItem> {
        val users = j.rows("user_list").associateBy { it.s("id") }
        return j.rows(key).map { ThreadItem.parse(it, users) }.filter { it.id.isNotEmpty() }
    }

    suspend fun followedForums(): List<Forum> {
        val result = linkedMapOf<String, Forum>()
        for (page in 1..20) {
            val j = post("/c/f/forum/getforumlist", mapOf("uid" to account?.uid.orEmpty(), "pn" to "$page", "rn" to "200"))
            val payload = j.optJSONObject("data")?.takeIf { it.has("forum_info") || it.has("forum_list") } ?: j
            val rows = payload.optJSONArray("forum_info") ?: payload.optJSONArray("forum_list")
            val forums = rows.objects().map(Forum::parse)
            val before = result.size
            forums.filter { it.name.isNotEmpty() }.forEach { result[it.id.ifEmpty { it.name }] = it }
            val more = payload.s("has_more", "hasMore").ifEmpty { payload.obj("page").s("has_more") }.ifEmpty { j.obj("page").s("has_more") }
            if (more in listOf("0", "false") || more.isEmpty() && forums.size < 50) return result.values.toList()
            if (result.size == before) { if (more in listOf("1", "true")) throw ApiFailure("关注列表分页未完成，请刷新后重试"); return result.values.toList() }
        }
        throw ApiFailure("关注列表超过分页上限，无法确认完整列表")
    }

    suspend fun forum(name: String, page: Int, sort: Int = 0, tab: JSONObject? = null, fid: String = ""): JSONObject {
        val args = mutableMapOf("kw" to name, "pn" to "$page", "rn" to "30", "sort_type" to "$sort")
        val id = tab?.s("tab_id", "id").orEmpty()
        val type = tab?.s("tab_type", "type").orEmpty()
        val title = tab?.s("tab_name", "text", "name").orEmpty()
        val good = title.contains("精华") || id == "301" || tab?.flag("is_good") == true
        val general = !good && (type == "15" || (id.toIntOrNull() ?: 0) > 1000)
        if (id.isNotEmpty()) args["tab_id"] = id
        if (type.isNotEmpty()) args["tab_type"] = type
        if (good) args["is_good"] = "1"
        if (general) {
            args["forum_id"] = fid.takeUnless { it.isEmpty() || it == "0" } ?: post("/c/f/frs/page", mapOf("kw" to name, "rn" to "1")).obj("forum").s("id")
            args["tab_name"] = title; args["is_general_tab"] = "1"
        }
        return post(if (general) "/c/f/frs/generalTabList" else "/c/f/frs/page", args)
    }

    suspend fun detail(tid: String, page: Int = 1, lz: Boolean = false, reverse: Boolean = false, pid: String = "") =
        post("/c/f/pb/page", mapOf("kz" to tid, "pn" to "$page", "rn" to "20", "with_floor" to "1", "floor_rn" to "3",
            "lz" to if (lz) "1" else "0", "r" to if (reverse) "1" else "0", "_client_version" to "12.65.1.0", "from" to "baidu_appstore") +
            if (pid.isNotEmpty()) mapOf("pid" to pid) else emptyMap())

    suspend fun write(path: String, values: Map<String, String>): JSONObject {
        val result = post(path, values + ("tbs" to tbs()), check = false)
        checkResult(result, true)
        return result
    }

    suspend fun signForum(name: String, fid: String) {
        val id = fid.takeUnless { it.isEmpty() || it == "0" } ?: forum(name, 1).obj("forum").s("id")
        require(id.isNotEmpty() && id != "0") { "无法获取吧 ID" }
        val result = post("/c/c/forum/sign", mapOf("kw" to name, "fid" to id, "tbs" to tbs()), check = false)
        val top = signComplete(result.s("error_code"), result.s("error_msg"))
        val nested = !result.has("error") || result.optJSONObject("error")?.let { signComplete(it.s("errno"), it.s("errmsg")) } == true
        if (!top || !nested) { checkResult(result, true); throw ApiFailure("未确认签到完成，请刷新查看") }
    }

    suspend fun agree(tid: String, pid: String, enabled: Boolean) {
        val thread = pid.isEmpty() || pid == "0" || pid == tid
        val token = tbs()
        val fields = mapOf("thread_id" to tid, "post_id" to if (thread) "0" else pid, "agree_type" to "2", "obj_type" to if (thread) "3" else "1", "op_type" to if (enabled) "0" else "1")
        var j = post("/c/c/agree/opAgree", fields + ("tbs" to token), false)
        if (j.s("error_code") != "0" && j.s("error_msg").contains("tbs", true)) {
            val fresh = tbs()
            if (fresh != token) j = post("/c/c/agree/opAgree", fields + ("tbs" to fresh), false)
        }
        if (j.obj("error").s("errno", "error_code").let { it.isNotEmpty() && it != "0" }) checkResult(j, true)
        val message = j.s("error_msg")
        if (j.s("error_code") == "0" || enabled && (j.s("error_code") == "340006" || Regex("重复|已点赞|已赞").containsMatchIn(message)) ||
            !enabled && Regex("重复|未点赞|未赞").containsMatchIn(message)) return
        checkResult(j, true)
    }
}

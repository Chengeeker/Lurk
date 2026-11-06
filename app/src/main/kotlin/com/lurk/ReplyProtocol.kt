package com.lurk

import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.ByteArrayOutputStream

// The field numbers mirror the existing reply protocol, independently of the form API.
class ProtoWriter {
    private val out = ByteArrayOutputStream()
    private fun varint(number: Long) {
        var value = number
        while (value and -128L != 0L) { out.write(((value and 127) or 128).toInt()); value = value ushr 7 }
        out.write(value.toInt())
    }
    fun number(field: Int, value: Long) = apply { varint((field shl 3).toLong()); varint(value) }
    fun bytes(field: Int, value: ByteArray) = apply { varint(((field shl 3) or 2).toLong()); varint(value.size.toLong()); out.write(value) }
    fun string(field: Int, value: String) = bytes(field, value.toByteArray())
    fun build() = out.toByteArray()
}

fun readProto(bytes: ByteArray): Map<Int, Any> {
    var offset = 0
    fun varint(): Long {
        var result = 0L
        for (shift in 0..63 step 7) {
            require(offset < bytes.size) { "截断的响应" }
            val b = bytes[offset++].toInt() and 255
            result = result or ((b and 127).toLong() shl shift)
            if (b and 128 == 0) return result
        }
        error("无效的响应整数")
    }
    val fields = mutableMapOf<Int, Any>()
    while (offset < bytes.size) {
        val tag = varint().toInt()
        require(tag ushr 3 > 0)
        when (tag and 7) {
            0 -> fields[tag ushr 3] = varint()
            2 -> {
                val size = varint()
                require(size >= 0 && size <= bytes.size - offset)
                fields[tag ushr 3] = bytes.copyOfRange(offset, offset + size.toInt()); offset += size.toInt()
            }
            1, 5 -> { offset += if (tag and 7 == 1) 8 else 4; require(offset <= bytes.size) }
            else -> error("不支持的响应字段")
        }
    }
    return fields
}

suspend fun NativeApi.reply(tid: String, fid: String, forum: String, text: String, pid: String = "", subPid: String = "", user: Author? = null): String {
    val a = requireNotNull(account) { "请先登录" }
    require(tid.matches(Regex("[0-9]+")) && text.isNotBlank()) { "请输入回复内容" }
    val forumId = fid.takeUnless { it.isEmpty() || it == "0" } ?: this.forum(forum, 1).obj("forum").s("id")
    require(forumId.matches(Regex("[0-9]+")) && forumId != "0" && forum.isNotBlank()) { "无法取得吧信息，请刷新后重试" }
    val tbs = tbs()
    val now = System.currentTimeMillis()
    val clientId = "wappc_${now}_${now % 1000}"
    val common = ProtoWriter().number(1, 2).string(2, "12.35.1.0").string(3, clientId)
        .string(6, "1020031h").string(7, NativeApi.CUID).number(8, now).string(9, "Pixel 7").string(10, a.bduss)
        .string(11, tbs).number(12, 1).string(24, "1.0.3").string(26, "Google").string(28, "3.0.0")
        .string(30, a.stoken).string(32, NativeApi.CUID).string(42, "2.34.0").string(43, "3340042")
        .number(55, 1).number(57, 1).number(63, 1).build()
    val content = if (subPid.isNotEmpty() && user != null && user.portrait.isNotEmpty()) "回复 #(reply, ${user.portrait}, ${user.name}) :$text" else text
    val data = ProtoWriter().bytes(1, common).string(4, tbs).string(6, "1").string(7, "0").string(8, "0")
        .string(9, "0").string(10, "0").string(16, "12").string(18, "1").string(19, content).string(26, forumId)
        .string(30, forum.removeSuffix("吧").trim()).string(31, "0").string(45, tid).string(47, "0").string(48, "0")
        .string(51, "0").string(52, "0").string(53, "0").string(58, a.name).string(60, "0").number(64, 0).number(67, 0)
    if (pid.isEmpty()) data.string(55, "13").string(32, "0").string(28, "").string(29, "")
    else {
        data.string(46, pid).string(49, pid)
        if (subPid.isEmpty()) data.string(55, "0") else data.string(50, subPid)
        if (!user?.id.isNullOrEmpty()) data.string(20, user!!.id)
    }
    val fields = linkedMapOf("BDUSS" to a.bduss, "_client_id" to clientId, "_client_type" to "2", "_client_version" to "12.35.1.0",
        "_timestamp" to "$now", "active_timestamp" to "0", "android_id" to "000", "brand" to "Google", "cmode" to "1",
        "cuid" to NativeApi.CUID, "cuid_galaxy2" to NativeApi.CUID, "cuid_gid" to "", "device_score" to "0",
        "event_day" to java.text.SimpleDateFormat("yyyyMd", java.util.Locale.US).format(java.util.Date()), "extra" to "",
        "first_install_time" to "0", "framework_ver" to "3340042", "from" to "tieba", "is_teenager" to "0", "last_update_time" to "0",
        "model" to "Pixel 7", "net_type" to "1", "oaid" to "{}", "personalized_rec_switch" to "1", "sample_id" to "",
        "sdk_ver" to "2.34.0", "start_scheme" to "", "start_type" to "1", "stoken" to a.stoken, "tbs" to tbs, "z_id" to "")
    fields["sign"] = sign(fields)
    val form = MultipartBody.Builder().setType(MultipartBody.FORM).apply {
        fields.forEach { (k, v) -> addFormDataPart(k, v) }
        addFormDataPart("data", "file", ProtoWriter().bytes(1, data.build()).build().toRequestBody())
    }.build()
    val result = bytes(request("https://tiebac.baidu.com/c/c/post/add?cmd=309731&format=protobuf")
        .header("x_bd_data_type", "protobuf").header("User-Agent", "bdtb for Android 12.35.1.0").post(form).build())
    if (result.toString(Charsets.UTF_8).trimStart().startsWith("{")) {
        val j = JSONObject(result.toString(Charsets.UTF_8)); checkResult(j, true)
        return j.s("pid").ifEmpty { j.obj("data").s("pid") }
    }
    val response = readProto(result)
    require(response.containsKey(1) || response.containsKey(2)) { "无法确认发表结果，请刷新后核对" }
    val error = (response[1] as? ByteArray)?.let(::readProto).orEmpty()
    val code = error[1] as? Long ?: 0
    if (code != 0L) throw ApiFailure(((error[3] ?: error[2]) as? ByteArray)?.toString(Charsets.UTF_8) ?: "发表失败（$code）")
    return ((response[2] as? ByteArray)?.let(::readProto)?.get(3) as? ByteArray)?.toString(Charsets.UTF_8).orEmpty()
}

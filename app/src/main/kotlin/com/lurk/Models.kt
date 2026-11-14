package com.lurk

import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.net.URLDecoder
import java.security.MessageDigest

fun JSONObject.s(vararg keys: String): String = keys.firstNotNullOfOrNull { key ->
    opt(key)?.takeUnless { it == JSONObject.NULL || it.toString().isEmpty() }?.toString()
} ?: ""
fun JSONObject.obj(key: String) = optJSONObject(key) ?: JSONObject()
fun JSONObject.rows(key: String) = optJSONArray(key).objects()
fun JSONArray?.objects(): List<JSONObject> = if (this == null) emptyList() else
    (0 until length()).mapNotNull { optJSONObject(it) }
fun JSONArray?.strings(): List<String> = if (this == null) emptyList() else
    (0 until length()).map { getString(it) }
fun JSONObject.flag(key: String) = s(key) in listOf("1", "true")
fun JSONObject.removeSnippet(): JSONObject { remove("snippetSegments"); remove("snippet_segments"); return this }
fun md5(bytes: ByteArray) = MessageDigest.getInstance("MD5").digest(bytes).joinToString("") { "%02x".format(it) }
fun sign(params: Map<String, String>) = md5((params.toSortedMap().entries.joinToString("") { "${it.key}=${it.value}" } + "tiebaclient!!!").toByteArray())

internal fun firstPostId(detail: JSONObject): String = detail.obj("thread").s("post_id").takeUnless { it.isEmpty() || it == "0" }
    ?: detail.rows("post_list").firstOrNull { it.s("floor") == "1" }?.s("id")?.takeUnless { it.isEmpty() || it == "0" }.orEmpty()

data class Account(val raw: JSONObject) {
    val uid get() = raw.s("uid")
    val name get() = raw.s("nameShow", "name").ifEmpty { "用户" }
    val bduss get() = raw.s("bduss")
    val stoken get() = raw.s("stoken")
    val cookie get() = "ka=open; BDUSS=$bduss; STOKEN=$stoken; BAIDUID=${raw.s("baiduid")}" 
}

data class Author(val id: String = "", val name: String = "贴吧吧友", val portrait: String = "", val level: String = "", val ip: String = "") {
    companion object {
        fun parse(raw: JSONObject, users: Map<String, JSONObject> = emptyMap(), fallbackId: String = ""): Author {
            val id = raw.s("id", "author_id", "user_id", "lz_uid").takeUnless { it.isEmpty() || it == "0" } ?: fallbackId
            val detail = users[id] ?: JSONObject()
            var name = raw.s("name_show", "nameShow", "show_nickname", "nick_name").ifEmpty { detail.s("name_show", "show_nickname") }
            val head = (raw.optJSONObject("user_show_info") ?: detail.obj("user_show_info")).obj("feed_head")
            head.rows("main_data").filter { it.s("type") == "1" }.forEach { item ->
                val label = item.obj("text").s("text")
                if (label.isNotEmpty() && (name.isEmpty() || name.startsWith("贴吧用户_"))) name = label
            }
            (raw.optJSONArray("show_icon_list") ?: detail.optJSONArray("show_icon_list")).objects().forEach { icon ->
                if (icon.s("type") == "name_show" && icon.s("text").isNotEmpty() && (name.isEmpty() || name.startsWith("贴吧用户_"))) name = icon.s("text")
            }
            val ipKeys = arrayOf("ip_address", "ipAddress", "ip", "location", "user_location", "province", "ip_sync")
            val ip = raw.s(*ipKeys).ifEmpty { detail.s(*ipKeys) }.ifEmpty { raw.obj("ala_info").s("location") }.ifEmpty { detail.obj("ala_info").s("location") }.replace("来自", "").trim().takeUnless { it == "0" || it.equals("null", true) }.orEmpty()
            return Author(id, name.ifEmpty { raw.s("name", "user_name", "author_name").ifEmpty { detail.s("name") } }.ifEmpty { "贴吧吧友" },
                raw.s("portrait", "user_portrait", "portraith", "icon", "avatar").ifEmpty { detail.s("portrait", "user_portrait", "portraith") }.ifEmpty { head.obj("image_data").s("img_url") },
                raw.s("level_id", "user_level", "level").ifEmpty { detail.s("level_id", "user_level") }, ip)
        }
    }
}

fun portraitUrl(value: String) = if (value.startsWith("http")) value else
    "https://gss0.bdstatic.com/7Ls0a8Sm1A5BphGlnYG/sys/portrait/item/${value.ifEmpty { "default.jpg" }}"

data class Media(val original: String, val thumbnail: String = original, val video: String = "", val width: Int = 0, val height: Int = 0, val folderName: String = "", val threadId: String = "", val title: String = "", val isVideo: Boolean = video.isNotEmpty(), val videoId: String = "", val fromThreadPreview: Boolean = false) {
    fun json() = JSONObject().put("origin_pic", original).put("cdn_src", thumbnail).put("video_url", video).put("width", width).put("height", height).put("type", if (isVideo) "5" else "3").put("video_id", videoId)
    companion object {
        fun parse(j: JSONObject): Media {
            val markedVideo = j.s("type") in listOf("5", "video") || j.has("video_duration") || j.has("video_length")
            val video = listOf("vhsrc", "video_url", "videoUrl", "play_url", "vurl", "video_res_url")
                .firstNotNullOfOrNull { key -> videoStreamUrl(j.s(key)).takeIf(String::isNotEmpty) }
                ?: listOf("link", "url", "src").firstNotNullOfOrNull { key ->
                    videoStreamUrl(j.s(key)).takeIf { it.isNotEmpty() && (markedVideo && key != "src" || mediaPath(it).substringAfterLast('.') in videoExtensions) }
                }.orEmpty()
            val isVideo = markedVideo || video.isNotEmpty()
            fun picture(vararg keys: String) = keys.firstNotNullOfOrNull { key ->
                j.s(key).takeIf { it.isNotEmpty() && mediaPath(it).substringAfterLast('.') !in nonPictureExtensions && (!isVideo || video.isEmpty() || targetUrl(it) != video) }
            }.orEmpty()
            val original = picture("origin_pic", "origin_src", "origin_url", "originUrl", "vpic", "big_pic", "big_cdn_src", "bigCdnUrl", "src_pic", "src", "thumbnail", "thumbnail_url", "first_frame_thumbnail", "cover_url", "url")
            val size = j.s("bsize").split(',')
            return Media(original, picture("cdn_src", "thumbUrl", "src_pic", "small_pic", "small_src", "smallPic", "small_thumbnail_url", "big_pic", "thumbnail", "thumbnail_url", "vpic", "cover_url").ifEmpty { original }, video,
                size.firstOrNull()?.toIntOrNull() ?: j.s("width", "video_width").toIntOrNull() ?: 0,
                size.getOrNull(1)?.toIntOrNull() ?: j.s("height", "video_height").toIntOrNull() ?: 0,
                isVideo = isVideo, videoId = if (isVideo) j.s("video_id", "vid").takeUnless { it == "0" }.orEmpty() else "")
        }
    }
}

private val videoExtensions = setOf("mp4", "m3u8", "flv", "webm", "mov", "m4v", "mpd")
private val nonPictureExtensions = videoExtensions + "swf"
private val nonVideoExtensions = setOf("jpg", "jpeg", "png", "gif", "webp", "avif", "bmp", "swf", "html", "htm")
private fun mediaPath(url: String) = url.substringBefore('?').substringBefore('#').lowercase()

internal fun videoStreamUrl(value: String): String {
    val url = targetUrl(value)
    if (url.isEmpty() || mediaPath(url).substringAfterLast('.') in nonVideoExtensions) return ""
    val host = URI(url).host.lowercase()
    if (host == "b23.tv" || host == "bilibili.com" || host.endsWith(".bilibili.com") ||
        isNativeHost(host) && nativeLink(url)?.first == "thread") return ""
    return url
}

private fun differentVideoIds(a: Media, b: Media) = a.videoId.isNotEmpty() && b.videoId.isNotEmpty() && a.videoId != b.videoId

private val tiebaPosterHosts = setOf("tiebapic.baidu.com", "imgsa.baidu.com", "imgsrc.baidu.com")
private val tiebaPosterHash = Regex("[a-fA-F0-9]{24,64}")
private fun coverKey(url: String): String {
    val path = url.substringAfter("://").removePrefix("//").substringBefore('?').substringBefore('#')
    if (path.substringBefore('/').lowercase() in tiebaPosterHosts) {
        val hash = path.substringAfterLast('/').substringBeforeLast('.')
        if (tiebaPosterHash.matches(hash)) return hash.lowercase()
    }
    return path
}

private fun sameVideo(a: Media, b: Media): Boolean {
    if (differentVideoIds(a, b)) return false
    if (a.videoId.isNotEmpty() && a.videoId == b.videoId || a.video.isNotEmpty() && a.video == b.video) return true
    val aCovers = listOf(coverKey(a.original), coverKey(a.thumbnail))
    return listOf(coverKey(b.original), coverKey(b.thumbnail)).any { it.isNotEmpty() && it in aCovers }
}

private fun mergeVideo(a: Media, b: Media, preferSecond: Boolean = false): Media = a.copy(
    original = a.original.ifEmpty { b.original },
    thumbnail = a.thumbnail.ifEmpty { b.thumbnail },
    video = if (preferSecond) b.video.ifEmpty { a.video } else a.video.ifEmpty { b.video },
    width = a.width.takeIf { it > 0 } ?: b.width,
    height = a.height.takeIf { it > 0 } ?: b.height,
    videoId = a.videoId.ifEmpty { b.videoId },
)

internal fun distinctPostMedia(items: List<Media>): List<Media> {
    val result = mutableListOf<Media>()
    val images = mutableSetOf<String>()
    for (item in items) {
        if (item.isVideo) {
            if (item.original.isEmpty() && item.video.isEmpty() && item.videoId.isEmpty()) continue
            val match = result.indexOfFirst { it.isVideo && sameVideo(it, item) }
            if (match >= 0) result[match] = mergeVideo(result[match], item)
            else result.add(item)
        } else if (item.original.isNotEmpty() && images.add(item.original)) result.add(item)
    }
    return result
}

private fun threadVideoSummary(thread: JSONObject): Media? {
    val raw = thread.optJSONObject("video_info") ?: thread.optJSONObject("video")
        ?: JSONObject().put("video_url", thread.s("video").ifEmpty { return null })
    return Media.parse(JSONObject(raw.toString()).put("type", "video"))
        .takeIf { it.video.isNotEmpty() || it.original.isNotEmpty() || it.videoId.isNotEmpty() }
}

internal fun detailVideoUrl(detail: JSONObject, selected: Media, failedUrl: String, allowSoleVideo: Boolean): String {
    val posts = detail.rows("post_list")
    val first = posts.firstOrNull { it.s("floor") == "1" } ?: posts.firstOrNull()?.takeIf { it.s("floor").isEmpty() }
    val body = parseContent(first?.opt("content")).mapNotNull { it.media }.filter { it.isVideo }
    val summary = threadVideoSummary(detail.obj("thread"))
    val candidates = (body + listOfNotNull(summary)).filter { it.video.isNotEmpty() && it.video != failedUrl }
    return candidates.firstOrNull { sameVideo(selected, it) }?.video
        ?: if (allowSoleVideo && distinctPostMedia(body).size <= 1)
            candidates.firstOrNull { !differentVideoIds(selected, it) }?.video.orEmpty()
        else ""
}

data class Segment(val text: String, val link: String = "", val media: Media? = null, val emoji: String = "", val userId: String = "")
fun parseContent(raw: Any?): List<Segment> = when (raw) {
    is JSONArray -> (0 until raw.length()).flatMap { index ->
        val j = raw.optJSONObject(index) ?: return@flatMap parseContent(raw.opt(index))
        listOf(
        when (j.s("type")) {
            "3", "5" -> Segment("", media = Media.parse(j))
            "1" -> { val url = targetUrl(j.s("link", "url")); Segment(url.ifEmpty { j.s("text") }, url) }
            "2" -> Segment(j.s("c", "text").ifEmpty { "[表情]" }, emoji = emojiUrl(j.s("text"), j.s("c"), j.s("cdn_src", "src")))
            "4" -> Segment(j.s("text"), userId = j.s("uid", "user_id"))
            else -> Segment(j.s("text", "content"))
        })
    }
    is String -> listOf(Segment(raw))
    else -> emptyList()
}

data class ThreadItem(
    val id: String, val title: String, val author: Author, val forum: String,
    val segments: List<Segment>, val media: List<Media>, val replies: String,
    val agrees: String, val agreed: Boolean, val postId: String, val raw: JSONObject,
) {
    companion object {
        fun parse(j: JSONObject, users: Map<String, JSONObject> = emptyMap()): ThreadItem {
            val author = Author.parse(j.optJSONObject("author") ?: j.optJSONObject("user") ?: JSONObject(j.toString()).put("id", j.s("author_id", "user_id")).put("name", j.s("author_name", "author", "name")), users, j.s("author_id", "user_id"))
            val content = listOf("first_post_content", "abstract", "content", "content_snippet", "contentSnippet").firstNotNullOfOrNull { key -> j.opt(key)?.takeUnless { it == JSONObject.NULL || it is JSONArray && it.length() == 0 || it is String && it.isEmpty() } }
            val segments = if (j.has("snippetSegments") || j.has("snippet_segments")) (j.rows("snippetSegments") + j.rows("snippet_segments")).map {
                val url = targetUrl(it.s("url", "link")); Segment(url.ifEmpty { it.s("text") }, url)
            } else parseContent(content)
            val media = distinctPostMedia((j.rows("media") + j.rows("mediaList") + j.rows("pic_list")).map(Media::parse) + segments.mapNotNull { it.media }).toMutableList()
            val summary = threadVideoSummary(j)
            if (summary != null) {
                val videos = media.indices.filter { media[it].isVideo }
                val match = videos.firstOrNull { sameVideo(media[it], summary) }
                    ?: videos.singleOrNull()?.takeIf { !differentVideoIds(media[it], summary) }
                if (match != null) media[match] = mergeVideo(media[match], summary, preferSecond = true)
                else if (videos.isEmpty()) media.add(summary)
            }
            val stored = JSONObject(j.toString()).put("author", JSONObject().put("id", author.id).put("name_show", author.name).put("portrait", author.portrait).put("level_id", author.level).put("ip_address", author.ip))
            return ThreadItem(j.s("tid", "thread_id", "id"), j.s("title", "thread_title"), author,
                j.s("fname", "forum_name", "forumName").ifEmpty { j.obj("forum").s("name") }, segments,
                media,
                j.s("reply_num", "count", "replyCount", "reply_count"), j.obj("agree").s("agree_num", "diff_agree_num").ifEmpty { j.s("agree_num", "agreeCount") },
                j.obj("agree").flag("has_agree") || j.flag("isAgree") || j.flag("is_agree") || j.flag("has_agree"), j.s("post_id", "pid", "postId", "first_post_id").ifEmpty { j.obj("first_post").s("id") }, stored)
        }
    }
}

data class Forum(val id: String, val name: String, val level: Int, val signed: Boolean, val raw: JSONObject) {
    companion object {
        fun parse(j: JSONObject) = Forum(j.s("id", "forum_id", "fid"), j.s("name", "forum_name"),
            j.s("level_id", "user_level", "level").toIntOrNull() ?: j.obj("user_info").optInt("user_level"),
            j.flag("is_sign") || j.flag("is_sign_in") || j.flag("is_signed") || j.obj("sign_in_info").obj("user_info").flag("is_sign_in"), j)
    }
}

fun targetUrl(input: String): String {
    var value = input.trim()
    if (value.startsWith("//")) value = "https:$value"
    if (value.startsWith("/mo/q/checkurl")) value = "https://tieba.baidu.com$value"
    repeat(3) {
        val uri = runCatching { URI(value) }.getOrNull() ?: return ""
        if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrEmpty()) return ""
        if (isNativeHost(uri.host) && uri.path == "/mo/q/checkurl") {
            val wrapped = uri.rawQuery?.split('&')?.firstOrNull { it.startsWith("url=") }?.substringAfter('=')
            if (wrapped != null) {
                value = runCatching { URLDecoder.decode(wrapped, "UTF-8") }.getOrDefault("")
            } else return value
        } else return value
    }
    return ""
}

fun isNativeHost(host: String?) = host?.lowercase()?.let { it == "tieba.baidu.com" || it.endsWith(".tieba.baidu.com") || it == "tiebac.baidu.com" || it.endsWith(".tiebac.baidu.com") } == true
fun nativeLink(raw: String): Pair<String, String>? {
    val uri = runCatching { URI(targetUrl(raw)) }.getOrNull() ?: return null
    if (!isNativeHost(uri.host)) return null
    Regex("^/p/([0-9]+)(?:/|$)").find(uri.path.orEmpty())?.let { return "thread" to it.groupValues[1] }
    val query = uri.rawQuery.orEmpty().split('&').associate { part ->
        val key = runCatching { URLDecoder.decode(part.substringBefore('='), "UTF-8") }.getOrDefault("")
        key to runCatching { URLDecoder.decode(part.substringAfter('=', ""), "UTF-8") }.getOrDefault("")
    }
    (query["kz"] ?: query["tid"])?.takeIf { it.matches(Regex("[0-9]+")) }?.let { return "thread" to it }
    return query["kw"]?.takeIf(String::isNotEmpty)?.let { "forum" to it }
}

fun signComplete(code: String, message: String): Boolean {
    val number = code.toIntOrNull() ?: return false
    if (number == 0) return true
    if (Regex("未签到|没签到|未完成|没有签到|失败|部分|剩余|权限|限制|不支持|稍后|重试").containsMatchIn(message)) return false
    return Regex("(?:已(?:经)?(?:全部|完成(?:今日|今天)?的?)?(?:一键)?签到|已(?:经)?签过到)(?:过了?|了)?(?:[，,。！!～~\\s]|$)|重复(?:一键)?签到").containsMatchIn(message)
}

fun validatedAccounts(raw: JSONArray, active: String): List<Account> {
    val accounts = raw.strings().map { text ->
        val j = JSONObject(text)
        require(j.opt("uid") is String && j.s("uid").isNotEmpty() && j.opt("bduss") is String) { "无效的备份账号" }
        listOf("name", "nameShow", "portrait", "stoken", "baiduid", "tbs").forEach {
            require(!j.has(it) || j.opt(it) is String) { "无效的账号字段" }
        }
        require(!j.has("isLogin") || j.opt("isLogin") is Boolean)
        Account(j)
    }
    require(accounts.map { it.uid }.distinct().size == accounts.size) { "重复的账号" }
    require(if (accounts.isEmpty()) active.isEmpty() else accounts.any { it.uid == active }) { "当前账号不匹配" }
    return accounts
}

fun batchTargets(forums: List<Forum>) = forums.filter { it.level >= 7 }.ifEmpty { forums }
fun verifyBatchSigns(before: List<Forum>, after: List<Forum>): Boolean {
    val expected = batchTargets(before)
    val targets = batchTargets(after)
    if (expected.isEmpty() || targets.isEmpty()) return false
    val names = after.associateBy { it.name }
    return expected.all { it.name.isNotEmpty() && names[it.name]?.signed == true } && targets.all { it.signed }
}

fun mediaMime(declared: String, prefix: ByteArray, video: Boolean): String {
    if (declared.startsWith(if (video) "video/" else "image/")) return declared
    if (declared.isNotEmpty() && declared != "application/octet-stream") return ""
    val text = prefix.toString(Charsets.ISO_8859_1)
    return when {
        video && text.length >= 8 && text.substring(4, 8) == "ftyp" -> "video/mp4"
        video && text.startsWith("FLV") -> "video/x-flv"
        !video && prefix.take(3).map { it.toInt() and 255 } == listOf(255, 216, 255) -> "image/jpeg"
        !video && text.startsWith("\u0089PNG") -> "image/png"
        !video && text.startsWith("GIF8") -> "image/gif"
        !video && text.startsWith("RIFF") && text.length >= 12 && text.substring(8, 12) == "WEBP" -> "image/webp"
        else -> ""
    }
}

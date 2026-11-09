package com.lurk

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class ProtocolTest {
    @Test fun postOwnershipRequiresIdentityRatherThanMatchingDisplayNames() {
        val account = Account(JSONObject().put("uid", "1").put("name", "同名用户").put("portrait", "owner"))
        assertFalse(ownsPost(account, Author("2", "同名用户", "other")))
        assertFalse(ownsPost(account, Author("0", "同名用户")))
        assertTrue(ownsPost(account, Author("1", "更改后的昵称")))
        assertTrue(ownsPost(account, Author("", "其他昵称", "owner")))
        assertFalse(ownsPost(null, Author("1", "同名用户", "owner")))
    }
    @Test fun cardMergesVideoVariantsAndSummaryButKeepsDistinctVideoIds() {
        val thread = JSONObject("""{
            "id":"11171161623",
            "media":[
              {"type":5,"vsrc":"https://tieba.baidu.com/mo/q/movideo/page","vhsrc":"https://cdn.example.com/high.mp4","vpic":"https://tiebapic.baidu.com/forum/pic/item/0123456789abcdef0123456789abcdef.jpg?a"},
              {"type":5,"vsrc":"https://tieba.baidu.com/mo/q/movideo/page","vhsrc":"https://cdn.example.com/low.mp4","vpic":"https://tiebapic.baidu.com/forum/w=640/sign=test/0123456789abcdef0123456789abcdef.jpg?b"}
            ],
            "video_info":{"thumbnail_url":"https://img.example.com/poster.jpg","video_url":"https://cdn.example.com/main.mp4","video_width":1920,"video_height":1080}
        }""")
        val video = ThreadItem.parse(thread).media.single()
        assertTrue(video.isVideo)
        assertEquals("https://tiebapic.baidu.com/forum/pic/item/0123456789abcdef0123456789abcdef.jpg?a", video.original)
        assertEquals("https://cdn.example.com/main.mp4", video.video)
        assertEquals(1920, video.width)
        assertEquals(2, distinctPostMedia(listOf(video.copy(videoId = "a"), video.copy(videoId = "b"))).size)
        assertEquals("b", Media.parse(video.copy(videoId = "b").json()).videoId)
    }

    @Test fun detailRecoveryUsesFirstPostAndSkipsTheFailedAddressAndUnrelatedReplies() {
        val detail = JSONObject("""{
            "thread":{"video_info":{"video_url":"https://cdn.example.com/failed.mp4"}},
            "post_list":[
              {"floor":1,"content":[{"type":5,"src":"https://img.example.com/new.jpg","link":"https://cdn.example.com/actual.mp4"}]},
              {"floor":2,"content":[{"type":5,"src":"https://img.example.com/other.jpg","link":"https://cdn.example.com/other.mp4"}]}
            ]
        }""")
        val selected = Media("https://img.example.com/old.jpg", video = "https://cdn.example.com/failed.mp4")
        assertEquals("https://cdn.example.com/actual.mp4", detailVideoUrl(detail, selected, selected.video, true))
        assertEquals("", detailVideoUrl(detail, selected, selected.video, false))
        assertEquals("", videoStreamUrl("https://cdn.example.com/flash.swf?ver=1"))
        assertEquals("", videoStreamUrl("https://b23.tv/example"))
    }

    @Test fun nativeLinksKeepOwnershipAndSupportParameterRoutes() {
        assertEquals("thread" to "123", nativeLink("https://c.tieba.baidu.com/p/123/?q=1"))
        assertEquals("thread" to "124", nativeLink("https://tiebac.baidu.com/mo/q/m?kz=124#reply"))
        assertEquals("forum" to "中文", nativeLink("https://tieba.baidu.com/f?kw=%E4%B8%AD%E6%96%87"))
        assertNull(nativeLink("https://tieba.baidu.com.attacker.test/p/123"))
        assertNull(nativeLink("https://tieba.baidu.com/p/not-a-number"))
        assertEquals("thread" to "125", nativeLink("https://sub.tieba.baidu.com/mo/q/checkurl?url=https%3A%2F%2Ftieba.baidu.com%2Fp%2F125"))
    }
    @Test fun mixedContentRetainsStringsAndLinksInOrder() {
        val parsed = parseContent(JSONArray("""["前文",{"type":1,"link":"https://example.com/?a=1#b"},"后文"]"""))
        assertEquals(listOf("前文", "https://example.com/?a=1#b", "后文"), parsed.map { it.text })
    }
    @Test fun batchVerificationRequiresNonemptyCompleteCoverage() {
        fun forum(name: String, level: Int, signed: Boolean) = Forum(name, name, level, signed, JSONObject())
        val high = forum("A", 7, false); val low = forum("B", 6, false)
        assertEquals(listOf(high), batchTargets(listOf(high, low)))
        assertEquals(listOf(low), batchTargets(listOf(low)))
        assertFalse(verifyBatchSigns(emptyList(), emptyList()))
        assertFalse(verifyBatchSigns(listOf(high), listOf(low.copy(signed = true))))
        assertTrue(verifyBatchSigns(listOf(high, low), listOf(high.copy(signed = true), low)))
        assertFalse(verifyBatchSigns(listOf(high), listOf(high.copy(signed = true), forum("C", 8, false))))
        assertTrue(verifyBatchSigns(listOf(low), listOf(low.copy(signed = true))))
        assertFalse(verifyBatchSigns(listOf(low), listOf(low)))
    }
    @Test fun htmlKeepsBreaksEntitiesAndEmojiButDropsScripts() {
        assertEquals("A&B\n[滑稽]\n中", plainText("<p>A&amp;B</p><img src='image_emoticon25.png'><br>&#x4e2d;<script>bad()</script>"))
        assertEquals("a < b", plainText("a &lt; b"))
        assertEquals("https://tb2.bdstatic.com/tb/editor/images/client/image_emoticon25.png", emojiUrl("", "[滑稽]"))
    }
    @Test fun authorsUseFeedHeadAndKeepResolvedIdentityInSavedData() {
        val author = JSONObject("""{"id":"2","name_show":"贴吧用户_2","user_show_info":{"feed_head":{"image_data":{"img_url":"https://example.com/avatar.jpg"},"main_data":[{"type":1,"text":{"text":"实际昵称"}}]}}} """)
        val item = ThreadItem.parse(JSONObject().put("id", "5").put("author_id", "2"), mapOf("2" to author))
        assertEquals("实际昵称", item.author.name)
        assertEquals(item.author, ThreadItem.parse(item.raw).author)
    }
    @Test fun malformedFlashCoverIsNotAnImageAndMediaDeduplicatesBySource() {
        assertEquals("https://example.com/cover.jpg", Media.parse(JSONObject().put("origin_src", "https://example.com/video.swf").put("vpic", "https://example.com/cover.jpg")).original)
        val item = ThreadItem.parse(JSONObject("""{"id":"1","media":[{"origin_src":"https://example.com/a.jpg"}],"content":[{"type":3,"origin_src":"https://example.com/a.jpg","width":10}]}"""))
        assertEquals(1, item.media.size)
    }
    @Test fun forumRulesExtractNestedTextWithoutExposingRawJson() {
        val rows = forumRules(JSONObject("""{"new_rules":[{"title":"规则","content":[{"text":"一","children":[{"content":"二"}]},"一"]}]}"""))
        assertEquals(listOf("一", "二"), rows.single().contents)
        assertEquals("规则", rows.single().title)
    }
    @Test fun cacheTraversalCannotDeleteOutsideRoot() {
        val root = java.nio.file.Files.createTempDirectory("lurk-cache-test").toFile()
        try {
            val child = java.io.File(root, "cache").apply { mkdir() }
            val outside = java.io.File(root, "keep.txt").apply { writeText("user data") }
            java.io.File(child, "old.tmp").writeText("cache")
            visitCache(child, delete = true)
            assertTrue(outside.exists())
            assertTrue(child.listFiles().isNullOrEmpty())
        } finally { root.deleteRecursively() }
    }
    @Test fun signingSortsFieldsAndKeepsUnicode() {
        assertEquals(sign(linkedMapOf("z" to "中文", "a" to "a=b")), sign(linkedMapOf("a" to "a=b", "z" to "中文")))
        assertEquals("d41d8cd98f00b204e9800998ecf8427e", md5(byteArrayOf()))
    }
    @Test fun linksKeepFullQueryAndOnlyUnwrapOwnedHost() {
        val url = "https://example.com/a?q=one%20two&x=1#part"
        assertEquals(url, targetUrl(url))
        assertEquals(url, targetUrl("https://tieba.baidu.com/mo/q/checkurl?url=" + java.net.URLEncoder.encode(url, "UTF-8")))
        val untrusted = "https://tieba.baidu.com.evil.example/mo/q/checkurl?url=https%3A%2F%2Fexample.com"
        assertEquals(untrusted, targetUrl(untrusted))
        assertEquals("", targetUrl("javascript:alert(1)"))
        assertEquals("", targetUrl("https://tieba.baidu.com/mo/q/checkurl?url=javascript%3Aalert(1)"))
    }
    @Test fun signCompletionDoesNotTurnPartialFailuresIntoSuccess() {
        assertTrue(signComplete("0", ""))
        assertTrue(signComplete("7", "已经签到"))
        assertTrue(signComplete("7", "已完成签到！"))
        listOf("部分已签到", "已签到 3 个，剩余未完成", "没有签到权限", "稍后重试", "普通错误").forEach { assertFalse(signComplete("7", it)) }
        assertFalse(signComplete("", "已签到"))
    }
    @Test fun followedForumRecognizesEveryExistingSignedField() {
        listOf("is_sign_in", "is_sign", "is_signed").forEach { field -> assertTrue(Forum.parse(JSONObject().put(field, "1")).signed) }
        assertEquals(9, Forum.parse(JSONObject().put("user_level", "9")).level)
    }
    @Test fun backupAllowlistExcludesCredentialsAndUnknownPerAccountKeys() {
        assertTrue(BackupSchema.allowed("key_bookmarks_list_123"))
        assertFalse(BackupSchema.allowed("key_bookmarks_list_../account"))
        listOf("key_accounts_list", "key_webdav_password", "unknown_token").forEach { assertFalse(BackupSchema.allowed(it)) }
        val safe = JSONObject().put("app", "Lurk").put("version", "2.0").put("backup_mode", "safe")
            .put("preferences", JSONObject().put("key_accounts_list", "injected").put("key_enable_haptics", true))
        BackupSchema.validate(safe)
    }
    @Test fun malformedBackupFailsBeforeAnyWrite() {
        val safe = JSONObject().put("app", "Lurk").put("version", "2.0").put("backup_mode", "safe")
            .put("preferences", JSONObject().put("key_enable_haptics", "true"))
        assertThrows(IllegalArgumentException::class.java) { BackupSchema.validate(safe) }
        safe.put("backup_mode", "full").put("preferences", JSONObject())
        assertThrows(IllegalArgumentException::class.java) { BackupSchema.validate(safe) }
    }
    @Test fun accountValidationRejectsDuplicatesAndMismatchedActive() {
        val account = JSONObject().put("uid", "one").put("bduss", "fixture").toString()
        assertEquals("one", validatedAccounts(JSONArray().put(account), "one").single().uid)
        assertThrows(IllegalArgumentException::class.java) { validatedAccounts(JSONArray().put(account).put(account), "one") }
        assertThrows(IllegalArgumentException::class.java) { validatedAccounts(JSONArray().put(account), "two") }
    }
    @Test fun protocolRoundTripKeepsLargeIdsAndChineseText() {
        val bytes = ProtoWriter().number(1, 999999999999L).string(2, "中文回复").bytes(3, ProtoWriter().number(1, 0).build()).build()
        val decoded = readProto(bytes)
        assertEquals(999999999999L, decoded[1])
        assertEquals("中文回复", (decoded[2] as ByteArray).toString(Charsets.UTF_8))
        assertEquals(0L, readProto(decoded[3] as ByteArray)[1])
    }
    @Test fun truncatedProtocolIsRejected() {
        assertThrows(IllegalArgumentException::class.java) { readProto(byteArrayOf(18, 6, 1)) }
        assertThrows(IllegalArgumentException::class.java) { readProto(byteArrayOf(8, 128.toByte())) }
    }
    @Test fun flutterSavedThreadRetainsLinksMediaAndReplyTarget() {
        val raw = JSONObject("""{"id":"42","title":"title","fname":"forum","first_post_id":"43","content":[{"type":1,"text":"网页链接","link":"https://example.com/path?q=1#part"}],"media":[{"origin_src":"https://example.com/full.jpg","cdn_src":"https://example.com/thumb.jpg","bsize":"600,800"}]}""")
        val item = ThreadItem.parse(JSONObject(raw.toString()))
        assertEquals("43", item.postId)
        assertEquals("https://example.com/path?q=1#part", item.segments.single().text)
        assertEquals("https://example.com/thumb.jpg", item.media.single().thumbnail)
        assertEquals(600, item.media.single().width)
    }
    @Test fun unresolvedVideoKeepsItsKindThroughHistory() {
        val media = Media.parse(JSONObject("""{"type":5,"vpic":"https://example.com/cover.jpg","video_url":""}"""))
        assertTrue(media.isVideo)
        assertEquals("", media.video)
        val restored = Media.parse(JSONObject(media.json().toString()))
        assertTrue(restored.isVideo)
        assertEquals(media.original, restored.original)
        assertFalse(Media.parse(JSONObject("""{"type":3,"src":"https://example.com/photo.jpg"}""")).isVideo)
    }
    @Test fun binaryMediaRequiresRecognizedSignature() {
        assertEquals("video/mp4", mediaMime("application/octet-stream", byteArrayOf(0, 0, 0, 20) + "ftypisom".toByteArray(), true))
        assertEquals("image/jpeg", mediaMime("", byteArrayOf(255.toByte(), 216.toByte(), 255.toByte()), false))
        assertEquals("", mediaMime("application/octet-stream", "<html>error</html>".toByteArray(), true))
        assertEquals("", mediaMime("text/html", "GIF89a".toByteArray(), false))
    }
}


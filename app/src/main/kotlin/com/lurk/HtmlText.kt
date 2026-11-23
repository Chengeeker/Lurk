package com.lurk

internal fun expandHtmlImages(segments: List<Segment>): List<Segment> = segments.flatMap { segment ->
    if (segment.media != null || segment.link.isNotEmpty() || segment.emoji.isNotEmpty() || segment.userId.isNotEmpty()) return@flatMap listOf(segment)
    val input = segment.text.replace(Regex("<(script|style)\\b[^>]*>.*?</\\1\\s*>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL)), "")
    val imageTags = Regex("<img\\b[^>]*>", RegexOption.IGNORE_CASE)
    val attributes = Regex("\\b(data-original|data-src|src)\\s*=\\s*[\"']([^\"']*)[\"']", RegexOption.IGNORE_CASE)
    val result = mutableListOf<Segment>()
    var start = 0
    imageTags.findAll(input).forEach { match ->
        if (match.value.contains("image_emoticon", true) || match.value.contains("BDE_Smiley", true)) return@forEach
        val urls = attributes.findAll(match.value).associate { it.groupValues[1].lowercase() to it.groupValues[2] }
        val url = listOf("data-original", "data-src", "src").firstNotNullOfOrNull { key ->
            targetUrl(plainText(urls[key].orEmpty(), false)).takeIf { it.isNotEmpty() }
        } ?: return@forEach
        if (match.range.first > start) result.add(Segment(input.substring(start, match.range.first)))
        result.add(Segment("", media = Media(url)))
        start = match.range.last + 1
    }
    if (start == 0) listOf(segment) else {
        if (start < input.length) result.add(Segment(input.substring(start)))
        result
    }
}

fun plainText(value: String, trim: Boolean = true): String {
    var text = value.replace(Regex("<(script|style)\\b[^>]*>.*?</\\1\\s*>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL)), "")
    text = text.replace(Regex("<img\\b[^>]*>", RegexOption.IGNORE_CASE)) { tag ->
        Regex("(?:src|data-src|data-original|alt|title|data-name)\\s*=\\s*[\"']([^\"']*)[\"']", RegexOption.IGNORE_CASE).findAll(tag.value).map { it.groupValues[1] }.firstNotNullOfOrNull { attribute ->
            val id = Regex("image[_ ]emoticon\\s*[-_ ]?(\\d+)", RegexOption.IGNORE_CASE).find(attribute)?.groupValues?.get(1)?.toIntOrNull()
            if (id != null) emojiIds.entries.firstOrNull { it.value == id }?.key?.let { "[$it]" } else attribute.takeIf(::isEmoji)
        } ?: "[图片]"
    }
    text = text.replace(Regex("<\\s*(br|/p|/div|/li|/tr|/h[1-6])\\b[^>]*>", RegexOption.IGNORE_CASE), "\n").replace(Regex("<[^>]+>"), "")
    text = text.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'")
    text = text.replace(Regex("&#(x[0-9a-f]+|[0-9]+);?", RegexOption.IGNORE_CASE)) { match ->
        val raw = match.groupValues[1]
        val number = if (raw.startsWith("x", true)) raw.drop(1).toIntOrNull(16) else raw.toIntOrNull()
        if (number != null && Character.isValidCodePoint(number)) String(Character.toChars(number)) else match.value
    }.replace(Regex("[ \\t]+\\n"), "\n").replace(Regex("\\n{3,}"), "\n\n")
    return if (trim) text.trim() else text
}

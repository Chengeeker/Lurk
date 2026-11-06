package com.lurk

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

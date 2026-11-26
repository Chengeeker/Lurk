package com.lurk

import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import org.junit.Assert.assertEquals
import org.junit.Test

class CommentEditorTest {
    @Test fun emojiInsertionAndDeletionRespectSelectionAndSurrogatePairs() {
        val inserted = TextFieldValue("前删除后", TextRange(1, 3)).insertPhrase("😀")
        assertEquals("前😀后", inserted.text)
        assertEquals(TextRange(3), inserted.selection)
        assertEquals(TextFieldValue("前后", TextRange(1)), inserted.erasePhrase())
        assertEquals("前后", TextFieldValue("前选中后", TextRange(3, 1)).erasePhrase().text)
        assertEquals("前", TextFieldValue("前", TextRange.Zero).erasePhrase().text)
    }
}

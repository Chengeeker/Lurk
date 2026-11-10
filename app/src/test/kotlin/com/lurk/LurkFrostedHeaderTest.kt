package com.lurk

import android.graphics.Bitmap
import android.graphics.HardwareRenderer
import android.graphics.RenderNode
import android.view.View
import androidx.activity.ComponentActivity
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w360dp-h800dp-mdpi")
class LurkFrostedHeaderTest {
    @get:Rule val compose = createAndroidComposeRule<ComponentActivity>()

    @Test fun transparentReplyMarksAreBlurredInLightAndDark() {
        val dark = mutableStateOf(false)
        compose.setContent {
            val night = dark.value
            val background = if (night) Color(0xFF111215) else Color.White
            val scheme = if (night) darkColorScheme(background = background) else lightColorScheme(background = background)
            MaterialTheme(colorScheme = scheme) {
                key(night) {
                    FrostedFrame(header = { Box(Modifier.fillMaxWidth().height(80.dp)) }) {
                        Canvas(Modifier.fillMaxSize()) {
                            for (x in 12..size.width.toInt() step 12) {
                                drawRect(if (night) Color.White else Color.Black, Offset(x.toFloat(), 0f), Size(3f, 160.dp.toPx()))
                            }
                        }
                    }
                }
            }
        }
        for (night in listOf(false, true)) {
            compose.runOnIdle { dark.value = night }
            compose.waitForIdle()
            compose.runOnUiThread {
                val view = compose.activity.findViewById<View>(android.R.id.content)
                val node = RenderNode("reply backdrop")
                node.setPosition(0, 0, view.width, view.height)
                view.draw(node.beginRecording())
                node.endRecording()
                val output = HardwareRenderer::class.java.getDeclaredMethod(
                    "createHardwareBitmap", RenderNode::class.java, Int::class.javaPrimitiveType, Int::class.javaPrimitiveType,
                ).invoke(null, node, view.width, view.height) as Bitmap
                val bitmap = checkNotNull(output.copy(Bitmap.Config.ARGB_8888, false))
                output.recycle()
                try {
                    fun edge(y: Int): Int = abs((bitmap.getPixel(121, y) and 255) - (bitmap.getPixel(127, y) and 255))
                    assertTrue("The source below the header must be sharp", edge(104) >= 200)
                    assertTrue("Comment text leaks through the header", edge(68) <= 12)
                } finally {
                    bitmap.recycle()
                }
            }
        }
    }
}

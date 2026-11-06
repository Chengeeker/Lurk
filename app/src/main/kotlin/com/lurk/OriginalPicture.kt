package com.lurk

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BrokenImage
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage

@Composable
fun OriginalPicture(url: String, description: String?, modifier: Modifier, contentScale: ContentScale,
                    onImageReady: (android.graphics.drawable.Drawable?) -> Unit = {}) {
    val colors = MaterialTheme.colorScheme
    if (url.isBlank()) {
        Box(modifier.background(colors.surfaceContainerHighest.copy(alpha = .3f)), contentAlignment = Alignment.Center) {
            Icon(Icons.Outlined.BrokenImage, description, Modifier.size(24.dp), tint = colors.outline)
        }
        return
    }
    var state by remember(url) { mutableIntStateOf(1) }; var retry by remember(url) { mutableIntStateOf(0) }
    Box(modifier, contentAlignment = Alignment.Center) {
        key(url, retry) { AsyncImage(mediaRequest(LocalContext.current, url), description, if (contentScale == ContentScale.Crop) Modifier.fillMaxSize() else Modifier, contentScale = contentScale,
            onLoading = { onImageReady(null); state = 1 },
            onSuccess = { onImageReady(it.result.drawable); state = 0 },
            onError = { onImageReady(null); state = 2 }) }
        if (state != 0) Box(Modifier.matchParentSize().background(colors.surfaceContainerHighest.copy(alpha = if (state == 1) .25f else .35f)), contentAlignment = Alignment.Center) {
            if (state == 1) CircularProgressIndicator(Modifier.size(20.dp), color = colors.primary.copy(alpha = .7f), strokeWidth = 2.dp)
            else Column(Modifier.fillMaxSize().feedbackClickable { state = 1; retry++ }.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Icon(Icons.Rounded.Refresh, "重新加载图片", Modifier.size(22.dp), tint = colors.outline)
                Spacer(Modifier.height(4.dp)); Text("重新加载", fontSize = 11.5.sp, color = colors.outline)
            }
        }
    }
}

@Composable
fun OriginalAvatar(url: String, description: String?, modifier: Modifier) {
    val colors = MaterialTheme.colorScheme
    var loaded by remember(url) { mutableStateOf(false) }
    Box(modifier.background(colors.surfaceContainerHighest), contentAlignment = Alignment.Center) {
        if (!loaded) BoxWithConstraints(Modifier.matchParentSize(), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.Person, null, Modifier.size(maxWidth * .6f), tint = colors.outlineVariant)
        }
        AsyncImage(url, description, Modifier.matchParentSize(), contentScale = ContentScale.Crop,
            onLoading = { loaded = false }, onSuccess = { loaded = true }, onError = { loaded = false })
    }
}

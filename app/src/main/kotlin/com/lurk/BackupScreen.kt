package com.lurk

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.error
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Credentials
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BackupTextField(value: String, change: (String) -> Unit, label: String, icon: ImageVector, enabled: Boolean = true,
                    hint: String? = null, error: String? = null, secret: Boolean = false) {
    val interaction = remember { MutableInteractionSource() }
    val colors = MaterialTheme.colorScheme
    val transform = if (secret) PasswordVisualTransformation() else VisualTransformation.None
    val fieldColors = OutlinedTextFieldDefaults.colors()
    Column {
        BasicTextField(value, change, Modifier.fillMaxWidth().heightIn(min = 48.dp).semantics { if (error != null) error(error) }, enabled = enabled, singleLine = true,
            textStyle = MaterialTheme.typography.bodyLarge.copy(color = if (enabled) colors.onSurface else colors.onSurface.copy(alpha = .38f)),
            visualTransformation = transform, interactionSource = interaction, cursorBrush = SolidColor(colors.primary),
            decorationBox = { input -> OutlinedTextFieldDefaults.DecorationBox(value, input, enabled, true, transform, interaction,
                isError = error != null, label = { Text(label) }, placeholder = hint?.let { { Text(it) } },
                leadingIcon = { Icon(icon, null, Modifier.size(24.dp)) }, colors = fieldColors,
                contentPadding = PaddingValues(start = 12.dp, top = 16.dp, end = 12.dp, bottom = 8.dp),
                container = { OutlinedTextFieldDefaults.Container(enabled, error != null, interaction, colors = fieldColors, shape = RoundedCornerShape(4.dp)) }) })
        if (error != null) Text(error, Modifier.padding(start = 12.dp, top = 4.dp), style = MaterialTheme.typography.bodySmall, color = colors.error)
    }
}

class WebDav(private val server: String, private val username: String, private val password: String, private val directory: String) {
    private fun base(): HttpUrl {
        val url = (if (server.contains("://")) server.trim() else "https://${server.trim()}").toHttpUrl()
        require((url.isHttps || url.host in setOf("127.0.0.1", "localhost", "::1")) && url.username.isEmpty() && url.password.isEmpty() && url.query == null && url.fragment == null) { "请填写有效的 HTTPS WebDAV 地址" }
        return url.newBuilder().apply { if (!url.encodedPath.endsWith('/')) addPathSegment("") }.build()
    }
    private fun dir() = base().newBuilder().addPathSegment(directory.ifBlank { "Lurk" }).addPathSegment("").build()
    private suspend fun execute(url: HttpUrl, method: String, body: String? = null, accepted: Set<Int>): ByteArray = withContext(Dispatchers.IO) {
        val request = Request.Builder().url(url).header("Authorization", Credentials.basic(username, password))
            .header("Depth", "0").method(method, body?.toRequestBody("application/json; charset=utf-8".toMediaType())).build()
        NativeApi.http.newCall(request).execute().use { response ->
            require(response.code in accepted) { "WebDAV 请求失败（${response.code}）" }
            val source = response.body?.byteStream() ?: return@withContext byteArrayOf()
            source.use { input ->
                val output = java.io.ByteArrayOutputStream(); val buffer = ByteArray(8192)
                while (true) { val n = input.read(buffer); if (n < 0) break; require(output.size() + n <= 16 * 1024 * 1024) { "备份超过 16 MB" }; output.write(buffer, 0, n) }
                output.toByteArray()
            }
        }
    }
    suspend fun test() { execute(base(), "PROPFIND", accepted = setOf(200, 207)) }
    suspend fun upload(data: JSONObject): Boolean {
        execute(dir(), "MKCOL", accepted = setOf(200, 201, 405))
        val text = data.toString(2)
        execute(dir().newBuilder().addPathSegment("backup_lurk_latest.json").build(), "PUT", text, setOf(200, 201, 204))
        return try {
            execute(dir().newBuilder().addPathSegment("backup_lurk_${System.currentTimeMillis()}.json").build(), "PUT", text, setOf(200, 201, 204)); true
        } catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (_: Exception) { false }
    }
    suspend fun download(): JSONObject = JSONObject(execute(dir().newBuilder().addPathSegment("backup_lurk_latest.json").build(), "GET", accepted = setOf(200)).toString(Charsets.UTF_8))
}


@Composable
fun BackupScreen(back: () -> Unit) {
    val model = LocalState.current; val colors = MaterialTheme.colorScheme
    var server by remember { mutableStateOf(model.store.string("key_webdav_url")) }
    var username by remember { mutableStateOf(model.store.string("key_webdav_username")) }
    var password by remember { mutableStateOf("") }
    var directory by remember { mutableStateOf(model.store.string("key_webdav_directory", "Lurk")) }
    var full by remember { mutableStateOf(false) }; var restore by remember { mutableStateOf(false) }
    var operation by remember { mutableStateOf("") }
    LaunchedEffect(Unit) { runCatching { withContext(Dispatchers.IO) { model.store.secret("webdav").orEmpty() } }.onSuccess { password = it }.onFailure { model.message("备份密码读取失败，请重新填写") } }
    var showErrors by remember { mutableStateOf(false) }
    val url = runCatching { (if (server.contains("://")) server.trim() else "https://${server.trim()}").toHttpUrl() }.getOrNull()
    val serverError = when {
        server.isBlank() -> "请输入 WebDAV 服务器地址"
        url == null || (!url.isHttps && url.host !in setOf("127.0.0.1", "localhost", "::1")) || url.username.isNotEmpty() || url.password.isNotEmpty() || url.query != null || url.fragment != null -> "请输入有效的 https:// WebDAV 地址"
        else -> null
    }
    val usernameError = if (username.isBlank()) "请输入账号" else null
    val passwordError = if (password.isBlank()) "请输入密码或授权 Token" else null
    fun valid(): Boolean {
        showErrors = true
        return serverError == null && usernameError == null && passwordError == null
    }
    suspend fun saveConfig() = withContext(Dispatchers.IO) {
        model.store.putAll(mapOf("key_webdav_url" to server.trim(), "key_webdav_username" to username.trim(), "key_webdav_directory" to directory.trim().ifEmpty { "Lurk" }))
        model.store.saveSecret("webdav", password)
    }
    fun run(kind: String) {
        if (!valid()) return
        model.action(false) { _, _ ->
            operation = kind
            try {
                saveConfig(); val client = WebDav(server.trim(), username.trim(), password, directory.trim().ifEmpty { "Lurk" })
                when (kind) {
                    "test" -> { client.test(); model.message("🎉 WebDAV 服务器连接成功！") }
                    "backup" -> { val data = withContext(Dispatchers.IO) { model.store.backup(full) }; val history = client.upload(data); model.message(if (history) "🎉 应用设置已成功备份到 WebDAV 云盘！" else "最新备份已上传，历史副本上传失败") }
                    "restore" -> {
                        val data = client.download(); BackupSchema.validate(data)
                        withContext(Dispatchers.IO) { model.store.restore(data) }; model.reloadAccount()
                        server = model.store.string("key_webdav_url"); username = model.store.string("key_webdav_username"); directory = model.store.string("key_webdav_directory", "Lurk")
                        password = withContext(Dispatchers.IO) { model.store.secret("webdav").orEmpty() }
                        model.message("🎉 备份已成功恢复！重启应用可应用全部设置，登录有效性以贴吧校验为准")
                    }
                }
            } finally { operation = "" }
        }
    }
    FrostedFrame(header = { PageBar("WebDAV 云端备份与恢复", back, titleWeight = FontWeight.Bold) }) {
        Column(Modifier.verticalScroll(rememberPageScrollState()).padding(start = 16.dp, top = 14.dp + LocalContentTop.current, end = 16.dp, bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(Modifier.fillMaxWidth().background(colors.primaryContainer.copy(alpha = .4f), RoundedCornerShape(16.dp)).border(1.dp, colors.primary.copy(alpha = .2f), RoundedCornerShape(16.dp)).padding(14.dp)) {
                Icon(Icons.Rounded.CloudSync, null, tint = colors.primary); Spacer(Modifier.width(12.dp)); Column { Text("备份内容", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = colors.primary); Spacer(Modifier.height(4.dp)); Text("备份应用设置、搜索与浏览历史等本地数据，不包含图片和视频缓存。", fontSize = 14.sp, lineHeight = 1.4.em, color = colors.onSurfaceVariant) }
            }
            SectionCard {
                listOf(false, true).forEach { choice -> Row(Modifier.fillMaxWidth().heightIn(min = 76.dp).feedbackClickable(enabled = !model.writing) { full = choice }.padding(horizontal = 16.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                    CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) { RadioButton(full == choice, null, Modifier.size(40.dp), enabled = !model.writing) }
                    Spacer(Modifier.width(16.dp))
                    Column(Modifier.weight(1f)) { Text(if (choice) "全量备份" else "全量安全备份", style = MaterialTheme.typography.titleMedium.copy(fontSize = 16.sp)); Text(if (choice) "同时上传 Cookie、Token 和 WebDAV 密码。备份文件含明文凭据，请妥善保管云盘及历史备份。" else "Cookie、Token 和 WebDAV 密码不会上传。", fontSize = 14.sp, color = colors.onSurfaceVariant) }
                } }
            }
            SectionCard {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("WebDAV 服务器配置", fontSize = 16.sp, fontWeight = FontWeight.SemiBold); Spacer(Modifier.height(4.dp))
                    BackupTextField(server, { server = it }, "服务器 URL", Icons.Rounded.Link, !model.writing, hint = "例如: https://dav.jianguoyun.com/dav/", error = serverError.takeIf { showErrors })
                    BackupTextField(username, { username = it }, "账号 / 邮箱", Icons.Rounded.PersonOutline, !model.writing, error = usernameError.takeIf { showErrors })
                    BackupTextField(password, { password = it }, "应用密码 / Token", Icons.Outlined.Lock, !model.writing, error = passwordError.takeIf { showErrors }, secret = true)
                    BackupTextField(directory, { directory = it }, "备份文件夹名称", Icons.Outlined.Folder, !model.writing, hint = "默认: Lurk")
                    Spacer(Modifier.height(4.dp))
                    OutlinedButton(enabled = !model.writing, onClick = tapFeedback { run("test") }, modifier = Modifier.fillMaxWidth()) { if (operation == "test") CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp) else Icon(Icons.Rounded.WifiTethering, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text(if (operation == "test") "正在测试连接..." else "测试服务器连接") }
                }
            }
            SectionCard {
                Column(Modifier.padding(16.dp)) {
                    Text("云端备份与还原操作", fontSize = 16.sp, fontWeight = FontWeight.SemiBold); Spacer(Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(enabled = !model.writing, onClick = tapFeedback { run("backup") }, modifier = Modifier.weight(1f), contentPadding = PaddingValues(vertical = 12.dp)) { if (operation == "backup") CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp) else Icon(Icons.Rounded.CloudUpload, null); Spacer(Modifier.width(8.dp)); Text(if (operation == "backup") "正在上传..." else "立即备份到云端") }
                        FilledTonalButton(enabled = !model.writing, onClick = tapFeedback { if (valid()) restore = true }, modifier = Modifier.weight(1f), contentPadding = PaddingValues(vertical = 12.dp)) { if (operation == "restore") CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp) else Icon(Icons.Rounded.CloudDownload, null); Spacer(Modifier.width(8.dp)); Text(if (operation == "restore") "正在拉取..." else "从云端恢复备份") }
                    }
                }
            }
        }
    }
    if (restore) AlertDialog(onDismissRequest = { restore = false }, title = { Text("从 WebDAV 恢复备份？") }, text = { Text("恢复备份将覆盖备份中包含的设置和历史。若云端是全量备份，还会替换贴吧登录凭据及 WebDAV 密码；全量安全备份保留本机登录凭据。是否继续？") }, confirmButton = { Button(onClick = tapFeedback { restore = false; run("restore") }) { Text("确定恢复") } }, dismissButton = { TextButton(onClick = tapFeedback { restore = false }) { Text("取消") } })
}



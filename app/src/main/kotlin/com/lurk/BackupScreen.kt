package com.lurk

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.error
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
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
    private fun dir() = base().newBuilder().addPathSegment(directory.trim().ifBlank { "Lurk" }.also {
        require(it !in setOf(".", "..") && it.none { c -> c == '/' || c == '\\' || c.code < 32 || c.code == 127 }) { "备份目录无效" }
    }).addPathSegment("").build()
    private val transport = WebDavTransport(NativeApi.http, 16L * 1024 * 1024)
    private suspend fun execute(url: HttpUrl, method: String, body: String? = null, accepted: Set<Int>): ByteArray =
        transport.request(url, method, Credentials.basic(username, password, Charsets.UTF_8), body?.toByteArray(Charsets.UTF_8))
            .requireStatus(if (method == "GET") "下载" else method, accepted).bytes
    suspend fun test() { execute(base(), "PROPFIND", accepted = setOf(200, 207)) }
    suspend fun upload(data: JSONObject): Boolean {
        execute(dir(), "MKCOL", accepted = setOf(200, 201, 405))
        val text = data.toString(2)
        execute(dir().newBuilder().addPathSegment("backup_lurk_latest.json").build(), "PUT", text, setOf(200, 201, 204))
        return try {
            execute(dir().newBuilder().addPathSegment("backup_lurk_${System.currentTimeMillis()}.json").build(), "PUT", text, setOf(200, 201, 204)); true
        } catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (_: Exception) { false }
    }
    suspend fun download(): JSONObject = transport.request(dir().newBuilder().addPathSegment("backup_lurk_latest.json").build(), "GET",
        Credentials.basic(username, password, Charsets.UTF_8)).requireStatus("下载", setOf(200)).json().also { BackupSchema.validate(it) }
}


@Composable
fun BackupScreen(back: () -> Unit) {
    val model = LocalState.current; val colors = MaterialTheme.colorScheme
    var server by remember { mutableStateOf(model.store.string("key_webdav_url")) }
    var username by remember { mutableStateOf(model.store.string("key_webdav_username")) }
    var password by remember { mutableStateOf("") }
    var directory by remember { mutableStateOf(model.store.string("key_webdav_directory", "Lurk")) }
    var full by remember { mutableStateOf(false) }; var restore by remember { mutableStateOf(false) }
    var operation by remember { mutableStateOf("loading") }
    val focus=androidx.compose.ui.platform.LocalFocusManager.current
    val scope=rememberCoroutineScope()
    var result by remember {mutableStateOf<String?>(null)}
    var resultTitle by remember {mutableStateOf("连接测试结果")}
    LaunchedEffect(Unit) {
        try {password=withContext(Dispatchers.IO){model.store.secret("webdav").orEmpty()}}
        catch(e:kotlinx.coroutines.CancellationException){throw e}
        catch(_:Exception){result="备份密码读取失败，原加密资料保留，请重新填写"}
        finally{operation=""}
    }
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
        focus.clearFocus();showErrors = true
        val valid=serverError == null && usernameError == null && passwordError == null && directory.trim().let { it !in setOf(".","..") && it.none { c->c=='/'||c=='\\'||c.code<32 } }
        if(!valid)result="请检查服务器地址、账号、密码和备份目录"
        return valid
    }
    suspend fun saveConfig() = withContext(Dispatchers.IO) {
        model.store.putAll(mapOf("key_webdav_url" to server.trim(), "key_webdav_username" to username.trim(), "key_webdav_directory" to directory.trim().ifEmpty { "Lurk" }))
        model.store.saveSecret("webdav", password)
    }
    fun run(kind: String) {
        if(operation.isNotEmpty() || model.writing)return
        result=null;resultTitle=when(kind){"test"->"连接测试结果";"backup"->"备份结果";else->"恢复结果"}
        if (!valid()) return
        operation=kind
        scope.launch {
            try {
                if(kind!="restore")saveConfig(); val client = WebDav(server.trim(), username.trim(), password, directory.trim().ifEmpty { "Lurk" })
                when (kind) {
                    "test" -> { client.test(); run {result="WebDAV 服务器连接成功"} }
                    "backup" -> { val data = withContext(Dispatchers.IO) { model.store.backup(full) }; val history = client.upload(data); run {result=if (history) "🎉 应用设置已成功备份到 WebDAV 云盘！" else "最新备份已上传，历史副本上传失败"} }
                    "restore" -> {
                        val data = client.download(); BackupSchema.validate(data)
                        val restored=withContext(Dispatchers.IO) { model.store.restore(data) }; model.reloadAccount()
                        server = model.store.string("key_webdav_url"); username = model.store.string("key_webdav_username"); directory = model.store.string("key_webdav_directory", "Lurk")
                        password = withContext(Dispatchers.IO) { model.store.secret("webdav").orEmpty() }
                        run {result=restored}
                    }
                }
            } catch(e:kotlinx.coroutines.CancellationException){throw e}
            catch(e:Exception){result=webDavError(e)}
            finally { operation = "" }
        }
    }
    FrostedFrame(header = { PageBar("WebDAV 云端备份与恢复", back, titleWeight = FontWeight.Bold) }) {
        Column(Modifier.fillMaxSize().imePadding().verticalScroll(rememberPageScrollState()).padding(start = 16.dp, top = 14.dp + LocalContentTop.current, end = 16.dp, bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(Modifier.fillMaxWidth().background(colors.primaryContainer.copy(alpha = .4f), RoundedCornerShape(16.dp)).border(1.dp, colors.primary.copy(alpha = .2f), RoundedCornerShape(16.dp)).padding(14.dp)) {
                Icon(Icons.Rounded.CloudSync, null, tint = colors.primary); Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text("备份内容", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = colors.primary); Spacer(Modifier.height(4.dp)); Text("备份设置、收藏和历史，不含图片与视频缓存。", style = MaterialTheme.typography.bodyMedium, color = colors.onSurfaceVariant) }
            }
            SettingsSectionCard { BackupModeOptions(full, !model.writing && operation.isEmpty()) { full = it } }
            SettingsSectionCard {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("WebDAV 服务器配置", fontSize = 16.sp, fontWeight = FontWeight.SemiBold); Spacer(Modifier.height(4.dp))
                    BackupTextField(server, { server = it }, "服务器 URL", Icons.Rounded.Link, !model.writing && operation.isEmpty(), hint = "例如: https://dav.jianguoyun.com/dav/", error = serverError.takeIf { showErrors })
                    BackupTextField(username, { username = it }, "账号 / 邮箱", Icons.Rounded.PersonOutline, !model.writing && operation.isEmpty(), error = usernameError.takeIf { showErrors })
                    BackupTextField(password, { password = it }, "应用密码 / Token", Icons.Outlined.Lock, !model.writing && operation.isEmpty(), error = passwordError.takeIf { showErrors }, secret = true)
                    BackupTextField(directory, { directory = it }, "备份文件夹名称", Icons.Outlined.Folder, !model.writing && operation.isEmpty(), hint = "默认: Lurk")
                    Spacer(Modifier.height(4.dp))
                    OutlinedButton(enabled = !model.writing && operation.isEmpty(), onClick = tapFeedback { run("test") }, modifier = Modifier.fillMaxWidth()) { if (operation == "test") CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp) else Icon(Icons.Rounded.WifiTethering, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text(if (operation == "test") "正在测试连接..." else "测试服务器连接") }
                }
            }
            SettingsSectionCard {
                Column(Modifier.padding(16.dp)) {
                    Text("云端备份与还原操作", fontSize = 16.sp, fontWeight = FontWeight.SemiBold); Spacer(Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(enabled = !model.writing && operation.isEmpty(), onClick = tapFeedback { run("backup") }, modifier = Modifier.weight(1f), contentPadding = PaddingValues(vertical = 12.dp)) { if (operation == "backup") CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp) else Icon(Icons.Rounded.CloudUpload, null); Spacer(Modifier.width(8.dp)); Text(if (operation == "backup") "正在上传..." else "立即备份到云端") }
                        FilledTonalButton(enabled = !model.writing && operation.isEmpty(), onClick = tapFeedback { resultTitle="恢复结果";result=null;if (valid()) restore = true }, modifier = Modifier.weight(1f), contentPadding = PaddingValues(vertical = 12.dp)) { if (operation == "restore") CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp) else Icon(Icons.Rounded.CloudDownload, null); Spacer(Modifier.width(8.dp)); Text(if (operation == "restore") "正在拉取..." else "从云端恢复备份") }
                    }
                }
            }
        }
    }
    if(operation.isEmpty()) result?.let { message ->
        AlertDialog(onDismissRequest={result=null},title={Text(resultTitle)},
            text={Text(message,Modifier.verticalScroll(rememberScrollState()))},
            confirmButton={TextButton(onClick=tapFeedback {result=null}){Text("知道了")}})
    }
    if (restore) AlertDialog(onDismissRequest = { restore = false }, title = { Text("从 WebDAV 恢复备份？") }, text = { Text("将用备份覆盖本机对应数据。全量备份会恢复 WebDAV 密码；登录凭据验证通过后才替换会话。旧密钥不可用时会先保留并核对原密文，保留密文不等于恢复旧资料。") }, confirmButton = { Button(onClick = tapFeedback { restore = false; run("restore") }) { Text("确定恢复") } }, dismissButton = { TextButton(onClick = tapFeedback { restore = false }) { Text("取消") } })
}

@Composable
internal fun BackupModeOptions(full: Boolean, enabled: Boolean, onSelect: (Boolean) -> Unit) {
    val colors = MaterialTheme.colorScheme
    Column(Modifier.selectableGroup()) {
        listOf(false, true).forEach { choice ->
            Row(
                Modifier.fillMaxWidth()
                    .selectable(full == choice, enabled = enabled, role = Role.RadioButton, onClick = tapFeedback { onSelect(choice) })
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(if (choice) "全量备份" else "全量安全备份", style = MaterialTheme.typography.titleMedium)
                    Text(if (choice) "含会话及网盘密码" else "不含会话及网盘密码", style = MaterialTheme.typography.bodyMedium, color = colors.onSurfaceVariant)
                    if (choice) Text("含明文凭据，请保管", style = MaterialTheme.typography.bodyMedium, color = colors.onSurfaceVariant)
                }
                RadioButton(full == choice, null, Modifier.size(24.dp), enabled = enabled)
            }
        }
    }
}


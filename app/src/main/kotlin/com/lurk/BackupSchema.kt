package com.lurk
import org.json.JSONObject
import org.json.JSONArray
object BackupSchema {
    val bools = setOf("key_use_custom_font_weight", "key_use_dynamic_color", "key_is_pure_black_dark", "key_enable_haptics", "key_use_floating_nav_bar", "key_use_liquid_glass_effect", "translucentNavigationGlass", "key_show_fps", "key_hide_blocked_completely", "key_block_video_threads", "key_recommend_followed_only", "key_use_internal_browser", "key_habit_auto_load_more", "key_habit_double_tap_top", "key_habit_show_original_img", "key_habit_double_tap_feed_refresh", "key_habit_do_not_save_history", "key_my_forums_single_column", "key_auto_clear_cache_on_exit", "key_bookmark_sort_order")
    val ints = setOf("key_theme_mode", "key_theme_color_index", "key_font_weight_index", "key_font_size_percent", "key_display_refresh_rate", "key_habit_initial_tab_index", "key_habit_image_load_mode", "key_habit_forum_default_sort", "key_image_save_path_type", "key_video_save_path_type", "key_auto_clear_cache_threshold_mb")
    val lists = setOf("key_bookmarks_list", "key_bookmark_pending_adds", "key_bookmark_pending_removes", "key_browsing_history_list", "key_forum_browsing_history_list", "key_block_words_list", "key_white_words_list")
    val strings = setOf("key_webdav_url", "key_webdav_username", "key_webdav_directory")
    val credentials = setOf("key_accounts_list", "key_active_account_uid", "key_active_account_name", "key_webdav_password")
    fun isList(key: String) = key in lists || listOf("key_bookmarks_list", "key_bookmark_pending_adds", "key_bookmark_pending_removes").any { key.startsWith("${it}_") && key.removePrefix("${it}_").matches(Regex("[a-zA-Z0-9_-]+")) }
    fun allowed(key: String) = key in bools || key in ints || key in strings || isList(key)
    fun validate(data: JSONObject): JSONObject {
        require(data.s("app") == "Lurk" && data.s("version") == "2.0" && data.s("backup_mode") in setOf("safe", "full")) { "无效的 Lurk 备份" }
        val values = data.getJSONObject("preferences")
        val full = data.s("backup_mode") == "full"
        values.keys().forEach { key ->
            if (allowed(key) || full && key in credentials) {
                val v = values.get(key)
                require(when { key in bools -> v is Boolean; key in ints -> v is Int || v is Long
                    isList(key) || key == "key_accounts_list" -> v is JSONArray && (0 until v.length()).all { v.get(it) is String }
                    else -> v is String }) { "无效的备份设置" }
            }
        }
        if (full) {
            require(credentials.all { values.has(it) }) { "全量备份缺少凭据组" }
            validatedAccounts(values.getJSONArray("key_accounts_list"), values.getString("key_active_account_uid"))
        }
        if (values.has("key_font_weight_index") && !values.has("key_use_custom_font_weight")) values.put("key_use_custom_font_weight", values.optInt("key_font_weight_index", 1) != 1)
        return values
    }
}

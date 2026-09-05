import "package:flutter_test/flutter_test.dart";
import "package:lurk/core/storage/storage_service.dart";
import "package:lurk/features/profile/presentation/widgets/history_view.dart";
import "package:lurk/features/settings/presentation/providers/habit_settings_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  test("ForumHistoryItem serialization and parsing", () {
    final raw = {
      "name": "原神",
      "avatar": "https://tiebapic.baidu.com/avatar.jpg",
      "time": 1700000000000,
    };
    final item = ForumHistoryItem.fromJson(raw);
    expect(item.name, "原神");
    expect(item.avatar, "https://tiebapic.baidu.com/avatar.jpg");
    expect(item.time, 1700000000000);
  });

  test("HabitSettingsState default values and updates", () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    final notifier = HabitSettingsNotifier(storage);
    expect(notifier.state.initialTabIndex, 1);
    expect(notifier.state.imageLoadMode, 0);
    expect(notifier.state.forumDefaultSort, 0);
    expect(notifier.state.doNotSaveHistory, false);
    expect(notifier.state.useInternalBrowser, true);

    await notifier.setInitialTabIndex(0);
    await notifier.setImageLoadMode(2);
    await notifier.setForumDefaultSort(1);
    await notifier.setDoNotSaveHistory(true);
    await notifier.setUseInternalBrowser(false);

    expect(notifier.state.initialTabIndex, 0);
    expect(notifier.state.imageLoadMode, 2);
    expect(notifier.state.forumDefaultSort, 1);
    expect(notifier.state.doNotSaveHistory, true);
    expect(notifier.state.useInternalBrowser, false);

    expect(prefs.getInt(StorageService.keyHabitInitialTabIndex), 0);
    expect(prefs.getInt(StorageService.keyHabitImageLoadMode), 2);
    expect(prefs.getInt(StorageService.keyHabitForumDefaultSort), 1);
    expect(prefs.getBool(StorageService.keyHabitDoNotSaveHistory), true);
    expect(prefs.getBool(StorageService.keyUseInternalBrowser), false);
  });
}

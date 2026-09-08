import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../feed/data/models/tieba_thread_model.dart';

class BlockSettingsState {
  final List<String> blockWords;
  final List<String> whiteWords;
  final bool hideBlockedCompletely;
  final bool blockVideoThreads;
  final bool recommendFollowedOnly;

  const BlockSettingsState({
    this.blockWords = const [],
    this.whiteWords = const [],
    this.hideBlockedCompletely = true,
    this.blockVideoThreads = false,
    this.recommendFollowedOnly = false,
  });

  BlockSettingsState copyWith({
    List<String>? blockWords,
    List<String>? whiteWords,
    bool? hideBlockedCompletely,
    bool? blockVideoThreads,
    bool? recommendFollowedOnly,
  }) {
    return BlockSettingsState(
      blockWords: blockWords ?? this.blockWords,
      whiteWords: whiteWords ?? this.whiteWords,
      hideBlockedCompletely: hideBlockedCompletely ?? this.hideBlockedCompletely,
      blockVideoThreads: blockVideoThreads ?? this.blockVideoThreads,
      recommendFollowedOnly: recommendFollowedOnly ?? this.recommendFollowedOnly,
    );
  }

  bool isThreadBlocked(TiebaThreadModel thread, {Set<String>? followedForums}) {
    // 1. 不看视频贴
    if (blockVideoThreads) {
      final hasVideo = thread.mediaList.any((m) => m.type == 'video' || m.type == '3');
      if (hasVideo) return true;
    }

    // 2. 只推荐已关注的吧
    if (recommendFollowedOnly && followedForums != null && thread.fname.isNotEmpty) {
      if (!followedForums.contains(thread.fname)) {
        return true;
      }
    }

    // 3. 屏蔽词与白名单匹配
    if (blockWords.isNotEmpty) {
      final combined = '${thread.title} ${thread.contentSnippet} ${thread.author.name} ${thread.author.nameShow}'.toLowerCase();
      
      bool hitBlack = false;
      for (final word in blockWords) {
        if (word.trim().isNotEmpty && combined.contains(word.trim().toLowerCase())) {
          hitBlack = true;
          break;
        }
      }

      if (hitBlack) {
        // 检查白名单
        bool hitWhite = false;
        for (final white in whiteWords) {
          if (white.trim().isNotEmpty && combined.contains(white.trim().toLowerCase())) {
            hitWhite = true;
            break;
          }
        }
        if (!hitWhite) {
          return true;
        }
      }
    }

    return false;
  }
}

class BlockSettingsNotifier extends StateNotifier<BlockSettingsState> {
  final StorageService _storage;

  BlockSettingsNotifier(this._storage)
      : super(BlockSettingsState(
          blockWords: _storage.getStringList(StorageService.keyBlockWords),
          whiteWords: _storage.getStringList(StorageService.keyWhiteWords),
          hideBlockedCompletely: _storage.getBool(StorageService.keyHideBlockedCompletely, defaultValue: true),
          blockVideoThreads: _storage.getBool(StorageService.keyBlockVideoThreads, defaultValue: false),
          recommendFollowedOnly: _storage.getBool(StorageService.keyRecommendFollowedOnly, defaultValue: false),
        ));

  Future<void> addBlockWord(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty || state.blockWords.contains(trimmed)) return;
    final updated = [...state.blockWords, trimmed];
    await _storage.setStringList(StorageService.keyBlockWords, updated);
    state = state.copyWith(blockWords: updated);
  }

  Future<void> removeBlockWord(String word) async {
    final updated = state.blockWords.where((w) => w != word).toList();
    await _storage.setStringList(StorageService.keyBlockWords, updated);
    state = state.copyWith(blockWords: updated);
  }

  Future<void> clearBlockWords() async {
    await _storage.setStringList(StorageService.keyBlockWords, []);
    state = state.copyWith(blockWords: []);
  }

  Future<void> addWhiteWord(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty || state.whiteWords.contains(trimmed)) return;
    final updated = [...state.whiteWords, trimmed];
    await _storage.setStringList(StorageService.keyWhiteWords, updated);
    state = state.copyWith(whiteWords: updated);
  }

  Future<void> removeWhiteWord(String word) async {
    final updated = state.whiteWords.where((w) => w != word).toList();
    await _storage.setStringList(StorageService.keyWhiteWords, updated);
    state = state.copyWith(whiteWords: updated);
  }

  Future<void> clearWhiteWords() async {
    await _storage.setStringList(StorageService.keyWhiteWords, []);
    state = state.copyWith(whiteWords: []);
  }

  Future<void> setHideBlockedCompletely(bool val) async {
    await _storage.setBool(StorageService.keyHideBlockedCompletely, val);
    state = state.copyWith(hideBlockedCompletely: val);
  }

  Future<void> setBlockVideoThreads(bool val) async {
    await _storage.setBool(StorageService.keyBlockVideoThreads, val);
    state = state.copyWith(blockVideoThreads: val);
  }

  Future<void> setRecommendFollowedOnly(bool val) async {
    await _storage.setBool(StorageService.keyRecommendFollowedOnly, val);
    state = state.copyWith(recommendFollowedOnly: val);
  }
}

final blockSettingsProvider =
    StateNotifierProvider<BlockSettingsNotifier, BlockSettingsState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return BlockSettingsNotifier(storage);
});

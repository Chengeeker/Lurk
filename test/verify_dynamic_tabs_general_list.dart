// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk/core/network/tieba_dio_client.dart';
import 'package:lurk/features/forum/data/forum_repository.dart';
import 'package:lurk/features/forum/data/models/forum_model.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';

void main() {
  test('verify dynamic partition tabs via generalTabList and user resolution', () async {
    final dioClient = TiebaDioClient();
    final forumRepo = ForumRepository(dioClient);

    // 1. Fetch forum page for 原神内容讨论
    print('1. Loading forum page for 原神内容讨论...');
    final forumRes = await forumRepo.getForumPage(
      forumName: '原神内容讨论',
      page: 1,
    );
    final forum = forumRes['forum'] as ForumDetailModel;
    final allThreads = (forumRes['threads'] as List).cast<TiebaThreadModel>();

    print('Forum name: "${forum.name}", fid: "${forum.id}", tabs count: ${forum.tabs.length}');
    expect(forum.tabs.isNotEmpty, isTrue);
    expect(allThreads.isNotEmpty, isTrue);

    for (var tab in forum.tabs) {
      print('  -> Tab: "${tab.tabName}" (id: ${tab.tabId}, type: ${tab.tabType}, isGood: ${tab.isGood})');
    }

    // 2. Fetch 强度讨论区 (id: 2879005, type: 15)
    final qdTab = forum.tabs.firstWhere(
      (t) => t.tabName == '强度讨论区',
      orElse: () => const ForumTabModel(tabId: 2879005, tabName: '强度讨论区', tabType: 15),
    );
    print('\n2. Testing dynamic partition tab: "${qdTab.tabName}" (id: ${qdTab.tabId}, type: ${qdTab.tabType})...');
    final qdRes = await forumRepo.getForumPage(
      forumName: '原神内容讨论',
      forumId: forum.id,
      page: 1,
      tabId: qdTab.tabId,
      tabType: qdTab.tabType,
      tabName: qdTab.tabName,
    );
    final qdThreads = (qdRes['threads'] as List).cast<TiebaThreadModel>();
    print('强度讨论区 threads count: ${qdThreads.length}');
    expect(qdThreads.isNotEmpty, isTrue);
    expect(qdThreads.length >= 10, isTrue);

    for (var i = 0; i < 5; i++) {
      final t = qdThreads[i];
      print('  [强度讨论区 #$i] "${t.title}" | 作者: "${t.author.displayName}" (id: ${t.author.id}) | 回复: ${t.replyNum} | 点赞: ${t.agreeNum}');
      expect(t.title.isNotEmpty, isTrue);
      expect(t.author.displayName.isNotEmpty, isTrue);
      expect(t.author.displayName != '贴吧吧友', isTrue);
      expect(t.author.portrait.isNotEmpty, isTrue);
    }

    // 3. Fetch 前瞻资讯区 (id: 2879003, type: 15)
    final qzTab = forum.tabs.firstWhere(
      (t) => t.tabName == '前瞻资讯区',
      orElse: () => const ForumTabModel(tabId: 2879003, tabName: '前瞻资讯区', tabType: 15),
    );
    print('\n3. Testing dynamic partition tab: "${qzTab.tabName}" (id: ${qzTab.tabId}, type: ${qzTab.tabType})...');
    final qzRes = await forumRepo.getForumPage(
      forumName: '原神内容讨论',
      forumId: forum.id,
      page: 1,
      tabId: qzTab.tabId,
      tabType: qzTab.tabType,
      tabName: qzTab.tabName,
    );
    final qzThreads = (qzRes['threads'] as List).cast<TiebaThreadModel>();
    print('前瞻资讯区 threads count: ${qzThreads.length}');
    expect(qzThreads.isNotEmpty, isTrue);
    for (var i = 0; i < 3; i++) {
      final t = qzThreads[i];
      print('  [前瞻资讯区 #$i] "${t.title}" | 作者: "${t.author.displayName}" | 回复: ${t.replyNum}');
      expect(t.title.isNotEmpty, isTrue);
      expect(t.author.displayName.isNotEmpty, isTrue);
      expect(t.author.portrait.isNotEmpty, isTrue);
    }

    // 4. Fetch 剧情交流区 (id: 2879004, type: 15)
    final jqTab = forum.tabs.firstWhere(
      (t) => t.tabName == '剧情交流区',
      orElse: () => const ForumTabModel(tabId: 2879004, tabName: '剧情交流区', tabType: 15),
    );
    print('\n4. Testing dynamic partition tab: "${jqTab.tabName}" (id: ${jqTab.tabId}, type: ${jqTab.tabType})...');
    final jqRes = await forumRepo.getForumPage(
      forumName: '原神内容讨论',
      forumId: forum.id,
      page: 1,
      tabId: jqTab.tabId,
      tabType: jqTab.tabType,
      tabName: jqTab.tabName,
    );
    final jqThreads = (jqRes['threads'] as List).cast<TiebaThreadModel>();
    print('剧情交流区 threads count: ${jqThreads.length}');
    expect(jqThreads.isNotEmpty, isTrue);
    for (var i = 0; i < 3; i++) {
      final t = jqThreads[i];
      print('  [剧情交流区 #$i] "${t.title}" | 作者: "${t.author.displayName}" | 回复: ${t.replyNum}');
      expect(t.title.isNotEmpty, isTrue);
      expect(t.author.displayName.isNotEmpty, isTrue);
      expect(t.author.portrait.isNotEmpty, isTrue);
    }
  });
}

// ignore_for_file: avoid_print, prefer_const_constructors, prefer_const_declarations
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk/features/feed/data/models/tieba_thread_model.dart';
import 'package:lurk/features/forum/data/models/forum_model.dart';
import 'package:lurk/features/settings/presentation/providers/block_settings_provider.dart';

void main() {
  group('BlockSettings and Thread Filtering', () {
    test('filters blacklisted keywords unless whitelisted', () {
      final stateWithBlack = const BlockSettingsState(
        blockWords: ['原神', '水军'],
        whiteWords: ['原神官方'],
      );

      final threadBlocked = TiebaThreadModel(
        id: '1',
        title: '这是一个关于原神的帖子',
        author: const TiebaAuthorModel(id: '1', name: 'user1', nameShow: 'user1'),
      );

      final threadWhitelisted = TiebaThreadModel(
        id: '2',
        title: '这是原神官方发布的新公告',
        author: const TiebaAuthorModel(id: '2', name: 'user2', nameShow: 'user2'),
      );

      final threadNormal = TiebaThreadModel(
        id: '3',
        title: '今天天气真好',
        author: const TiebaAuthorModel(id: '3', name: 'user3', nameShow: 'user3'),
      );

      expect(stateWithBlack.isThreadBlocked(threadBlocked), isTrue);
      expect(stateWithBlack.isThreadBlocked(threadWhitelisted), isFalse);
      expect(stateWithBlack.isThreadBlocked(threadNormal), isFalse);
    });

    test('filters video threads when blockVideoThreads is true', () {
      final stateBlockVideo = const BlockSettingsState(
        blockVideoThreads: true,
      );

      final threadWithVideo = TiebaThreadModel(
        id: '1',
        title: '视频帖子测试',
        author: const TiebaAuthorModel(id: '1', name: 'user1', nameShow: 'user1'),
        mediaList: [
          const TiebaMediaModel(
            originUrl: 'http://video.mp4',
            bigCdnUrl: '',
            thumbUrl: '',
            type: 'video',
          ),
        ],
      );

      final threadWithPic = TiebaThreadModel(
        id: '2',
        title: '图片帖子测试',
        author: const TiebaAuthorModel(id: '2', name: 'user2', nameShow: 'user2'),
        mediaList: [
          const TiebaMediaModel(
            originUrl: 'http://pic.jpg',
            bigCdnUrl: '',
            thumbUrl: '',
            type: 'pic',
          ),
        ],
      );

      expect(stateBlockVideo.isThreadBlocked(threadWithVideo), isTrue);
      expect(stateBlockVideo.isThreadBlocked(threadWithPic), isFalse);
    });

    test('filters non-followed forums when recommendFollowedOnly is true', () {
      final stateFollowedOnly = const BlockSettingsState(
        recommendFollowedOnly: true,
      );

      final threadFollowed = TiebaThreadModel(
        id: '1',
        title: '原神内容讨论吧帖子',
        fname: '原神内容讨论',
        author: const TiebaAuthorModel(id: '1', name: 'user1', nameShow: 'user1'),
      );

      final threadNotFollowed = TiebaThreadModel(
        id: '2',
        title: '某陌生吧帖子',
        fname: '陌生吧',
        author: const TiebaAuthorModel(id: '2', name: 'user2', nameShow: 'user2'),
      );

      final followedSet = {'原神内容讨论', '崩坏星穹铁道'};

      expect(stateFollowedOnly.isThreadBlocked(threadFollowed, followedForums: followedSet), isFalse);
      expect(stateFollowedOnly.isThreadBlocked(threadNotFollowed, followedForums: followedSet), isTrue);
    });
  });

  group('ForumDetailModel Sign-in Status Detection', () {
    test('correctly detects is_sign_in from sign_in_info', () {
      final jsonSigned = {
        'forum_id': '27989825',
        'forum_name': '原神内容讨论',
        'sign_in_info': {
          'user_info': {
            'is_sign_in': 1,
            'user_sign_rank': 688,
          },
        },
      };

      final jsonUnsigned = {
        'forum_id': '27989825',
        'forum_name': '原神内容讨论',
        'sign_in_info': {
          'user_info': {
            'is_sign_in': 0,
          },
        },
      };

      final modelSigned = ForumDetailModel.fromJson(jsonSigned);
      final modelUnsigned = ForumDetailModel.fromJson(jsonUnsigned);

      expect(modelSigned.isSigned, isTrue);
      expect(modelUnsigned.isSigned, isFalse);
    });
  });
}

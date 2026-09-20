import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/constants/tieba_constants.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/spring_page_route.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../forum/presentation/forum_view.dart';
import 'my_forums_controller.dart';

class MyForumsView extends ConsumerWidget {
  const MyForumsView({super.key});

  Widget _buildStateMessage(
    BuildContext context, {
    required IconData icon,
    required String message,
    String? detail,
    VoidCallback? onRetry,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 96),
      children: [
        Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.outline),
              ),
              if (detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.outline, fontSize: 12),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final forumsState = ref.watch(myForumsControllerProvider);
    final isLogin = ref.watch(authStateProvider).isLogin;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '我的关注',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (isLogin && forumsState.forums.isNotEmpty)
            TextButton.icon(
              icon: forumsState.isSigning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.assignment_turned_in_rounded, size: 18),
              label: const Text(
                '一键签到',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: forumsState.isSigning
                  ? null
                  : () async {
                      final ok = await ref
                          .read(myForumsControllerProvider.notifier)
                          .batchSign();
                      if (context.mounted) {
                        AppToast.show(
                          context,
                          ok ? '一键签到完成（已签≥7级吧）' : '签到遇到问题，请重试',
                        );
                      }
                    },
            ),
        ],
      ),
      body: EasyRefresh(
        onRefresh: () async {
          await ref.read(myForumsControllerProvider.notifier).refresh();
        },
        child: !isLogin
            ? _buildStateMessage(
                context,
                icon: Icons.lock_outline_rounded,
                message: '请先登录以查看关注的吧',
              )
            : forumsState.isLoading && forumsState.forums.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : forumsState.errorMessage != null && forumsState.forums.isEmpty
            ? _buildStateMessage(
                context,
                icon: Icons.error_outline_rounded,
                message: forumsState.errorMessage!,
                detail: '请检查网络连接后重试',
                onRetry: () =>
                    ref.read(myForumsControllerProvider.notifier).refresh(),
              )
            : forumsState.forums.isEmpty
            ? _buildStateMessage(
                context,
                icon: Icons.forum_outlined,
                message: '暂无关注的吧',
                detail: '关注新的吧后，它们会显示在这里',
              )
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                ),
                itemCount: forumsState.forums.length,
                itemBuilder: (context, index) {
                  final forum = forumsState.forums[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          SpringPageRoute(
                            page: ForumView(forumName: forum.name),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            AppAvatar(
                              url: TiebaConstants.getForumAvatarUrl(
                                forum.avatar,
                              ),
                              size: 44,
                              radius: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    forum.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Lv.${forum.userLevel}',
                                          style: TextStyle(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (forum.isSigned) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '已签到',
                                            style: TextStyle(
                                              color: colorScheme.outline,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

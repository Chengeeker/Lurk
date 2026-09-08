import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../detail/presentation/widgets/image_gallery_page.dart';
import '../../data/models/tieba_thread_model.dart';
import 'tieba_video_player_page.dart';

class NineGridView extends StatelessWidget {
  final List<TiebaMediaModel> mediaList;
  final String? threadId;
  final String? folderName;

  const NineGridView({
    super.key,
    required this.mediaList,
    this.threadId,
    this.folderName,
  });

  bool _isVideoMedia(TiebaMediaModel m) {
    if (m.type == 'video') return true;
    if (m.videoUrl.isNotEmpty &&
        !m.videoUrl.toLowerCase().endsWith('.jpg') &&
        !m.videoUrl.toLowerCase().endsWith('.jpeg') &&
        !m.videoUrl.toLowerCase().endsWith('.png') &&
        !m.videoUrl.toLowerCase().endsWith('.webp')) {
      return true;
    }
    if (m.originUrl.contains('.mp4') || m.bigCdnUrl.contains('.mp4')) {
      return true;
    }
    return false;
  }

  String _resolveVideoUrl(TiebaMediaModel m) {
    if (m.videoUrl.isNotEmpty) return m.videoUrl;
    if (m.originUrl.contains('.mp4')) return m.originUrl;
    if (m.bigCdnUrl.contains('.mp4')) return m.bigCdnUrl;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (mediaList.isEmpty) return const SizedBox.shrink();

    final count = mediaList.length;
    final images = mediaList
        .map((m) => m.originUrl.isNotEmpty ? m.originUrl : m.bigCdnUrl)
        .toList();

    if (count == 1) {
      final media = mediaList.first;
      final displayUrl = media.originUrl.isNotEmpty
          ? media.originUrl
          : media.bigCdnUrl;
      final isVideo = _isVideoMedia(media);

      return GestureDetector(
        onTap: () {
          if (isVideo) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TiebaVideoPlayerPage(
                  videoUrl: _resolveVideoUrl(media),
                  coverUrl: media.thumbUrl.isNotEmpty
                      ? media.thumbUrl
                      : displayUrl,
                  threadId: threadId,
                ),
              ),
            );
          } else {
            ImageGalleryPage.open(
              context,
              images: images,
              initialIndex: 0,
              folderName: folderName,
            );
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppNetworkImage(
              url: displayUrl,
              fit: BoxFit.cover,
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 300),
              borderRadius: BorderRadius.circular(12),
            ),
            if (isVideo)
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
          ],
        ),
      );
    }

    final int crossAxisCount = count == 4 ? 2 : (count == 2 ? 2 : 3);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count > 9 ? 9 : count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final media = mediaList[index];
        final displayUrl = media.bigCdnUrl.isNotEmpty
            ? media.bigCdnUrl
            : (media.originUrl.isNotEmpty ? media.originUrl : media.thumbUrl);
        final isVideo = _isVideoMedia(media);

        return GestureDetector(
          onTap: () {
            if (isVideo) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TiebaVideoPlayerPage(
                    videoUrl: _resolveVideoUrl(media),
                    coverUrl: media.thumbUrl.isNotEmpty
                        ? media.thumbUrl
                        : displayUrl,
                    threadId: threadId,
                  ),
                ),
              );
            } else {
              ImageGalleryPage.open(
                context,
                images: images,
                initialIndex: index,
                folderName: folderName,
              );
            }
          },
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: displayUrl,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
              ),
              if (isVideo)
                Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

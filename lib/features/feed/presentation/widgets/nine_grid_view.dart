import 'package:flutter/material.dart';

import '../../../../core/utils/haptic_feedback_util.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../detail/presentation/widgets/image_gallery_page.dart';
import '../../data/models/tieba_thread_model.dart';

class NineGridView extends StatefulWidget {
  final List<TiebaMediaModel> mediaList;
  final String? threadId;
  final String? folderName;

  const NineGridView({
    super.key,
    required this.mediaList,
    this.threadId,
    this.folderName,
  });

  @override
  State<NineGridView> createState() => _NineGridViewState();

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
}

class _NineGridViewState extends State<NineGridView> {
  final Object _heroScope = Object();

  @override
  Widget build(BuildContext context) {
    final mediaList = widget.mediaList;
    if (mediaList.isEmpty) return const SizedBox.shrink();

    final count = mediaList.length;
    final galleryItems = mediaList.map((media) {
      final isVideo = widget._isVideoMedia(media);
      final imageUrl = isVideo
          ? (media.thumbUrl.isNotEmpty
                ? media.thumbUrl
                : (media.originUrl.isNotEmpty
                      ? media.originUrl
                      : media.bigCdnUrl))
          : (media.originUrl.isNotEmpty
                ? media.originUrl
                : (media.bigCdnUrl.isNotEmpty
                      ? media.bigCdnUrl
                      : media.thumbUrl));
      return GalleryMediaItem(
        imageUrl: imageUrl,
        isVideo: isVideo,
        videoUrl: widget._resolveVideoUrl(media),
      );
    }).toList();
    final images = galleryItems.map((item) => item.imageUrl).toList();

    if (count == 1) {
      final media = mediaList.first;
      final displayUrl = media.originUrl.isNotEmpty
          ? media.originUrl
          : media.bigCdnUrl;
      final isVideo = widget._isVideoMedia(media);
      const imageConstraints = BoxConstraints(maxHeight: 280, maxWidth: 300);
      final hasImageSize = media.width > 0 && media.height > 0;
      Widget image = AppNetworkImage(
        url: displayUrl,
        fit: BoxFit.cover,
        constraints: hasImageSize ? null : imageConstraints,
        borderRadius: BorderRadius.circular(12),
      );
      if (hasImageSize) {
        image = ConstrainedBox(
          constraints: imageConstraints,
          child: AspectRatio(
            aspectRatio: media.width / media.height,
            child: image,
          ),
        );
      }
      final thumbnail = Stack(
        alignment: Alignment.center,
        children: [
          image,
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
      );

      return GestureDetector(
        onTap: () {
          HapticFeedbackUtil.light();
          ImageGalleryPage.open(
            context,
            images: images,
            mediaItems: galleryItems,
            initialIndex: 0,
            folderName: widget.folderName,
            heroScope: _heroScope,
            threadId: widget.threadId,
          );
        },
        child: isVideo
            ? thumbnail
            : ImageGalleryHeroThumbnail(
                scope: _heroScope,
                index: 0,
                mediaIdentity: images[0],
                child: thumbnail,
              ),
      );
    }

    final int crossAxisCount = count == 4 ? 2 : (count == 2 ? 2 : 3);

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
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
        final isVideo = widget._isVideoMedia(media);

        return GestureDetector(
          onTap: () {
            HapticFeedbackUtil.light();
            ImageGalleryPage.open(
              context,
              images: images,
              mediaItems: galleryItems,
              initialIndex: index,
              folderName: widget.folderName,
              heroScope: _heroScope,
              threadId: widget.threadId,
            );
          },
          child: isVideo
              ? Stack(
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
                )
              : ImageGalleryHeroThumbnail(
                  scope: _heroScope,
                  index: index,
                  mediaIdentity: images[index],
                  child: Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        url: displayUrl,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

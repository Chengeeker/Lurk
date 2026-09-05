import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:video_player/video_player.dart";

import "../../../../core/network/sign_interceptor.dart";
import "../../../../core/services/media_save_service.dart";
import "../../../../core/utils/app_toast.dart";
import "../../../../core/utils/haptic_feedback_util.dart";

/// 贴吧原生沉浸式视频播放器 (支持智能解析、按住即刻 2.0X 极速快进/松手秒回原速、清晰度无缝切换、高反差相册保存)
class TiebaVideoPlayerPage extends ConsumerStatefulWidget {
  final String videoUrl;
  final String? coverUrl;
  final String? title;
  final String? authorName;
  final String? threadId;
  final Map<String, String>? videoQualityUrls;

  const TiebaVideoPlayerPage({
    super.key,
    required this.videoUrl,
    this.coverUrl,
    this.title,
    this.authorName,
    this.threadId,
    this.videoQualityUrls,
  });

  @override
  ConsumerState<TiebaVideoPlayerPage> createState() =>
      _TiebaVideoPlayerPageState();
}

class _TiebaVideoPlayerPageState extends ConsumerState<TiebaVideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isLoadingDynamic = false;

  String _effectiveVideoUrl = "";

  // 播放倍速控制
  double _playbackSpeed = 1.0;
  bool _isFastForwarding = false;
  static const List<double> _availableSpeeds = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
    3.0,
  ];

  // 清晰度控制
  late Map<String, String> _qualityMap;
  String _currentQuality = "高清";

  // 按住快进手势计时器与指针跟踪
  Timer? _pressTimer;
  int _activePointers = 0;

  @override
  void initState() {
    super.initState();
    _effectiveVideoUrl = widget.videoUrl;
    _qualityMap = Map.from(widget.videoQualityUrls ?? {});
    if (_qualityMap.isEmpty && _effectiveVideoUrl.isNotEmpty) {
      _qualityMap["高清"] = _effectiveVideoUrl;
    }

    if (_qualityMap.isNotEmpty) {
      _currentQuality = _qualityMap.entries
          .firstWhere(
            (e) => e.value == _effectiveVideoUrl,
            orElse: () => _qualityMap.entries.first,
          )
          .key;
    }

    if (_looksLikeDirectVideoUrl(_effectiveVideoUrl)) {
      _initPlayer();
    } else if (widget.threadId != null && widget.threadId!.isNotEmpty) {
      _fetchAndPlayVideoByThreadId(widget.threadId!);
    } else {
      _initPlayer();
    }
  }

  bool _looksLikeDirectVideoUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.endsWith(".jpg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".webp") ||
        lower.endsWith(".gif")) {
      return false;
    }
    return lower.contains(".mp4") ||
        lower.contains("video") ||
        lower.contains(".m3u8") ||
        lower.contains(".flv");
  }

  Future<void> _fetchAndPlayVideoByThreadId(String tid) async {
    setState(() {
      _isLoadingDynamic = true;
      _hasError = false;
    });

    try {
      final dio = Dio();
      final params = <String, dynamic>{
        "kz": tid,
        "pn": "1",
        "rn": "2",
        "_client_version": "12.65.1.0",
        "_client_type": "2",
        "from": "baidu_appstore",
      };
      params["sign"] = SignInterceptor.calculateSign(params);
      final res = await dio.post(
        "https://c.tieba.baidu.com/c/f/pb/page",
        data: params,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = res.data;
      if (data is Map) {
        String? foundVideoUrl;
        final threadMap = data["thread"] as Map<String, dynamic>?;
        if (threadMap != null) {
          final vi = threadMap["video_info"];
          if (vi is Map) {
            foundVideoUrl =
                vi["video_url"]?.toString() ??
                vi["vurl"]?.toString() ??
                vi["video_res_url"]?.toString();
          }
        }
        if (foundVideoUrl == null || foundVideoUrl.isEmpty) {
          final postList = data["post_list"] as List? ?? [];
          if (postList.isNotEmpty) {
            final firstPost = postList[0] as Map<String, dynamic>?;
            final content = firstPost?["content"] as List? ?? [];
            for (var c in content) {
              if (c is Map &&
                  (c["type"] == 3 || c["type"] == "3" || c["type"] == 5)) {
                foundVideoUrl =
                    c["vurl"]?.toString() ??
                    c["video_url"]?.toString() ??
                    c["link"]?.toString();
                if (foundVideoUrl != null && foundVideoUrl.isNotEmpty) break;
              }
            }
          }
        }
        if (foundVideoUrl != null && foundVideoUrl.isNotEmpty) {
          _effectiveVideoUrl = foundVideoUrl;
          _qualityMap["高清"] = foundVideoUrl;
          if (mounted) setState(() => _isLoadingDynamic = false);
          _initPlayer(overrideUrl: foundVideoUrl);
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingDynamic = false);
      _initPlayer();
    }
  }

  Future<void> _initPlayer({
    String? overrideUrl,
    Duration? startPosition,
    bool autoPlay = true,
  }) async {
    final targetUrl = overrideUrl ?? _effectiveVideoUrl;
    if (targetUrl.isEmpty || !_looksLikeDirectVideoUrl(targetUrl)) {
      if (widget.threadId != null && !_isLoadingDynamic) {
        _fetchAndPlayVideoByThreadId(widget.threadId!);
        return;
      }
      if (mounted) setState(() => _hasError = true);
      return;
    }

    _effectiveVideoUrl = targetUrl;
    String primaryUrl = targetUrl.trim();
    String fallbackUrl = primaryUrl.startsWith("http://")
        ? primaryUrl.replaceFirst("http://", "https://")
        : primaryUrl.replaceFirst("https://", "http://");

    try {
      if (mounted) {
        setState(() {
          _hasError = false;
          _isInitialized = false;
        });
      }

      await _controller?.dispose();
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(primaryUrl),
        httpHeaders: const {
          "User-Agent": "bdtb for Android 12.41.7.1",
          "Referer": "https://tieba.baidu.com/",
        },
      );

      try {
        await _controller!.initialize();
      } catch (_) {
        // Fallback to alternate protocol (http vs https)
        await _controller?.dispose();
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(fallbackUrl),
          httpHeaders: const {
            "User-Agent": "bdtb for Android 12.41.7.1",
            "Referer": "https://tieba.baidu.com/",
          },
        );
        await _controller!.initialize();
        _effectiveVideoUrl = fallbackUrl;
      }

      if (startPosition != null && startPosition > Duration.zero) {
        await _controller!.seekTo(startPosition);
      }
      await _controller!.setPlaybackSpeed(_playbackSpeed);

      if (autoPlay) {
        await _controller!.play();
      }

      _controller!.addListener(_onPlayerUpdate);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedbackUtil.light();
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  void _startFastForward() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedbackUtil.medium();
    setState(() {
      _isFastForwarding = true;
    });
    _controller!.setPlaybackSpeed(2.0);
  }

  void _stopFastForward() {
    if (_controller == null || !_isInitialized) return;
    if (_isFastForwarding) {
      HapticFeedbackUtil.light();
      setState(() {
        _isFastForwarding = false;
      });
      _controller!.setPlaybackSpeed(_playbackSpeed);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_controller == null || !_isInitialized) return;
    _activePointers++;
    _pressTimer?.cancel();
    // 按住超过 250ms 即进入 2.0X 快进模式
    _pressTimer = Timer(const Duration(milliseconds: 250), () {
      if (_activePointers > 0 && mounted) {
        _startFastForward();
      }
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
    _pressTimer?.cancel();
    if (_isFastForwarding) {
      // 松开手指立即恢复正常播放倍速
      _stopFastForward();
    } else if (_activePointers == 0) {
      // 快速轻触 (< 250ms)：切换顶部与底部控制栏显隐
      setState(() {
        _showControls = !_showControls;
      });
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
    _pressTimer?.cancel();
    if (_isFastForwarding) {
      _stopFastForward();
    }
  }

  void _showSpeedBottomSheet() {
    HapticFeedbackUtil.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "选择播放倍速",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._availableSpeeds.map((s) {
                  final isSelected = (_playbackSpeed == s);
                  return ListTile(
                    title: Text(
                      "${s}X",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.amberAccent : Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    onTap: () {
                      HapticFeedbackUtil.light();
                      setState(() {
                        _playbackSpeed = s;
                      });
                      _controller?.setPlaybackSpeed(s);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQualityBottomSheet() {
    if (_qualityMap.isEmpty) return;
    HapticFeedbackUtil.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "选择视频画质",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._qualityMap.keys.map((q) {
                  final isSelected = (_currentQuality == q);
                  return ListTile(
                    title: Text(
                      q,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.amberAccent : Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    onTap: () {
                      HapticFeedbackUtil.light();
                      final newUrl = _qualityMap[q];
                      if (newUrl != null && q != _currentQuality) {
                        final currentPos =
                            _controller?.value.position ?? Duration.zero;
                        setState(() {
                          _currentQuality = q;
                        });
                        _initPlayer(
                          overrideUrl: newUrl,
                          startPosition: currentPos,
                          autoPlay: _controller?.value.isPlaying ?? true,
                        );
                      }
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, "0");
    if (d.inHours > 0) {
      return "${d.inHours}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. 视频渲染层 (或加载指示)
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_hasError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white70,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "视频加载失败或链接已失效",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () {
                        setState(() => _hasError = false);
                        if (widget.threadId != null) {
                          _fetchAndPlayVideoByThreadId(widget.threadId!);
                        } else {
                          _initPlayer();
                        }
                      },
                      child: const Text("重试"),
                    ),
                  ],
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),

            // 2. 长按加速浮动指示胶囊 (按住才显示，松手秒隐藏)
            if (_isFastForwarding)
              Positioned(
                top: MediaQuery.of(context).padding.top + 50,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fast_forward_rounded,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "2.0X 倍速快进中",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 3. 顶部导航与保存视频栏 (高反差圆底，任何背景均清晰醒目)
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 12,
                    right: 12,
                    bottom: 16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black87,
                        Colors.black38,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // 左上角返回按钮
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.title != null &&
                                widget.title!.isNotEmpty)
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (widget.authorName != null &&
                                widget.authorName!.isNotEmpty)
                              Text(
                                "@${widget.authorName!}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // 右上角保存视频按钮
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: "保存视频",
                          onPressed: () {
                            if (_effectiveVideoUrl.isNotEmpty) {
                              MediaSaveService.saveVideo(
                                context,
                                _effectiveVideoUrl,
                                folderName: widget.authorName,
                              );
                            } else if (widget.coverUrl != null &&
                                widget.coverUrl!.isNotEmpty) {
                              MediaSaveService.saveImage(
                                context,
                                widget.coverUrl!,
                                folderName: widget.authorName,
                              );
                            } else {
                              AppToast.show(context, "暂无可保存的视频资源");
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. 底部播放控制面板
            if (_showControls && _isInitialized && _controller != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 8,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 进度条
                      Row(
                        children: [
                          Text(
                            _formatDuration(_controller!.value.position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6.0,
                                ),
                                activeTrackColor: Colors.amberAccent,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.amberAccent,
                              ),
                              child: Slider(
                                value: _controller!
                                    .value
                                    .position
                                    .inMilliseconds
                                    .toDouble(),
                                min: 0.0,
                                max: _controller!.value.duration.inMilliseconds
                                    .toDouble(),
                                onChanged: (value) {
                                  _controller!.seekTo(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(_controller!.value.duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 底部按钮控制栏 (播放/暂停、清晰度选择、倍速选择)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _controller!.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          const Spacer(),

                          // 清晰度按钮
                          if (_qualityMap.length > 1)
                            TextButton(
                              onPressed: _showQualityBottomSheet,
                              child: Text(
                                _currentQuality,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          // 倍速按钮
                          TextButton(
                            onPressed: _showSpeedBottomSheet,
                            child: Text(
                              _playbackSpeed == 1.0
                                  ? "倍速"
                                  : "${_playbackSpeed}X",
                              style: TextStyle(
                                color: _playbackSpeed == 1.0
                                    ? Colors.white
                                    : Colors.amberAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

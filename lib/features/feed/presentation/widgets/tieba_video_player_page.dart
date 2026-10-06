import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:video_player/video_player.dart";

import "../../../../core/network/sign_interceptor.dart";
import "../../../../core/services/media_save_service.dart";
import "../../../../core/services/share_service.dart";
import "../../../../core/utils/app_toast.dart";
import "../../../../core/utils/haptic_feedback_util.dart";

enum _DragMode { none, brightness, volume }

enum _HudType { none, brightness, volume, seek }

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
  static const MethodChannel _mediaChannel = MethodChannel("com.lurk/app");

  VideoPlayerController? _controller;
  int _playerLoadId = 0;
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
  Timer? _hideControlsTimer;
  Timer? _hudDismissTimer;
  final Set<int> _fastForwardPointers = {};
  bool _fastForwardGestureConsumed = false;
  bool _isLandscape = false;
  bool _brightnessChanged = false;
  Offset _lastTapDownPosition = Offset.zero;
  Offset _panStartPosition = Offset.zero;
  _DragMode _dragMode = _DragMode.none;
  _HudType _hudType = _HudType.none;
  double _startBrightness = 0.5;
  double _currentBrightness = 0.5;
  double _startVolume = 0.5;
  double _currentVolume = 0.5;
  double _hudValue = 0.5;
  int _hudSeekDiff = 0;
  Duration _targetSeekPosition = Duration.zero;

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
    _initDeviceLevels();
    _resetControlsTimer();
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

    final loadId = ++_playerLoadId;
    final previousController = _controller;
    _controller = null;
    _effectiveVideoUrl = targetUrl;
    final primaryUrl = targetUrl.trim();
    final fallbackUrl = primaryUrl.startsWith("http://")
        ? primaryUrl.replaceFirst("http://", "https://")
        : primaryUrl.replaceFirst("https://", "http://");

    setState(() {
      _hasError = false;
      _isInitialized = false;
    });

    VideoPlayerController? controller;
    try {
      await previousController?.dispose();
      if (!mounted || loadId != _playerLoadId) return;

      controller = VideoPlayerController.networkUrl(
        Uri.parse(primaryUrl),
        httpHeaders: const {
          "User-Agent": "bdtb for Android 12.41.7.1",
          "Referer": "https://tieba.baidu.com/",
        },
      );
      _controller = controller;

      try {
        await controller.initialize();
      } catch (_) {
        // Fallback to alternate protocol (http vs https)
        if (!mounted ||
            loadId != _playerLoadId ||
            !identical(_controller, controller)) {
          return;
        }
        await controller.dispose();
        if (!mounted || loadId != _playerLoadId) return;
        controller = VideoPlayerController.networkUrl(
          Uri.parse(fallbackUrl),
          httpHeaders: const {
            "User-Agent": "bdtb for Android 12.41.7.1",
            "Referer": "https://tieba.baidu.com/",
          },
        );
        _controller = controller;
        await controller.initialize();
        _effectiveVideoUrl = fallbackUrl;
      }

      if (!mounted ||
          loadId != _playerLoadId ||
          !identical(_controller, controller)) {
        return;
      }
      if (startPosition != null && startPosition > Duration.zero) {
        await controller.seekTo(startPosition);
      }
      if (!mounted ||
          loadId != _playerLoadId ||
          !identical(_controller, controller)) {
        return;
      }
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.setVolume(_currentVolume);

      if (autoPlay) {
        await controller.play();
      }
      if (!mounted ||
          loadId != _playerLoadId ||
          !identical(_controller, controller)) {
        return;
      }

      controller.addListener(_onPlayerUpdate);
      setState(() => _isInitialized = true);
      _resetControlsTimer();
    } catch (_) {
      if (!mounted ||
          loadId != _playerLoadId ||
          !identical(_controller, controller)) {
        return;
      }
      setState(() {
        _hasError = true;
        _isInitialized = false;
      });
    }
  }

  Future<void> _initDeviceLevels() async {
    try {
      final brightness = await _mediaChannel.invokeMethod<double>(
        "getBrightness",
      );
      if (!mounted) return;
      if (brightness != null) {
        setState(() => _currentBrightness = brightness);
      }
    } catch (_) {}
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _playerLoadId++;
    _pressTimer?.cancel();
    _hideControlsTimer?.cancel();
    _hudDismissTimer?.cancel();
    if (_isLandscape) _restorePortraitAndSystemUI();
    if (_brightnessChanged) {
      unawaited(
        _mediaChannel.invokeMethod<void>("resetBrightness").catchError((_) {}),
      );
    }
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedbackUtil.light();
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _showControls = true);
    } else {
      _controller!.play();
      setState(() {});
      _resetControlsTimer();
    }
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
    if (!_isFastForwarding) return;
    HapticFeedbackUtil.light();
    setState(() => _isFastForwarding = false);
    _controller?.setPlaybackSpeed(_playbackSpeed);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_controller == null || !_isInitialized) return;
    if (!_isFastForwarding) _fastForwardGestureConsumed = false;
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (event.localPosition.dx >= screenWidth * 0.45 &&
        event.localPosition.dx <= screenWidth * 0.55) {
      return;
    }
    _fastForwardPointers.add(event.pointer);
    _pressTimer?.cancel();
    // 按住超过 250ms 即进入 2.0X 快进模式
    _pressTimer = Timer(const Duration(milliseconds: 250), () {
      if (_fastForwardPointers.isNotEmpty && mounted) {
        _fastForwardGestureConsumed = true;
        _startFastForward();
      }
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    _fastForwardPointers.remove(event.pointer);
    if (_fastForwardPointers.isEmpty) {
      _pressTimer?.cancel();
      _stopFastForward();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _fastForwardPointers.remove(event.pointer);
    if (_fastForwardPointers.isEmpty) {
      _pressTimer?.cancel();
      _stopFastForward();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _resetControlsTimer();
  }

  void _resetControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls && _controller?.value.isPlaying == true) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _controller?.value.isPlaying == true) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _restorePortraitAndSystemUI() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _toggleOrientation() {
    final nextLandscape = !_isLandscape;
    setState(() => _isLandscape = nextLandscape);
    if (nextLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _restorePortraitAndSystemUI();
    }
    _resetControlsTimer();
  }

  void _seekRelative(int deltaSeconds) {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    HapticFeedbackUtil.light();
    final current = controller.value.position;
    final duration = controller.value.duration;
    final target = Duration(
      seconds: (current.inSeconds + deltaSeconds).clamp(0, duration.inSeconds),
    );
    controller.seekTo(target);
    _showHud(type: _HudType.seek, diff: deltaSeconds, target: target);
  }

  void _setBrightness(double value) {
    _brightnessChanged = true;
    _currentBrightness = value;
    unawaited(
      _mediaChannel
          .invokeMethod<void>("setBrightness", {"brightness": value})
          .catchError((_) {}),
    );
  }

  void _setVolume(double value) {
    _currentVolume = value;
    final controller = _controller;
    if (controller != null) unawaited(controller.setVolume(value));
  }

  void _showHud({
    required _HudType type,
    double value = 0,
    int diff = 0,
    Duration target = Duration.zero,
    int autoDismissMs = 600,
  }) {
    _hudDismissTimer?.cancel();
    setState(() {
      _hudType = type;
      _hudValue = value;
      _hudSeekDiff = diff;
      _targetSeekPosition = target;
    });
    if (autoDismissMs > 0) {
      _hudDismissTimer = Timer(Duration(milliseconds: autoDismissMs), () {
        if (mounted) setState(() => _hudType = _HudType.none);
      });
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _panStartPosition = details.localPosition;
    _dragMode = _DragMode.none;
    _startBrightness = _currentBrightness;
    _startVolume = _currentVolume;
  }

  void _onVerticalDragUpdate(
    DragUpdateDetails details,
    double screenWidth,
    double screenHeight,
  ) {
    final dx = details.localPosition.dx - _panStartPosition.dx;
    final dy = details.localPosition.dy - _panStartPosition.dy;
    if (_dragMode == _DragMode.none && dy.abs() > 14 && dy.abs() > dx.abs()) {
      _dragMode = _panStartPosition.dx < screenWidth / 2
          ? _DragMode.brightness
          : _DragMode.volume;
    }

    final delta = -dy / (screenHeight * 0.65);
    if (_dragMode == _DragMode.brightness) {
      final value = (_startBrightness + delta).clamp(0.01, 1.0);
      _setBrightness(value);
      _showHud(type: _HudType.brightness, value: value, autoDismissMs: 0);
    } else if (_dragMode == _DragMode.volume) {
      final value = (_startVolume + delta).clamp(0.0, 1.0);
      _setVolume(value);
      _showHud(type: _HudType.volume, value: value, autoDismissMs: 0);
    }
  }

  void _onVerticalDragEnd() {
    final type = _hudType;
    _dragMode = _DragMode.none;
    if (type != _HudType.none) _showHud(type: type, value: _hudValue);
  }

  Future<void> _shareVideo() async {
    final threadId = widget.threadId;
    if (threadId == null || threadId.isEmpty) {
      AppToast.show(context, "暂无可分享的帖子链接");
      return;
    }
    final title = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : "贴吧视频";
    await ShareService.shareTextContent(
      context,
      text: "$title\nhttps://tieba.baidu.com/p/$threadId",
      title: title,
      fallbackMessage: "视频链接已复制到剪贴板",
    );
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

  Widget _buildGestureHud() {
    final (icon, label, value) = switch (_hudType) {
      _HudType.brightness => (
        Icons.brightness_6_rounded,
        "亮度 ${(_hudValue * 100).round()}%",
        _hudValue,
      ),
      _HudType.volume => (
        Icons.volume_up_rounded,
        "音量 ${(_hudValue * 100).round()}%",
        _hudValue,
      ),
      _HudType.seek => (
        _hudSeekDiff >= 0 ? Icons.forward_10_rounded : Icons.replay_10_rounded,
        "${_hudSeekDiff > 0 ? '+' : ''}$_hudSeekDiff 秒  ${_formatDuration(_targetSeekPosition)}",
        null,
      ),
      _ => (Icons.play_arrow_rounded, "", null),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          if (value != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLandscape,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isLandscape) _toggleOrientation();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
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

            if (_isInitialized && _controller != null)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _handlePointerDown,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _lastTapDownPosition = details.localPosition;
                    },
                    onTap: () {
                      if (_fastForwardGestureConsumed) return;
                      _toggleControls();
                    },
                    onDoubleTapDown: (details) {
                      _lastTapDownPosition = details.localPosition;
                    },
                    onDoubleTap: () {
                      final x = _lastTapDownPosition.dx;
                      final width = MediaQuery.sizeOf(context).width;
                      if (x < width * 0.35) {
                        _seekRelative(-10);
                      } else if (x > width * 0.65) {
                        _seekRelative(10);
                      } else {
                        _togglePlayPause();
                      }
                    },
                    onVerticalDragStart: _onVerticalDragStart,
                    onVerticalDragUpdate: (details) => _onVerticalDragUpdate(
                      details,
                      MediaQuery.sizeOf(context).width,
                      MediaQuery.sizeOf(context).height,
                    ),
                    onVerticalDragEnd: (_) => _onVerticalDragEnd(),
                    child: const SizedBox.expand(),
                  ),
                ),
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
                          onPressed: _isLandscape
                              ? _toggleOrientation
                              : () => Navigator.pop(context),
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
                            Icons.share_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                          tooltip: "分享视频",
                          onPressed: _shareVideo,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          IconButton(
                            tooltip: _isLandscape ? "退出横屏" : "横屏播放",
                            icon: Icon(
                              _isLandscape
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              color: Colors.white,
                            ),
                            onPressed: _toggleOrientation,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_hudType != _HudType.none)
              Positioned.fill(
                child: IgnorePointer(child: Center(child: _buildGestureHud())),
              ),
          ],
        ),
      ),
    );
  }
}

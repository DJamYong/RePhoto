import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../services/motion_photo_service.dart';
import '../widgets/live_dashed_circle_painter.dart';

/// 全屏照片查看页 — 双指缩放/旋转/平移 + 双击缩放
class PhotoFullscreenPage extends StatefulWidget {
  final AssetEntity photo;

  const PhotoFullscreenPage({super.key, required this.photo});

  @override
  State<PhotoFullscreenPage> createState() => _PhotoFullscreenPageState();
}

class _PhotoFullscreenPageState extends State<PhotoFullscreenPage>
    with TickerProviderStateMixin {
  Uint8List? _imageBytes;
  bool _isLoading = true;

  // ── 变换状态 ──
  double _scale = 1.0;
  double _rotation = 0.0;
  Offset _translation = Offset.zero;

  // 手势起始快照
  double _baseScale = 1.0;
  double _baseRotation = 0.0;
  // ── 动画 ──
  late final AnimationController _animCtrl;
  Animation<double>? _animScale;
  Animation<double>? _animRot;
  Animation<double>? _animTx;
  Animation<double>? _animTy;

  // ── 上划退出 ──
  bool _gestureStartInDefault = false;
  bool _isDismissing = false;
  double _dismissDy = 0.0;

  // ── Live Photo ──
  bool _isLivePhoto = false;
  VideoPlayerController? _videoCtrl;
  bool _isPlayingLive = false;

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(() => setState(() {}));

  // ── UI ──
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animCtrl.addListener(_onAnimTick);
    _loadImage();
    _initLivePhoto();
  }

  @override
  void dispose() {
    _animCtrl.removeListener(_onAnimTick);
    _animCtrl.dispose();
    _fadeCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.photo.thumbnailDataWithSize(
        const ThumbnailSize(1920, 1920),
        quality: 95,
      );
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── 动画回调（唯一的 listener，不累积） ──

  void _onAnimTick() {
    setState(() {
      if (_animScale != null) _scale = _animScale!.value;
      if (_animRot != null) _rotation = _animRot!.value;
      if (_animTx != null) _translation = Offset(_animTx!.value, _translation.dy);
      if (_animTy != null) _translation = Offset(_translation.dx, _animTy!.value);
      if (_animDismissDy != null) _dismissDy = _animDismissDy!.value;
    });
  }
  Animation<double>? _animDismissDy;

  // ── 手势 ──

  // 判断是否处于默认状态（未缩放/未旋转/未平移）
  bool get _isInDefaultState =>
      (_scale - 1.0).abs() < 0.05 &&
      _rotation.abs() < 0.01 &&
      _translation.dx.abs() < 2.0 &&
      _translation.dy.abs() < 2.0;

  void _onScaleStart(ScaleStartDetails d) {
    // 播放中做任何手势都退出播放
    if (_isPlayingLive) { _stopLivePlayback(); return; }

    _baseScale = _scale;
    _baseRotation = _rotation;
    // 清除动画引用，防止 onAnimTick 读到过期值
    _animScale = null;
    _animRot = null;
    _animTx = null;
    _animTy = null;
    _animDismissDy = null;
    _animCtrl.stop();

    // 记录手势开始时是否处于默认状态（用于上划退出判断）
    _gestureStartInDefault = _isInDefaultState;
    _isDismissing = false;
    _dismissDy = 0.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // 单指 + 默认状态 + 纵向滑动 → 进入上划退出模式
    if (!_isDismissing &&
        _gestureStartInDefault &&
        d.pointerCount == 1 &&
        d.focalPointDelta.dy.abs() > d.focalPointDelta.dx.abs() * 1.2) {
      _isDismissing = true;
    }

    if (_isDismissing) {
      setState(() {
        _dismissDy += d.focalPointDelta.dy;
      });
      return;
    }

    // 正常缩放/旋转/平移（默认状态下禁止单指平移）
    setState(() {
      _scale = (_baseScale * d.scale).clamp(0.3, 6.0);
      _rotation = _baseRotation + d.rotation;
      // 默认状态下不响应单指拖动；缩放/旋转后才允许平移
      if (!_gestureStartInDefault || d.scale != 1.0) {
        _translation += d.focalPointDelta;
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_isDismissing) {
      // 上划/下滑距离 > 100px 或速度 > 500 px/s → 退出
      final shouldDismiss =
          _dismissDy.abs() > 100 || d.velocity.pixelsPerSecond.dy.abs() > 500;
      if (shouldDismiss) {
        Navigator.of(context).pop();
      } else {
        // 未达到阈值 → 动画回弹
        _animateDismissBack();
      }
      return;
    }

    if (_scale < 0.3) _animateReset();
  }

  void _animateDismissBack() {
    _animDismissDy = Tween<double>(begin: _dismissDy, end: 0)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _isDismissing = false;
          _dismissDy = 0.0;
          _animDismissDy = null;
        });
      }
    });
  }


  // ── 双击 ──

  void _onDoubleTap() {
    if (_isInDefaultState) {
      _animateTo(scale: 2.8, rotation: 0, translation: Offset.zero);
    } else {
      _animateReset();
    }
  }

  void _animateReset() {
    _animateTo(scale: 1, rotation: 0, translation: Offset.zero);
  }

  void _animateTo({
    required double scale,
    required double rotation,
    required Offset translation,
  }) {
    _animScale = Tween<double>(begin: _scale, end: scale)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animRot = Tween<double>(begin: _rotation, end: rotation)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animTx = Tween<double>(begin: _translation.dx, end: translation.dx)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animTy = Tween<double>(begin: _translation.dy, end: translation.dy)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _animCtrl.forward(from: 0);
  }

  void _onTap() {
    if (_isPlayingLive) { _stopLivePlayback(); return; }
    setState(() => _showUI = !_showUI);
  }

  // ── Live Photo ──

  Future<void> _initLivePhoto() async {
    final isMotion = await MotionPhotoService.isMotionPhoto(
      photoId: widget.photo.id,
      isLivePhotoIOS: widget.photo.isLivePhoto,
      mimeType: widget.photo.mimeType,
    );
    if (!isMotion || !mounted) return;

    _isLivePhoto = true;
    setState(() {});

    try {
      VideoPlayerController? ctrl;
      if (widget.photo.isLivePhoto) {
        // iOS: getMediaUrl 返回 file:// 本地 MOV 路径
        final url = await widget.photo.getMediaUrl();
        if (url != null) {
          final uri = Uri.parse(url);
          if (uri.scheme == 'file') {
            ctrl = VideoPlayerController.file(File.fromUri(uri));
          } else {
            ctrl = VideoPlayerController.networkUrl(uri);
          }
        }
      } else {
        debugPrint('[LIVE] extracting video for id=${widget.photo.id}');
        final debugInfo = await MotionPhotoService.debugCheck(widget.photo.id);
        debugPrint('[LIVE] debugInfo=$debugInfo');
        final videoUri = await MotionPhotoService.extractMotionVideo(widget.photo.id);
        debugPrint('[LIVE] videoUri=$videoUri');
        if (videoUri != null) {
          if (videoUri.startsWith('content://')) {
            ctrl = VideoPlayerController.contentUri(Uri.parse(videoUri));
          } else {
            debugPrint('[LIVE] temp file size=${File(videoUri).lengthSync()}');
            ctrl = VideoPlayerController.file(File(videoUri));
          }
        }
      }
      if (ctrl == null || !mounted) {
        debugPrint('[LIVE] ctrl is null — cannot play');
        return;
      }
      _videoCtrl = ctrl;
      await ctrl.initialize();

      // 视频播完：还在长按就停在最后一帧，松手才退出
      final videoCtrl = ctrl;
      videoCtrl.addListener(() {
        if (videoCtrl.value.isCompleted && mounted) {
          _onLiveVideoCompleted(videoCtrl);
        }
      });

      if (mounted) setState(() {});
    } catch (_) {
      // 视频初始化失败，静默降级
    }
  }

  /// 长按 → 播放动图（淡入）
  void _onLongPress() {
    if (!_isLivePhoto) return;
    if (!_isInDefaultState) return;
    final ctrl = _videoCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    setState(() => _isPlayingLive = true);
    _fadeCtrl.forward();
    ctrl.play();
  }

  /// 松手 → 淡出回到静态图
  Future<void> _stopLivePlayback() async {
    if (!_isPlayingLive) return;
    _isPlayingLive = false;
    _fadeCtrl.reverse();
    if (mounted) setState(() {});
    final ctrl = _videoCtrl;
    if (ctrl != null) {
      ctrl.pause();
      await ctrl.seekTo(Duration.zero);
    }
  }

  void _onLiveVideoCompleted(VideoPlayerController ctrl) {
    if (!_isPlayingLive) return;
    ctrl.pause();
    ctrl.seekTo(Duration.zero);
  }

  // ── 构建 ──

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // 上划退出进度 0→1：影响透明度
    final dismissProgress =
        (_isDismissing ? (_dismissDy.abs() / screenHeight).clamp(0.0, 1.0) : 0.0);
    final photoOpacity = (1.0 - dismissProgress * 1.2).clamp(0.0, 1.0);
    final uiOpacity = _showUI && !_isDismissing ? 1.0 : 0.0;

    final transform = Matrix4.identity()
      ..translateByDouble(
          _translation.dx,
          _translation.dy + (_isDismissing ? _dismissDy : 0),
          0, 1)
      ..rotateZ(_rotation)
      ..scaleByDouble(_scale, _scale, 1, 1);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 照片（全屏显示，上划退出时跟随移动 + 淡出）
          if (_imageBytes != null)
            Center(
              child: Opacity(
                opacity: photoOpacity,
                child: Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: Hero(
                    tag: 'photo_${widget.photo.id}',
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

          // 黑底 + 视频层（显式 AnimationController 驱动淡入淡出）
          if (_videoCtrl != null && _videoCtrl!.value.isInitialized) ...[
            Positioned.fill(
              child: Opacity(
                opacity: _fadeCtrl.value,
                child: Container(color: Colors.black),
              ),
            ),
            Center(
              child: Opacity(
                opacity: _fadeCtrl.value,
                child: Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: AspectRatio(
                    aspectRatio: _videoCtrl!.value.aspectRatio > 0
                        ? _videoCtrl!.value.aspectRatio
                        : 1.0,
                    child: VideoPlayer(_videoCtrl!),
                  ),
                ),
              ),
            ),
          ],

          // 手势控制层（铺满全屏，留出系统手势边距，透明响应）
          if (_imageBytes != null)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 12, right: 12, top: 40, bottom: 20,
                ),
                child: Listener(
                  onPointerUp: (_) {
                    if (_isPlayingLive) _stopLivePlayback();
                  },
                  child: GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    onDoubleTap: _onDoubleTap,
                    onTap: _onTap,
                    onLongPress: _isLivePhoto ? _onLongPress : null,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),

          // 加载/错误状态
          if (_imageBytes == null)
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white54, strokeWidth: 2)
                  : const Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 48),
            ),

          // 顶部按钮 + 日期 + Live 标识
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0, right: 0,
            child: AnimatedOpacity(
              opacity: uiOpacity,
              duration: const Duration(milliseconds: 150),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 日期居中
                  Text(
                    _formatDate(widget.photo.createDateTime),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, letterSpacing: 1),
                  ),
                  // 左侧：关闭 + LIVE 标识
                  Positioned(
                    left: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        if (_isLivePhoto)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12, height: 12,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 外圈虚线圆
                                CustomPaint(
                                  size: const Size(12, 12),
                                  painter: LiveDashedCirclePainter(
                                    color: Colors.white54,
                                    strokeWidth: 1,
                                  ),
                                ),
                                // 内圈实线圆
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white54,
                                        width: 1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部提示
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0, right: 0,
            child: AnimatedOpacity(
              opacity: uiOpacity,
              duration: const Duration(milliseconds: 150),
              child: Center(
                child: Text(
                  '上下划退出 · 双指缩放/旋转',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12, letterSpacing: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

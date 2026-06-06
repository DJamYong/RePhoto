import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// 全屏照片查看页 — 双指缩放/旋转/平移 + 双击缩放
class PhotoFullscreenPage extends StatefulWidget {
  final AssetEntity photo;

  const PhotoFullscreenPage({super.key, required this.photo});

  @override
  State<PhotoFullscreenPage> createState() => _PhotoFullscreenPageState();
}

class _PhotoFullscreenPageState extends State<PhotoFullscreenPage>
    with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _animCtrl.removeListener(_onAnimTick);
    _animCtrl.dispose();
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

    // 正常缩放/旋转/平移
    setState(() {
      _scale = (_baseScale * d.scale).clamp(0.3, 6.0);
      _rotation = _baseRotation + d.rotation;
      _translation += d.focalPointDelta;
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_isDismissing) {
      // 上划距离 > 100px 或 上划速度 > 500 px/s → 退出
      final shouldDismiss =
          _dismissDy < -100 || d.velocity.pixelsPerSecond.dy < -500;
      if (shouldDismiss) {
        Navigator.of(context).pop();
      } else {
        // 未达到阈值 → 动画回弹
        _animateDismissBack();
      }
      return;
    }

    if (_scale < 0.25) _animateReset();
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

  void _onTap() => setState(() => _showUI = !_showUI);

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

          // 手势控制层（铺满全屏，留出系统手势边距，透明响应）
          if (_imageBytes != null)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 12, right: 12, top: 40, bottom: 20,
                ),
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  onDoubleTap: _onDoubleTap,
                  onTap: _onTap,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
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

          // 顶部按钮 + 日期
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0, right: 0,
            child: AnimatedOpacity(
              opacity: uiOpacity,
              duration: const Duration(milliseconds: 150),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(widget.photo.createDateTime),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, letterSpacing: 1),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
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
              child: const Center(
                child: Text(
                  '上划退出 · 双指缩放/旋转',
                  style: TextStyle(
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';

class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  static const _videoAsset = 'assets/videos/mascot_intro.mp4';

  VideoPlayerController? _controller;
  Timer? _finishTimer;
  bool _ready = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVideo());
  }

  Future<void> _loadVideo() async {
    final controller = VideoPlayerController.asset(_videoAsset);
    _controller = controller;

    try {
      await controller.initialize().timeout(const Duration(seconds: 4));
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (!mounted) return;

      controller.addListener(_handlePlayback);
      setState(() => _ready = true);

      unawaited(controller.play());
      final duration = controller.value.duration;
      if (duration > Duration.zero) {
        _finishTimer = Timer(
          duration + const Duration(milliseconds: 700),
          _goToAuth,
        );
      }
    } catch (_) {
      _goToAuth();
    }
  }

  void _handlePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;

    final almostDone = duration - const Duration(milliseconds: 120);
    if (controller.value.position >= almostDone) {
      _goToAuth();
    }
  }

  void _goToAuth() {
    if (_finished || !mounted) return;
    _finished = true;
    _finishTimer?.cancel();
    context.go('/auth');
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    final controller = _controller;
    controller?.removeListener(_handlePlayback);
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _IntroGradient(),
          if (_ready && _controller != null)
            _IntroVideo(controller: _controller!)
          else
            Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: tokens.primary,
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.space4),
                child: IconButton.filledTonal(
                  tooltip: 'Skip intro',
                  onPressed: _goToAuth,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroVideo extends StatelessWidget {
  const _IntroVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final videoSize = controller.value.size;
    final width = videoSize.width == 0 ? 9.0 : videoSize.width;
    final height = videoSize.height == 0 ? 16.0 : videoSize.height;

    return SizedBox.expand(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

class _IntroGradient extends StatelessWidget {
  const _IntroGradient();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: tokens.pageGradient),
    );
  }
}

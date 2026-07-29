import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ChatMediaViewerScreen extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String title;
  final bool isViewOnce;
  final Future<void> Function()? onViewed;

  const ChatMediaViewerScreen({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    required this.title,
    this.isViewOnce = false,
    this.onViewed,
  });

  @override
  State<ChatMediaViewerScreen> createState() => _ChatMediaViewerScreenState();
}

class _ChatMediaViewerScreenState extends State<ChatMediaViewerScreen> {
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;
  String? _videoError;
  bool _viewedCallbackTriggered = false;

  @override
  void initState() {
    super.initState();
    if (widget.isViewOnce && widget.onViewed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_markViewed());
      });
    }

    if (widget.mediaType == 'video') {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.mediaUrl),
      );
      final controller = _videoController!;
      _videoInitialization = controller.initialize().then((_) async {
        if (!mounted) return;
        await controller.setLooping(false);
        await controller.play();
        setState(() {});
      }).catchError((error) {
        _videoError = error.toString();
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _markViewed() async {
    if (_viewedCallbackTriggered) return;
    _viewedCallbackTriggered = true;
    try {
      await widget.onViewed?.call();
    } catch (_) {
      // If the message update fails, the viewer still stays usable.
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleVideoPlayback() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.mediaType == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          if (widget.isViewOnce)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.visibility_off_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: isVideo ? _buildVideoPlayer() : _buildImageViewer(),
        ),
      ),
    );
  }

  Widget _buildImageViewer() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Image.network(
          widget.mediaUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 220,
            height: 220,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 42),
            const SizedBox(height: 10),
            Text(
              _videoError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<void>(
      future: _videoInitialization,
      builder: (context, snapshot) {
        final controller = _videoController;
        if (snapshot.connectionState != ConnectionState.done ||
            controller == null ||
            !controller.value.isInitialized) {
          return const CircularProgressIndicator(color: Colors.white);
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _toggleVideoPlayback,
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(controller),
                      AnimatedOpacity(
                        opacity: controller.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.22),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white12,
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _toggleVideoPlayback,
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                label: Text(
                  controller.value.isPlaying ? 'Pause' : 'Play',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

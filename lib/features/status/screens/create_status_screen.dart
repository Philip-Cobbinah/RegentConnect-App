import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme.dart';
import '../../../models/group_model.dart';
import '../../../services/status_service.dart';

class CreateStatusScreen extends StatefulWidget {
  final String type;
  final XFile? mediaFile;

  const CreateStatusScreen({
    super.key,
    required this.type,
    this.mediaFile,
  });

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  static const double _maxVideoSeconds = 30;

  final StatusService _statusService = StatusService();
  final TextEditingController _textController = TextEditingController();

  Uint8List? _imageBytes;
  String? _cropSourcePath;
  String? _mediaName;
  String? _mediaMimeType;
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;
  String? _mediaError;
  bool _handlingVideoBoundary = false;
  bool _isPosting = false;
  bool _allowReshare = true;
  bool _isMuted = false;
  String _selectedColor = '#7C4DFF';
  double _trimStartSeconds = 0;
  double _trimEndSeconds = 0;
  String? _taggedGroupId;
  String? _taggedGroupName;
  String? _taggedGroupKind;

  final List<String> _backgroundColors = const [
    '#7C4DFF',
    '#FF5722',
    '#4CAF50',
    '#2196F3',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#FF9800',
  ];

  @override
  void initState() {
    super.initState();
    _cropSourcePath = widget.mediaFile?.path;
    _mediaName = widget.mediaFile?.name;
    _mediaMimeType =
        widget.mediaFile?.mimeType ?? _contentTypeFor(widget.mediaFile?.name);
    if (widget.type == 'image') {
      _loadImagePreview();
    } else if (widget.type == 'video') {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    final controller = _videoController;
    _videoController = null;
    controller?.removeListener(_enforceVideoSelection);
    controller?.dispose();
    super.dispose();
  }

  Future<void> _loadImagePreview() async {
    final media = widget.mediaFile;
    if (media == null) {
      setState(() => _mediaError = 'No image was selected.');
      return;
    }
    try {
      final bytes = await media.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mediaError = 'This image could not be opened.');
    }
  }

  Future<void> _initializeVideo() async {
    final media = widget.mediaFile;
    if (media == null) {
      setState(() => _mediaError = 'No video was selected.');
      return;
    }

    final controller = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(media.path))
        : VideoPlayerController.file(File(media.path));
    _videoController = controller;
    _videoInitialization = controller.initialize().then((_) async {
      final durationSeconds = controller.value.duration.inMilliseconds / 1000.0;
      _trimStartSeconds = 0;
      _trimEndSeconds = durationSeconds.clamp(0.0, _maxVideoSeconds).toDouble();
      await controller.setLooping(false);
      await controller.setVolume(_isMuted ? 0 : 1);
      controller.addListener(_enforceVideoSelection);
      if (_trimEndSeconds > 0) {
        await controller.play();
      }
      if (mounted) setState(() {});
    }).catchError((Object _) {
      if (mounted) {
        setState(() {
          _mediaError =
              'This video format cannot be previewed in the current browser.';
        });
      }
    });
  }

  void _enforceVideoSelection() {
    final controller = _videoController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _handlingVideoBoundary ||
        _trimEndSeconds <= _trimStartSeconds) {
      return;
    }
    final position = controller.value.position.inMilliseconds / 1000.0;
    if (position + 0.05 < _trimStartSeconds || position >= _trimEndSeconds) {
      _handlingVideoBoundary = true;
      controller
          .seekTo(
        Duration(
          milliseconds: (_trimStartSeconds * 1000).round(),
        ),
      )
          .then((_) async {
        if (!controller.value.isPlaying) {
          await controller.play();
        }
      }).whenComplete(() => _handlingVideoBoundary = false);
    }
  }

  Future<void> _cropImage() async {
    final sourcePath = _cropSourcePath;
    if (sourcePath == null) return;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit status photo',
            toolbarColor: RegentColors.primaryDark,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Edit status photo',
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 560, height: 560),
          ),
        ],
      );
      if (cropped == null) return;
      final bytes = await cropped.readAsBytes();
      if (!mounted) return;
      setState(() {
        _cropSourcePath = cropped.path;
        _imageBytes = bytes;
        _mediaName = 'status_photo.jpg';
        _mediaMimeType = 'image/jpeg';
        _mediaError = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The image editor could not open this file.'),
        ),
      );
    }
  }

  Future<void> _toggleMute() async {
    _isMuted = !_isMuted;
    await _videoController?.setVolume(_isMuted ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      final position = controller.value.position.inMilliseconds / 1000.0;
      if (position >= _trimEndSeconds || position < _trimStartSeconds) {
        await controller.seekTo(
          Duration(milliseconds: (_trimStartSeconds * 1000).round()),
        );
      }
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _postStatus() async {
    if (_isPosting) return;
    if (widget.type == 'text' && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type something for your status.')),
      );
      return;
    }
    if (widget.type != 'text' && widget.mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select media before posting.')),
      );
      return;
    }
    if (widget.type == 'video' &&
        (_videoController?.value.isInitialized != true ||
            _trimEndSeconds <= _trimStartSeconds)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the video preview to load.')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      StatusMediaUpload? mediaUpload;
      if (widget.type != 'text') {
        final bytes = _imageBytes ?? await widget.mediaFile!.readAsBytes();
        mediaUpload = await _statusService.uploadStatusMedia(
          bytes,
          type: widget.type,
          originalName: _mediaName ?? widget.mediaFile!.name,
          contentType: _mediaMimeType,
        );
        if (mediaUpload == null) {
          throw Exception('The media upload failed. Please try again.');
        }
      }

      final videoDuration = _videoController?.value.duration.inMilliseconds;
      await _statusService.postStatus(
        type: widget.type,
        text: _textController.text.trim().isNotEmpty
            ? _textController.text.trim()
            : null,
        mediaUrl: mediaUpload?.url,
        mediaStoragePath: mediaUpload?.storagePath,
        mediaSize: mediaUpload?.size,
        backgroundColor: _selectedColor,
        allowReshare: _allowReshare,
        isMuted: _isMuted,
        taggedGroupId: _taggedGroupId,
        trimStartMs:
            widget.type == 'video' ? (_trimStartSeconds * 1000).round() : null,
        trimEndMs:
            widget.type == 'video' ? (_trimEndSeconds * 1000).round() : null,
        mediaDurationMs: widget.type == 'video' ? videoDuration : null,
        mediaMimeType: mediaUpload?.contentType ?? _mediaMimeType,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Status posted!'),
          backgroundColor: RegentColors.statusAccent,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not post status: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.type == 'text'
          ? Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')))
          : RegentColors.dmBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          switch (widget.type) {
            'image' => 'Photo status',
            'video' => 'Video status',
            _ => 'Text status',
          },
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.type == 'image')
            IconButton(
              tooltip: 'Crop and rotate',
              onPressed: _imageBytes == null ? null : _cropImage,
              icon: const Icon(Icons.crop_rotate, color: Colors.white),
            ),
          if (widget.type != 'text')
            IconButton(
              tooltip: 'Add emoji',
              onPressed: _showEmojiPicker,
              icon: const Icon(
                Icons.emoji_emotions_outlined,
                color: Colors.white,
              ),
            ),
          if (widget.type == 'video')
            IconButton(
              tooltip: _isMuted ? 'Unmute video' : 'Mute video',
              onPressed: _toggleMute,
              icon: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: _isMuted ? Colors.redAccent : Colors.white,
              ),
            ),
          PopupMenuButton<bool>(
            tooltip: 'Status options',
            initialValue: _allowReshare,
            onSelected: (value) => setState(() => _allowReshare = value),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: !_allowReshare,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _allowReshare
                        ? Icons.repeat_on_rounded
                        : Icons.repeat_rounded,
                  ),
                  title: Text(
                    _allowReshare ? 'Resharing is on' : 'Resharing is off',
                  ),
                  subtitle: const Text('Tap to change'),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildGroupTagBar(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: RegentColors.primaryBright,
        onPressed: _isPosting ? null : _postStatus,
        icon: _isPosting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.send_rounded, color: Colors.white),
        label: Text(
          _isPosting ? 'Posting...' : 'Post',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (widget.type) {
      'text' => _buildTextStatus(),
      'image' => _buildImageStatus(),
      _ => _buildVideoStatus(),
    };
  }

  Widget _buildTextStatus() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _textController,
                autofocus: true,
                maxLength: 700,
                maxLines: null,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  counterStyle: TextStyle(color: Colors.white60),
                  hintText: 'Type a status...',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 24),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: _backgroundColors.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: isSelected ? 40 : 32,
                  height: isSelected ? 40 : 32,
                  decoration: BoxDecoration(
                    color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildImageStatus() {
    if (_mediaError != null) return _mediaErrorState(_mediaError!);
    final bytes = _imageBytes;
    if (bytes == null) {
      return const Center(
        child: CircularProgressIndicator(color: RegentColors.primaryBright),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
        Positioned(
          top: 12,
          left: 16,
          child: _editorHint(
            Icons.crop_rotate,
            'Crop, rotate, or change aspect ratio',
            _cropImage,
          ),
        ),
        _captionField(bottom: 18),
      ],
    );
  }

  Widget _buildVideoStatus() {
    if (_mediaError != null) return _mediaErrorState(_mediaError!);
    final controller = _videoController;
    final initialization = _videoInitialization;
    if (controller == null || initialization == null) {
      return const Center(
        child: CircularProgressIndicator(color: RegentColors.primaryBright),
      );
    }

    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(
              color: RegentColors.primaryBright,
            ),
          );
        }
        final durationSeconds =
            controller.value.duration.inMilliseconds / 1000.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
            Center(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  return IconButton.filledTonal(
                    tooltip: value.isPlaying ? 'Pause' : 'Play',
                    iconSize: 38,
                    onPressed: _togglePlayback,
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 84,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.content_cut_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Selected ${_formatSeconds(_trimStartSeconds)} – '
                            '${_formatSeconds(_trimEndSeconds)} '
                            '(${(_trimEndSeconds - _trimStartSeconds).toStringAsFixed(1)}s)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Text(
                          'Max 30s',
                          style: TextStyle(
                            color: RegentColors.lightViolet,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    RangeSlider(
                      min: 0,
                      max: durationSeconds > 0 ? durationSeconds : 0.1,
                      values: RangeValues(
                        _trimStartSeconds.clamp(0, durationSeconds),
                        _trimEndSeconds.clamp(0, durationSeconds),
                      ),
                      labels: RangeLabels(
                        _formatSeconds(_trimStartSeconds),
                        _formatSeconds(_trimEndSeconds),
                      ),
                      onChanged: (values) =>
                          _updateVideoSelection(values, durationSeconds),
                    ),
                  ],
                ),
              ),
            ),
            if (_isMuted)
              Positioned(
                top: 12,
                right: 16,
                child: _editorHint(
                  Icons.volume_off,
                  'Muted',
                  _toggleMute,
                ),
              ),
            _captionField(bottom: 18),
          ],
        );
      },
    );
  }

  void _updateVideoSelection(
    RangeValues values,
    double durationSeconds,
  ) {
    var start = values.start;
    var end = values.end;
    if (end - start > _maxVideoSeconds) {
      if ((start - _trimStartSeconds).abs() > (end - _trimEndSeconds).abs()) {
        end = (start + _maxVideoSeconds).clamp(0, durationSeconds);
      } else {
        start = (end - _maxVideoSeconds).clamp(0, durationSeconds);
      }
    }
    if (end - start < 0.5) {
      end = (start + 0.5).clamp(0, durationSeconds);
      start = (end - 0.5).clamp(0, durationSeconds);
    }
    setState(() {
      _trimStartSeconds = start;
      _trimEndSeconds = end;
    });
    _videoController?.seekTo(
      Duration(milliseconds: (start * 1000).round()),
    );
  }

  Widget _captionField({required double bottom}) {
    return Positioned(
      bottom: bottom,
      left: 16,
      right: 92,
      child: TextField(
        controller: _textController,
        maxLength: 700,
        maxLines: 3,
        minLines: 1,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Add a caption...',
          hintStyle: const TextStyle(color: Colors.white60),
          prefixIcon: IconButton(
            tooltip: 'Add emoji',
            onPressed: _showEmojiPicker,
            icon: const Icon(
              Icons.emoji_emotions_outlined,
              color: Colors.white70,
            ),
          ),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.62),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(
              color: RegentColors.lightViolet,
            ),
          ),
        ),
      ),
    );
  }

  Widget _editorHint(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTagBar() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 9, 150, 9),
        color: Colors.black26,
        child: _taggedGroupId == null
            ? OutlinedButton.icon(
                onPressed: _showGroupTagPicker,
                icon: const Icon(
                  Icons.alternate_email,
                  color: Colors.white,
                ),
                label: const Text(
                  'Tag a group or channel',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  alignment: Alignment.centerLeft,
                ),
              )
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white54),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _taggedGroupKind == 'channel'
                          ? Icons.campaign
                          : Icons.groups_2,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        _taggedGroupName ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: 'Remove tag',
                      onPressed: () {
                        setState(() {
                          _taggedGroupId = null;
                          _taggedGroupName = null;
                          _taggedGroupKind = null;
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showGroupTagPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: RegentColors.dmSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.58,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(
                  Icons.alternate_email,
                  color: RegentColors.lightViolet,
                ),
                title: Text(
                  'Tag a group or channel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Admins can turn member tagging off in community settings.',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _statusService.getMyGroupsForStatus(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: RegentColors.primaryBright,
                        ),
                      );
                    }
                    final groups = snapshot.data!.docs.map((document) {
                      return GroupModel.fromMap({
                        ...(document.data() as Map<String, dynamic>),
                        'id': document.id,
                      });
                    }).toList();
                    if (groups.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Join or create a group or channel first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final allowed = group.canTagOnStatus(
                          _statusService.currentUserId,
                        );
                        return ListTile(
                          enabled: allowed,
                          leading: CircleAvatar(
                            backgroundColor: allowed
                                ? RegentColors.primaryBright
                                : Colors.grey.shade700,
                            child: Icon(
                              group.isChannel ? Icons.campaign : Icons.groups_2,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            group.name,
                            style: TextStyle(
                              color: allowed ? Colors.white : Colors.white38,
                            ),
                          ),
                          subtitle: Text(
                            allowed
                                ? (group.isChannel ? 'Channel' : 'Group')
                                : 'Member tagging disabled by admin',
                            style: TextStyle(
                              color: allowed
                                  ? Colors.white60
                                  : Colors.red.shade200,
                            ),
                          ),
                          trailing: Icon(
                            allowed ? Icons.chevron_right : Icons.lock_outline,
                            color: allowed ? Colors.white54 : Colors.white38,
                          ),
                          onTap: allowed
                              ? () {
                                  setState(() {
                                    _taggedGroupId = group.id;
                                    _taggedGroupName = group.name;
                                    _taggedGroupKind = group.kind;
                                  });
                                  Navigator.pop(sheetContext);
                                }
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    const emojis = [
      '😀',
      '😂',
      '😍',
      '🥳',
      '❤️',
      '🔥',
      '✨',
      '👏',
      '🙏',
      '🎓',
      '📚',
      '💜',
      '✅',
      '📣',
      '🎉',
      '💯',
    ];
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: emojis.map((emoji) {
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final selection = _textController.selection;
                  final offset = selection.isValid
                      ? selection.baseOffset
                      : _textController.text.length;
                  final text = _textController.text;
                  _textController.text =
                      '${text.substring(0, offset)}$emoji${text.substring(offset)}';
                  _textController.selection =
                      TextSelection.collapsed(offset: offset + emoji.length);
                  Navigator.pop(sheetContext);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatSeconds(double value) {
    final total = value.round();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String? _contentTypeFor(String? fileName) {
    final extension = fileName?.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'm4v' => 'video/x-m4v',
      _ => null,
    };
  }
}

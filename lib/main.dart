import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'analytics.dart';

const String playerUserAgent = 'TelegramPlayer-v4';

final AnalyticsService analytics = AnalyticsService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await analytics.init();
  runApp(const VidBunkerTestApp());
}

class VideoItem {
  final String title;
  final String url;
  const VideoItem({required this.title, required this.url});

  String get videoId => url;
}

class VidBunkerTestApp extends StatelessWidget {
  const VidBunkerTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VidBunker Test Player',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF9F7FF),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<VideoItem> videos = const [
    VideoItem(
      title: 'Test Video 1',
      url: 'https://vidbunker.in/watch/t9oacLF5g',
    ),
    VideoItem(
      title: 'Test Video 2',
      url: 'https://vidbunker.in/watch/ckpRfY1jN',
    ),
  ];

  final List<VideoItem> _addedVideos = [];

  Future<void> _addLink() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const AddLinkPage()),
    );
    if (!mounted || value == null) return;

    final url = value.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid http/https URL.')),
      );
      return;
    }

    final video = VideoItem(
      title: 'Added Video ${_addedVideos.length + 1}',
      url: url,
    );

    setState(() => _addedVideos.add(video));

    final result = await analytics.reportVideoVisit();
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visit report failed: ${result.error}')),
      );
    }
  }

  void _openVideo(VideoItem video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerPage(video: video)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allVideos = <VideoItem>[...videos, ..._addedVideos];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VidBunker Test Player',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: allVideos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final video = allVideos[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openVideo(video),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.play_arrow, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            video.url,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-link',
        onPressed: _addLink,
        icon: const Icon(Icons.add_link),
        label: const Text('Add Link'),
      ),
    );
  }
}

class AddLinkPage extends StatefulWidget {
  const AddLinkPage({super.key});

  @override
  State<AddLinkPage> createState() => _AddLinkPageState();
}

class _AddLinkPageState extends State<AddLinkPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a video URL.')),
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Video Link')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Video URL',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'https://vidbunker.in/watch/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add),
                label: const Text('Add Video'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  final VideoItem video;
  const PlayerPage({super.key, required this.video});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with WidgetsBindingObserver {
  static const MethodChannel _downloadChannel =
      MethodChannel('vidbunker/downloads');
  static const double _playerRatio = 16 / 9;
  static const List<double> _speeds = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  VideoPlayerController? _controller;
  String? _error;
  bool _starting = true;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  BoxFit _videoFit = BoxFit.contain;
  BoxFit _fitBeforeFullscreen = BoxFit.contain;
  bool _reportSent = false;
  int _maxPlayedSeconds = 0;
  Timer? _hideControlsTimer;
  String _videoSize = 'Checking…';
  bool _sizeLoading = true;
  List<AnalyticsRequestLog> _requestLogs = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestLogs = List.unmodifiable(analytics.requestHistory);
    analytics.onRequest = (log) {
      if (!mounted) return;
      setState(() {
        _requestLogs = List.unmodifiable(analytics.requestHistory);
      });
    };
    _initialize();
  }

  Future<void> _initialize() async {
    _hideControlsTimer?.cancel();
    if (mounted) {
      setState(() {
        _starting = true;
        _error = null;
        _reportSent = false;
        _maxPlayedSeconds = 0;
        _controlsVisible = true;
        _videoSize = 'Checking…';
        _sizeLoading = true;
      });
    }

    final old = _controller;
    old?.removeListener(_onControllerChanged);
    await old?.dispose();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.url),
      formatHint: VideoFormat.other,
      httpHeaders: const {
        'User-Agent': playerUserAgent,
        'Accept': '*/*',
      },
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );

    _controller = controller;
    controller.addListener(_onControllerChanged);
    _loadVideoSize();

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();

      if (!mounted) return;
      setState(() => _starting = false);
      _showControls();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = controller.value.errorDescription ?? e.toString();
      });
    }
  }

  void _onControllerChanged() {
    if (!mounted || _controller == null) return;

    final value = _controller!.value;
    final error = value.errorDescription;
    if (error != null && error.isNotEmpty && _error == null) {
      setState(() {
        _starting = false;
        _error = error;
      });
      return;
    }

    final seconds = value.position.inSeconds;
    if (seconds > _maxPlayedSeconds) {
      _maxPlayedSeconds = seconds;
    }

    if (value.position >= value.duration &&
        value.duration > Duration.zero &&
        !_reportSent) {
      _sendPlaybackReport('ended');
    }

    if (value.isPlaying && _controlsVisible) {
      _startHideTimer();
    }
  }

  Future<void> _sendPlaybackReport(String reason) async {
    if (_reportSent) return;
    _reportSent = true;

    // Existing view-report mechanism intentionally left unchanged.
    final result = await analytics.reportPlayback(
      videoId: widget.video.videoId,
      playedSec: _maxPlayedSeconds,
      reason: reason,
    );

    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('View report failed: ${result.error}')),
      );
    }
  }

  void _showControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideControlsTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Future<void> _seekBy(int seconds) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final target = controller.value.position + Duration(seconds: seconds);
    final max = controller.value.duration;
    final safe = target < Duration.zero
        ? Duration.zero
        : target > max
            ? max
            : target;

    await controller.seekTo(safe);
    _showControls();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      _hideControlsTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      await controller.play();
      _showControls();
    }
  }

  Future<void> _setSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
    if (mounted) {
      Navigator.of(context).pop();
      _showControls();
    }
  }

  void _cycleVideoFit() {
    // One player button cycles through the three display modes.
    // No bottom sheet is opened.
    final next = switch (_videoFit) {
      BoxFit.contain => BoxFit.cover,
      BoxFit.cover => BoxFit.fill,
      _ => BoxFit.contain,
    };
    setState(() => _videoFit = next);
    _showControls();
  }

  String _fitLabel() {
    switch (_videoFit) {
      case BoxFit.contain:
        return 'FIT';
      case BoxFit.cover:
        return 'CROP';
      case BoxFit.fill:
        return 'STRETCH';
      default:
        return 'FIT';
    }
  }

  IconData _fitIcon() {
    switch (_videoFit) {
      case BoxFit.contain:
        return Icons.fit_screen;
      case BoxFit.cover:
        return Icons.crop;
      case BoxFit.fill:
        return Icons.open_in_full;
      default:
        return Icons.fit_screen;
    }
  }

  void _showSpeedSheet() {
    final current = _controller?.value.playbackSpeed ?? 1.0;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Playback speed',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ..._speeds.map(
                (speed) => ListTile(
                  leading: Icon(
                    speed == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text('${_speedText(speed)}×'),
                  onTap: () => _setSpeed(speed),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _speedText(double speed) {
    return speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toString();
  }

  Future<void> _toggleFullscreen() async {
    _hideControlsTimer?.cancel();

    if (_fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      _videoFit = _fitBeforeFullscreen;
      if (mounted) setState(() => _fullscreen = false);
    } else {
      _fitBeforeFullscreen = _videoFit;
      // Fullscreen behaves like YouTube's fill-screen mode by default.
      // Users can still switch to Fit/Original ratio from the player menu.
      _videoFit = BoxFit.cover;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      if (mounted) setState(() => _fullscreen = true);
    }

    _showControls();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setVolume(controller.value.volume == 0 ? 1.0 : 0.0);
    _showControls();
  }

  Future<void> _loadVideoSize() async {
    final uri = Uri.tryParse(widget.video.url);
    if (uri == null) return;

    int? size;
    HttpClient? client;
    try {
      client = HttpClient();
      client.userAgent = playerUserAgent;
      final request = await client
          .headUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        final length = response.contentLength;
        if (length > 0) size = length;
      }
    } catch (_) {
      // Fall back to a one-byte range request below.
    } finally {
      client?.close(force: true);
    }

    if (size == null) {
      HttpClient? rangeClient;
      try {
        rangeClient = HttpClient();
        rangeClient.userAgent = playerUserAgent;
        final request = await rangeClient
            .getUrl(uri)
            .timeout(const Duration(seconds: 10));
        request.headers.set(HttpHeaders.acceptHeader, '*/*');
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
        final response = await request.close().timeout(const Duration(seconds: 10));
        final range = response.headers.value(HttpHeaders.contentRangeHeader);
        final match = range == null
            ? null
            : RegExp(r'/([0-9]+)$').firstMatch(range);
        if (match != null) size = int.tryParse(match.group(1)!);
        if (size == null && response.contentLength > 1) {
          size = response.contentLength;
        }
        await response.drain<void>();
      } catch (_) {
        // Size is optional metadata; playback remains available.
      } finally {
        rangeClient?.close(force: true);
      }
    }

    if (!mounted) return;
    setState(() {
      _sizeLoading = false;
      _videoSize = size == null ? 'Unavailable' : _formatBytes(size);
    });
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    if (index == 0) return '${value.round()} ${units[index]}';
    if (value >= 100) return '${value.toStringAsFixed(0)} ${units[index]}';
    if (value >= 10) return '${value.toStringAsFixed(1)} ${units[index]}';
    return '${value.toStringAsFixed(2)} ${units[index]}';
  }

  Future<void> _download() async {
    final uri = Uri.tryParse(widget.video.url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return;

    try {
      final filename =
          '${widget.video.title.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.mp4';
      final result = await _downloadChannel.invokeMethod<String>('download', {
        'url': uri.toString(),
        'fileName': filename,
        'userAgent': playerUserAgent,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result ?? 'Download started. Check Downloads/VidBunker.',
          ),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.pause();
      if (mounted) setState(() => _controlsVisible = true);
    }
  }

  @override
  void dispose() {
    if (analytics.onRequest != null) {
      analytics.onRequest = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();

    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // Existing analytics behavior intentionally left unchanged.
    if (!_reportSent) {
      _sendPlaybackReport('exit');
    }

    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;

    if (_fullscreen && controller != null && value != null && value.isInitialized) {
      return _buildFullscreen(controller, value);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      body: _error != null
          ? SafeArea(child: _ErrorView(message: _error!, onRetry: _initialize))
          : controller == null ||
                  _starting ||
                  value == null ||
                  !value.isInitialized
              ? const SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connecting to video server...'),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildVideoArea(controller, value),
                      const SizedBox(height: 12),
                      _buildDownloadSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildVideoArea(
    VideoPlayerController controller,
    VideoPlayerValue value,
  ) {
    final nativeRatio = value.aspectRatio > 0 ? value.aspectRatio : _playerRatio;

    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _playerRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildFittedVideo(controller, nativeRatio),
              if (value.isBuffering)
                const Center(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              if (_controlsVisible) _buildControlsOverlay(controller, value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFittedVideo(
    VideoPlayerController controller,
    double nativeRatio,
  ) {
    // The 16:9 player frame is fixed, while the video itself is never
    // stretched. Contain preserves the complete picture; Cover fills the
    // frame and crops only the excess; Fill is provided as an explicit
    // optional mode for users who prefer stretching.
    if (_videoFit == BoxFit.fill) {
      return VideoPlayer(controller);
    }

    return FittedBox(
      fit: _videoFit,
      alignment: Alignment.center,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 1000,
        height: 1000 / nativeRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildControlsOverlay(
    VideoPlayerController controller,
    VideoPlayerValue value,
  ) {
    return Stack(
      children: [
        Positioned(
          top: 6,
          left: 6,
          right: 6,
          child: Row(
            children: [
              _overlayButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              _fitCycleButton(),
              const SizedBox(width: 4),
              _overlayButton(
                icon: Icons.speed,
                tooltip: 'Playback speed',
                onPressed: _showSpeedSheet,
              ),
              const SizedBox(width: 4),
              _overlayButton(
                icon: value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                tooltip: value.volume == 0 ? 'Unmute' : 'Mute',
                onPressed: _toggleMute,
              ),
              const SizedBox(width: 4),
              _overlayButton(
                icon: Icons.fullscreen,
                tooltip: 'Fullscreen',
                onPressed: _toggleFullscreen,
              ),
            ],
          ),
        ),
        if (value.isBuffering)
          const Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _overlayButton(
                icon: Icons.replay_10,
                tooltip: 'Back 10 seconds',
                onPressed: () => _seekBy(-10),
              ),
              const SizedBox(width: 26),
              _overlayButton(
                icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                large: true,
                onPressed: _togglePlay,
              ),
              const SizedBox(width: 26),
              _overlayButton(
                icon: Icons.forward_10,
                tooltip: 'Forward 10 seconds',
                onPressed: () => _seekBy(10),
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 6,
          child: Row(
            children: [
              Text(
                _format(value.position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 3)],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  colors: const VideoProgressColors(
                    playedColor: Colors.red,
                    bufferedColor: Colors.white70,
                    backgroundColor: Colors.white38,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _format(value.duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 3)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fitCycleButton() {
    return Tooltip(
      message: 'Video fit: ${_fitLabel()} (tap to change)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _cycleVideoFit,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_fitIcon(), color: Colors.white, size: 22),
                const SizedBox(width: 4),
                Text(
                  _fitLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool large = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        iconSize: large ? 38 : 25,
        padding: EdgeInsets.all(large ? 14 : 9),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }

  Widget _buildDownloadSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.video.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.storage_outlined, size: 19),
              const SizedBox(width: 7),
              const Text(
                'Video size',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                _videoSize,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download_rounded),
              label: const Text(
                'Download',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildRequestCatcher(),
        ],
      ),
    );
  }

  Widget _buildRequestCatcher() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.http_outlined),
        title: const Text(
          'Server request catcher',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _requestLogs.isEmpty
              ? 'No analytics request captured yet'
              : '${_requestLogs.length} request${_requestLogs.length == 1 ? '' : 's'} captured',
        ),
        children: _requestLogs.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Play the video or add a link. The exact analytics request and server response will appear here.',
                    ),
                  ),
                ),
              ]
            : _requestLogs.reversed.map(_buildRequestCard).toList(),
      ),
    );
  }

  Widget _buildRequestCard(AnalyticsRequestLog log) {
    final sentTime = DateTime.fromMillisecondsSinceEpoch(log.timestampMs);
    final response = log.responseBody?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text(
            '${log.method}  ${log.statusCode == null ? 'NETWORK ERROR' : 'HTTP ${log.statusCode}'}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          SelectableText(
            log.url,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 5),
          Text(
            'Sent: ${sentTime.toLocal()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          const Text(
            'REQUEST HEADERS',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            log.headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 10),
          const Text(
            'REQUEST BODY',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            log.body.isEmpty ? '(empty)' : log.body,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 10),
          const Text(
            'SERVER RESPONSE',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            response == null || response.isEmpty ? '(no response)' : response,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreen(
    VideoPlayerController controller,
    VideoPlayerValue value,
  ) {
    final nativeRatio = value.aspectRatio > 0 ? value.aspectRatio : _playerRatio;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: SizedBox.expand(
          child: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // In landscape fullscreen, default to Cover so the video can
                // use the whole screen like YouTube. The fit menu still lets
                // the user switch back to the complete/native-ratio picture.
                if (_videoFit == BoxFit.fill)
                  VideoPlayer(controller)
                else
                  FittedBox(
                    fit: _videoFit == BoxFit.contain ? BoxFit.contain : BoxFit.cover,
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: 1000,
                      height: 1000 / nativeRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                if (value.isBuffering)
                  const Center(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                if (_controlsVisible) _buildControlsOverlay(controller, value),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _format(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Playback failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            SelectableText(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

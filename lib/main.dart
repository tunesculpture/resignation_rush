import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'analytics.dart';

const String playerUserAgent = 'TelegramPlayer-v4';
const String supabaseUrl = 'https://ixsmbnrjkhbumofnever.supabase.co';
const String supabasePublishableKey = 'sb_publishable_KB6d9_Hlw8HYRtSM5DHU2A_zS-xWzxV';

final AnalyticsService analytics = AnalyticsService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await analytics.init();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey);
  await MobileAds.instance.initialize();
  runApp(const VidBunkerTestApp());
}

class VideoItem {
  final int? id;
  final String title;
  final String url;
  final String thumbnailUrl;
  final String description;
  final String category;
  const VideoItem({required this.title, required this.url, required this.thumbnailUrl, this.id, this.description = '', this.category = 'Videos'});

  String get videoId => url;
  String get thumbnailSource {
    final quoted = RegExp(r'''src\s*=\s*["']([^"']+)["']''', caseSensitive: false).firstMatch(thumbnailUrl);
    final unquoted = RegExp(r'''src\s*=\s*([^\s>]+)''', caseSensitive: false).firstMatch(thumbnailUrl);
    return (quoted ?? unquoted)?.group(1)?.trim() ?? thumbnailUrl.trim();
  }

  factory VideoItem.fromMap(Map<String, dynamic> row) => VideoItem(
    id: (row['id'] as num?)?.toInt(),
    title: row['title'] as String? ?? 'Untitled video',
    url: row['video_url'] as String? ?? '',
    thumbnailUrl: row['thumbnail_url'] as String? ?? '',
    description: row['description'] as String? ?? '',
    category: row['category'] as String? ?? 'Videos',
  );
}

class VidBunkerTestApp extends StatelessWidget {
  const VidBunkerTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Player',
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
  late Future<List<VideoItem>> _videosFuture;
  String _searchQuery = '';
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  int _interstitialCounter = 0;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _videosFuture = _loadVideos();
    _loadInterstitial();
  }

  Future<List<VideoItem>> _loadVideos() async {
    final rows = await Supabase.instance.client
        .from('videos')
        .select('id,title,video_url,thumbnail_url,description,category')
        .eq('is_published', true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    return (rows as List).map((row) => VideoItem.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<void> _refresh() async {
    setState(() => _videosFuture = _loadVideos());
    try { await _videosFuture; } catch (_) {}
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdUnits.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _openVideo(VideoItem video) {
    // A restrained interstitial between videos, not on every tap.
    _interstitialCounter++;
    final ad = _interstitialAd;
    if (_interstitialCounter % 4 == 0 && ad != null && !AdExperience.isInterstitialSuppressed) {
      _interstitialAd = null;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (shown) {
          shown.dispose();
          _loadInterstitial();
          if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(video: video)));
        },
        onAdFailedToShowFullScreenContent: (shown, _) {
          shown.dispose();
          _loadInterstitial();
          if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(video: video)));
        },
      );
      ad.show();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(video: video)));
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF9F7FF),
        titleSpacing: 20,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _searchOpen
              ? TextField(
                  key: const ValueKey('catalog-search'),
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search videos', border: InputBorder.none, isDense: true,
                  ),
                )
              : const Text('Video Player', key: ValueKey('catalog-title'),
                  style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        ),
        actions: [
          IconButton(
            tooltip: _searchOpen ? 'Close search' : 'Search videos',
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) { _searchController.clear(); _searchQuery = ''; }
            }),
            icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded, size: 27),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(children: [
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: BannerAdSlot(height: 50),
        ),
        const SizedBox(height: 8),
        Expanded(child: FutureBuilder<List<VideoItem>>(
          future: _videosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _CatalogMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load videos',
              message: 'Check your internet connection and try again.\n${snapshot.error}',
              buttonText: 'Try again', onPressed: _refresh,
            );
            final videos = (snapshot.data ?? const <VideoItem>[]).where((video) =>
              video.title.toLowerCase().contains(_searchQuery) || video.category.toLowerCase().contains(_searchQuery)
            ).toList();
            if (videos.isEmpty) return _CatalogMessage(
              icon: Icons.video_library_outlined,
              title: _searchQuery.isEmpty ? 'No videos yet' : 'No matching videos',
              message: _searchQuery.isEmpty ? 'Videos added in the admin panel will appear here.' : 'Try another search.',
              buttonText: _searchQuery.isEmpty ? 'Refresh' : 'Clear search',
              onPressed: _searchQuery.isEmpty ? _refresh : () => setState(() => _searchQuery = ''),
            );
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                itemCount: videos.length + videos.length ~/ 5,
                itemBuilder: (context, index) {
                  // Insert a native ad after every five content cards, so ads don't dominate the feed.
                  final adPosition = index > 0 && index % 6 == 5;
                  if (adPosition) return const Padding(
                    padding: EdgeInsets.only(bottom: 14), child: NativeAdCard(),
                  );
                  final videoIndex = index - (index ~/ 6);
                  if (videoIndex >= videos.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: VideoCard(video: videos[videoIndex], onTap: () => _openVideo(videos[videoIndex])),
                  );
                },
              ),
            );
          },
        )),
      ]),
    );
  }
}

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;
  const VideoCard({super.key, required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shadowColor: const Color(0x221C1B2A),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFECEAF3))),
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                Image.network(
                  video.thumbnailSource,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE3E7EF),
                    child: const Center(child: Icon(Icons.broken_image_outlined, size: 42)),
                  ),
                  loadingBuilder: (context, child, progress) => progress == null ? child : Container(
                    color: const Color(0xFFE3E7EF),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
                Positioned(
                  right: 12, bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(.75), borderRadius: BorderRadius.circular(40)),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                  ),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 18, backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.play_circle_fill, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(video.category, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ])),
              const Icon(Icons.more_vert, size: 20),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;
  const _CatalogMessage({required this.icon, required this.title, required this.message, required this.buttonText, required this.onPressed});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 58, color: Colors.grey.shade600), const SizedBox(height: 16),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text(message, textAlign: TextAlign.center), const SizedBox(height: 18),
      FilledButton(onPressed: onPressed, child: Text(buttonText)),
    ]),
  ));
}

class AdExperience {
  static DateTime? interstitialAdFreeUntil;
  static bool get isInterstitialSuppressed => interstitialAdFreeUntil != null && DateTime.now().isBefore(interstitialAdFreeUntil!);
}

class AdUnits {
  // Google's official Android test ad units. Replace with your own IDs before publishing.
  static const banner = 'ca-app-pub-3940256099942544/6300978111';
  static const native = 'ca-app-pub-3940256099942544/2247696110';
  static const interstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const rewarded = 'ca-app-pub-3940256099942544/5224354917';
}

class BannerAdSlot extends StatefulWidget {
  final double height;
  final AdSize size;
  const BannerAdSlot({super.key, this.height = 50, this.size = AdSize.banner});
  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}
class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    _ad = BannerAd(size: widget.size, adUnitId: AdUnits.banner, request: const AdRequest(), listener: BannerAdListener(
      onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
      onAdFailedToLoad: (ad, _) { ad.dispose(); },
    ))..load();
  }
  @override
  void dispose() { _ad?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: Center(child: _loaded && _ad != null ? SizedBox(width: _ad!.size.width.toDouble(), height: _ad!.size.height.toDouble(), child: AdWidget(ad: _ad!)) : const SizedBox.shrink()),
  );
}

class RewardedAdButton extends StatefulWidget {
  const RewardedAdButton({super.key});
  @override
  State<RewardedAdButton> createState() => _RewardedAdButtonState();
}

class _RewardedAdButtonState extends State<RewardedAdButton> {
  RewardedAd? _ad;
  bool _loading = false;
  @override
  void initState() { super.initState(); _load(); }

  void _load() {
    if (_loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: AdUnits.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { _ad = ad; _loading = false; if (mounted) setState(() {}); },
        onAdFailedToLoad: (_) { _ad = null; _loading = false; if (mounted) setState(() {}); },
      ),
    );
  }

  void _showAd() {
    final ad = _ad;
    if (ad == null) { _load(); return; }
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) { shown.dispose(); _load(); },
      onAdFailedToShowFullScreenContent: (shown, _) { shown.dispose(); _load(); },
    );
    ad.show(onUserEarnedReward: (_, __) {
      AdExperience.interstitialAdFreeUntil = DateTime.now().add(const Duration(minutes: 30));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reward earned: no interstitial ads for 30 minutes.')),
        );
        setState(() {});
      }
    });
  }

  @override
  void dispose() { _ad?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (AdExperience.isInterstitialSuppressed) {
      final remaining = AdExperience.interstitialAdFreeUntil!.difference(DateTime.now()).inMinutes + 1;
      return Text('Full-screen ads paused · ${remaining}m', style: Theme.of(context).textTheme.labelSmall);
    }
    return TextButton.icon(
      onPressed: _ad == null ? null : _showAd,
      icon: const Icon(Icons.play_circle_outline, size: 18),
      label: Text(_ad == null ? 'Loading video ad…' : 'Watch ad · 30 min without interstitials'),
    );
  }
}

class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});
  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}
class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    _ad = NativeAd(adUnitId: AdUnits.native, factoryId: 'videoNative', request: const AdRequest(), listener: NativeAdListener(
      onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
      onAdFailedToLoad: (ad, _) { ad.dispose(); },
    ))..load();
  }
  @override
  void dispose() { _ad?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _loaded && _ad != null
    ? Card(clipBehavior: Clip.antiAlias, child: SizedBox(height: 160, child: AdWidget(ad: _ad!)))
    : const SizedBox.shrink();
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
          const SizedBox(height: 8),
          const Center(child: Text('Advertisement', style: TextStyle(fontSize: 10, color: Colors.grey))),
          const BannerAdSlot(height: 100, size: AdSize.largeBanner),
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
                      'Play a video. The exact analytics request and server response will appear here.',
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

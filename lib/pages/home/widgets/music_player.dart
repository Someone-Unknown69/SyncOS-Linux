// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/misc/app_logging.dart';
import 'package:syncos_linux/features/media/domain/models/media_info.dart';
import 'package:syncos_linux/features/media/provider/remote_media_provider.dart';
import 'dart:io';
import '../../../theme/app_theme.dart';
import 'dart:math';

// ======================== PROVIDERS ========================

// Only track metadata relevant to theme (ignore position/status)
final trackMetadataProvider =
    Provider<({String? title, String? artist, Uri? albumArt})>((ref) {
      final track = ref.watch(currentTrackProvider);
      return (
        title: track.title,
        artist: track.artist,
        albumArt: track.albumArtUri,
      );
    });

final dynamicColorSchemeProvider = FutureProvider<ColorScheme>((ref) async {
  final metadata = ref.watch(trackMetadataProvider);
  final artUri = metadata.albumArt;

  ImageProvider provider;
  if (artUri != null && artUri.path.isNotEmpty) {
    provider = FileImage(File.fromUri(artUri));
  } else {
    provider = const AssetImage('assets/images/album.png');
  }

  return MusicThemeService.generate(provider, Brightness.dark);
});

final statusProvider = Provider<bool>((ref) {
  final info = ref.watch(remoteMediaStreamProvider).value ?? MediaInfo.empty;
  return info.status ?? false;
});

final currentTrackProvider = Provider<MediaInfo>((ref) {
  return ref.watch(remoteMediaStreamProvider).value ?? MediaInfo.empty;
});

// ======================== THEME SERVICE ========================

class MusicThemeService {
  /// Generates a Material 3 ColorScheme directly from an image.
  /// This uses the native Flutter algorithm to ensure harmonious tones.
  static Future<ColorScheme> generate(
    ImageProvider image,
    Brightness brightness,
  ) async {
    try {
      return await ColorScheme.fromImageProvider(
        provider: image,
        brightness: brightness,
      );
    } catch (e) {
      // Fallback if the image fails to load or extract
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4), // Material 3 baseline purple
        brightness: brightness,
      );
    }
  }
}

class MusicPlayerWidget extends ConsumerStatefulWidget {
  const MusicPlayerWidget({super.key});

  @override
  ConsumerState<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends ConsumerState<MusicPlayerWidget> {
  @override
  Widget build(BuildContext context) {
    final colorSchemeAsync = ref.watch(dynamicColorSchemeProvider);
    final info = ref.watch(currentTrackProvider);
    final controls = ref.watch(remoteMediaServiceProvider);
    final status = ref.watch(statusProvider);

    final colorScheme =
        colorSchemeAsync.whenData((scheme) => scheme).value ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        );

    final theme = colorScheme;
    final artUri = info.albumArtUri;
    final bool hasArt = artUri != null;

    return Theme(
      data: ThemeData(useMaterial3: true, colorScheme: theme),
      child: Builder(
        builder: (context) {
          final localTheme = Theme.of(context).colorScheme;

          return AspectRatio(
            aspectRatio: 1,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: localTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.musicPlayerRadius),
              ),
              child: Stack(
                children: [
                  // Background Image
                  Positioned.fill(
                    child: hasArt
                        ? SizedBox.expand(
                            child: Image.file(
                              File.fromUri(artUri),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: localTheme.surfaceContainer,
                                );
                              },
                            ),
                          )
                        : Container(color: localTheme.surfaceContainer),
                  ),
                  // Consistent Dark Scrim
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            localTheme.scrim.withValues(alpha: 0.8),
                            localTheme.scrim.withValues(alpha: 0.4),
                            localTheme.scrim.withValues(alpha: 0.9),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // UI Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Song Info at the Top
                        _TrackInfo(
                          name: info.title ?? "Nothing Playing",
                          artist: info.artist ?? "",
                          theme: localTheme,
                        ),

                        const Spacer(),

                        // Progress Bar
                        MusicProgressSlider(
                          theme: theme,
                          duration: info.duration?.toDouble() ?? 0.0,
                          position: info.position?.toDouble() ?? 0.0,
                          status: status,
                        ),

                        const SizedBox(height: 12),

                        // Control
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Previous Button
                            IconButton(
                              onPressed: () {
                                controls.previous();
                              },
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                                size: 26,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: localTheme.onPrimary,
                                foregroundColor: localTheme.primary,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Primary Play/Pause Button
                            IconButton.filled(
                              onPressed: () {
                                controls.playPauseToggle();
                              },
                              iconSize: 40,
                              icon: Icon(
                                status
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: localTheme.primary,
                                foregroundColor: localTheme.onPrimary,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Next Button
                            IconButton(
                              onPressed: () {
                                controls.next();
                              },
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                size: 26,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: localTheme.onPrimary,
                                foregroundColor: localTheme.primary,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------     Title info and shi     ---------------------------------------------

class _TrackInfo extends StatelessWidget {
  final String name;
  final String artist;
  final ColorScheme theme;

  const _TrackInfo({
    required this.name,
    required this.artist,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            color: theme.onSecondaryContainer,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          artist,
          style: TextStyle(color: theme.onSurfaceVariant, fontSize: 16),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

// ---------------------------     Progress Slider     ---------------------------------------------

class MusicProgressSlider extends ConsumerStatefulWidget {
  final ColorScheme theme;
  final double duration;
  final double position;
  final bool status;

  const MusicProgressSlider({
    super.key,
    required this.theme,
    required this.duration,
    required this.position,
    required this.status,
  });

  @override
  ConsumerState<MusicProgressSlider> createState() =>
      _MusicProgressSliderState();
}

class _MusicProgressSliderState extends ConsumerState<MusicProgressSlider>
    with TickerProviderStateMixin {
  double? _dragValue;
  late double _localPosition;
  late DateTime _lastUpdateTime;
  Ticker? _ticker;

  late AnimationController _waveController;
  late AnimationController _flattenController;

  @override
  void initState() {
    super.initState();
    _localPosition = widget.position;
    _lastUpdateTime = DateTime.now();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _flattenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.status) {
      _flattenController.value = 1.0;
      _waveController.repeat();
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.dispose();
    _ticker = createTicker((elapsed) {
      if (widget.status && mounted) {
        setState(() {});
      }
    });
    _ticker!.start();
  }

  @override
  void didUpdateWidget(MusicProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Track changed
    if (oldWidget.duration != widget.duration) {
      _localPosition = widget.position;
      _lastUpdateTime = DateTime.now();
    }
    // Position update from dispatcher
    else if (oldWidget.position != widget.position) {
      _localPosition = widget.position;
      _lastUpdateTime = DateTime.now();
    }

    // Status changed
    if (oldWidget.status != widget.status) {
      if (widget.status) {
        _waveController.repeat();
        _flattenController.forward();
        _startTicker();
      } else {
        _waveController.stop();
        _flattenController.reverse();
        _ticker?.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sendControl = ref.watch(remoteMediaServiceProvider);

    // Smooth position: dispatcher position (ms) + time elapsed (ms)
    double elapsedMs = DateTime.now()
        .difference(_lastUpdateTime)
        .inMilliseconds
        .toDouble();
    double smoothPosition = _localPosition + elapsedMs;

    double progress = widget.duration != 0
        ? (smoothPosition / widget.duration).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(
        () => _dragValue = (d.localPosition.dx / context.size!.width).clamp(
          0.0,
          1.0,
        ),
      ),
      onHorizontalDragEnd: (d) {
        if (_dragValue != null) {
          final seekPosition = (_dragValue! * widget.duration).toInt();
          logDebug('Control', 'Dragging update');
          sendControl.sendSeek(seekPosition);
          setState(() {
            _localPosition = seekPosition.toDouble();
            _lastUpdateTime = DateTime.now();
          });
        }
        setState(() => _dragValue = null);
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_waveController, _flattenController]),
        builder: (context, _) => CustomPaint(
          size: const Size(double.infinity, 30),
          painter: SquigglePainter(
            progress: (_dragValue ?? progress).clamp(0.0, 1.0),
            phase: _waveController.value * 2 * pi,
            amplitude: _flattenController.value * 4.0,
            color: widget.theme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _waveController.dispose();
    _flattenController.dispose();
    super.dispose();
  }
}

// Modify this to change the squiggly player style
class SquigglePainter extends CustomPainter {
  final double progress, phase, amplitude;
  final Color color;

  SquigglePainter({
    required this.progress,
    required this.phase,
    required this.amplitude,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final thumbX = size.width * progress;

    // Inactive track
    final inactivePaint = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    if (thumbX < size.width) {
      canvas.drawLine(
        Offset(thumbX, centerY),
        Offset(size.width, centerY),
        inactivePaint,
      );
    }

    // Active track
    if (thumbX > 0) {
      const double waveLength = 30.0;
      final activePaint = Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final activePath = Path();
      activePath.moveTo(0, centerY + amplitude * sin(phase));
      for (double x = 0.8; x <= thumbX; x += 0.8) {
        final double y =
            centerY + amplitude * sin((x / waveLength) * 2 * pi + phase);
        activePath.lineTo(x, y);
      }
      canvas.drawPath(activePath, activePaint);
    }

    // Thumb
    canvas.drawCircle(
      Offset(thumbX, centerY),
      7.0,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant SquigglePainter oldDelegate) => true;
}


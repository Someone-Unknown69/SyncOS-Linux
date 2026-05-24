import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import '../../../services/socket_server.dart';
import '../../../theme/app_theme.dart';
import 'dart:math';
import '../../../models/music_controls.dart';

// -------------------------------      Music Widget     -------------------------------------------

final MusicControls _musicControls = MusicControls();

class MusicThemeService {
  /// Generates a Material 3 ColorScheme directly from an image.
  /// This uses the native Flutter algorithm to ensure harmonious tones.
  static Future<ColorScheme> generate(ImageProvider image, Brightness brightness) async {
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

class MusicPlayerWidget extends StatefulWidget {
  final String imagePath;
  final String trackName;
  final String artistName;
  final int position;
  final int duration;
  final String status;
  final String? albumArtBase64;
  final SocketServer? client;

  const MusicPlayerWidget({
    super.key,
    required this.imagePath,
    required this.trackName,
    required this.artistName,
    required this.position,
    required this.duration,
    required this.status,
    required this.albumArtBase64,
    this.client,
  });

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  ColorScheme? _dynamicScheme;
  Uint8List? _cacheImageBytes;

  @override
  void initState() {
    super.initState();
    _updateTheme();
  }

  @override
  void didUpdateWidget(MusicPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumArtBase64 != widget.albumArtBase64 || 
    oldWidget.imagePath != widget.imagePath) {
      _updateTheme();
    }
  }

  Uint8List? _decodeBase64Image(String? base64Str) {
    if (base64Str == null || base64Str == 'N/A' || base64Str.length < 50) return null;
    try {
      String cleanBase64 = base64Str.replaceAll(RegExp(r'\s+'), '');
      int pad = cleanBase64.length % 4;
      if (pad > 0) {
        cleanBase64 += '=' * (4 - pad);
      }
      Uint8List bytes = base64Decode(cleanBase64);
      try {
        bytes = Uint8List.fromList(gzip.decode(bytes));
      } catch (_) {}
      return bytes;
    } catch (e) {
      debugPrint("Error decoding base64 image: $e");
      return null;
    }
  }

  Future<void> _updateTheme() async {
    final bytes = _decodeBase64Image(widget.albumArtBase64) ?? _decodeBase64Image(widget.imagePath);

    if(mounted) {
      setState(() {
        _cacheImageBytes = bytes; 
      });
    }

    if (bytes != null) {
      final scheme = await MusicThemeService.generate(
        MemoryImage(bytes),
        Brightness.dark,
      );
      if(mounted) {
        setState(() => _dynamicScheme = scheme);
      }
    }
  }

@override
  Widget build(BuildContext context) {
    final theme = _dynamicScheme ?? Theme.of(context).colorScheme;

    return Theme(
      data: ThemeData(useMaterial3: true, colorScheme: theme),
      child: Builder(builder: (context) {
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
                  child: _cacheImageBytes != null
                      ? Image.memory(
                          _cacheImageBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
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
                        name: widget.trackName,
                        artist: widget.artistName,
                        theme: localTheme,
                      ),
                      
                      const Spacer(),

                      // Progress Bar
                      MusicProgressSlider(
                        theme: theme,
                        duration: widget.duration.toDouble(),
                        position: widget.position.toDouble(),
                        status: widget.status,
                        client: widget.client,
                      ),
                      
                      const SizedBox(height: 12),

                      // Control
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous Button
                          IconButton(
                            onPressed: () {
                              _musicControls.previous();
                            },
                            icon: const Icon(Icons.skip_previous_rounded, size: 26),
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
                              _musicControls.playpause();
                            },
                            iconSize: 40,
                            icon: Icon(
                              widget.status == 'Playing' ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                              _musicControls.next();
                            },
                            icon: const Icon(Icons.skip_next_rounded, size: 26),
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
      }),
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

class MusicProgressSlider extends StatefulWidget {
  final ColorScheme theme;
  final double duration;
  final double position;
  final String status;
  final SocketServer? client;

  const MusicProgressSlider({
    super.key,
    required this.theme,
    required this.duration,
    required this.position,
    required this.status,
    this.client,
  });

  @override
  State<MusicProgressSlider> createState() => _MusicProgressSliderState();
}

class _MusicProgressSliderState extends State<MusicProgressSlider> 
  with TickerProviderStateMixin {
  double? _dragValue;
  late double _localPosition;
  Timer? _timer;

  late AnimationController _waveController;
  late AnimationController _flattenController;

  @override
  void initState() {
    super.initState();
    _localPosition = widget.position;
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _flattenController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    if (widget.status == 'Playing') {
      _flattenController.value = 1.0;
      _waveController.repeat();
    }
    _updateTimer();
  }

  @override
  void didUpdateWidget(MusicProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Track changed — reset position immediately
    if (oldWidget.duration != widget.duration) {
      _localPosition = widget.position;
    } else if (oldWidget.position != widget.position) {
      if ((_localPosition - widget.position).abs() > 2) {
        _localPosition = widget.position;
      }
    }

    if (oldWidget.status != widget.status) {
      _updateTimer();
      if (widget.status == 'Playing') {
        _waveController.repeat();       // restart the wave loop
        _flattenController.forward();   // animate amplitude back up
      } else {
        _waveController.stop();         // freeze the wave
        _flattenController.reverse();   // animate amplitude down to 0 (flat line)
      }
    }
  }

  void _updateTimer() {
    _timer?.cancel();
    if (widget.status == 'Playing') {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _localPosition < widget.duration) {
          setState(() {
            _localPosition += 1.0;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = widget.duration != 0 ? _localPosition / widget.duration : 0.0;
    
    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() => _dragValue = (d.localPosition.dx / context.size!.width).clamp(0.0, 1.0)),
      onHorizontalDragEnd: (d) {
        if (_dragValue != null && widget.client != null) {
          
          _musicControls.seek((_dragValue! * widget.duration).toInt());

          setState(() => _localPosition = _dragValue! * widget.duration);
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
    _timer?.cancel();
    _waveController.dispose();
    _flattenController.dispose();
    super.dispose();
  }
}


// Modify this to change the squiggly player style
class SquigglePainter extends CustomPainter {
  final double progress, phase, amplitude;
  final Color color;

  SquigglePainter({required this.progress, required this.phase, required this.amplitude, required this.color});

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
      canvas.drawLine(Offset(thumbX, centerY), Offset(size.width, centerY), inactivePaint);
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
        final double y = centerY + amplitude * sin((x / waveLength) * 2 * pi + phase);
        activePath.lineTo(x, y);
      }
      canvas.drawPath(activePath, activePaint);
    }

    // Thumb
    canvas.drawCircle(
      Offset(thumbX, centerY),
      7.0,
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant SquigglePainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------------------------------

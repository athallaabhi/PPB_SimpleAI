import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/room.dart';
import '../models/signal_log.dart';
import '../services/database_service.dart';
import '../services/wifi_service.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key, required this.room});

  final Room room;

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final WifiService _wifiService = WifiService();

  List<SignalLogEntry> _signalLogs = const [];
  Size? _sourceImageSize;
  bool _isLoading = true;
  bool _canReadWifi = false;
  int? _liveDbm;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final canReadWifi = await _requestWifiPermission();
      final imageSize = await _resolveImageSize(widget.room.imageUrl);
      final logs = await _databaseService.getSignalLogsByRoom(widget.room.id);

      int? initialDbm;
      if (canReadWifi) {
        initialDbm = await _wifiService.getCurrentConnectedRssi();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _canReadWifi = canReadWifi;
        _sourceImageSize = imageSize;
        _signalLogs = logs;
        _liveDbm = initialDbm;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize canvas: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _requestWifiPermission() async {
    final serviceStatus = await Permission.locationWhenInUse.serviceStatus;
    if (serviceStatus != ServiceStatus.enabled) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Location Service Disabled'),
              content: const Text(
                'Please enable location services to read Wi-Fi RSSI accurately.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
      return false;
    }

    var permissionStatus = await Permission.locationWhenInUse.status;
    if (permissionStatus.isDenied) {
      permissionStatus = await Permission.locationWhenInUse.request();
    }

    if (!permissionStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission denied. RSSI will show as -- and stored as 0.',
            ),
          ),
        );
      }
      return false;
    }

    return true;
  }

  Future<Size> _resolveImageSize(String imageUrl) {
    final completer = Completer<Size>();
    final image = _imageProviderFromUrl(imageUrl);
    final stream = image.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        completer.complete(
          Size(info.image.width.toDouble(), info.image.height.toDouble()),
        );
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        completer.complete(const Size(1, 1));
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  ImageProvider _imageProviderFromUrl(String imageUrl) {
    if (_isLocalFileUri(imageUrl)) {
      return FileImage(File.fromUri(Uri.parse(imageUrl)));
    }

    return NetworkImage(imageUrl);
  }

  bool _isLocalFileUri(String imageUrl) {
    return imageUrl.startsWith('file://');
  }

  Rect _calculateContainRect({required Size container, required Size image}) {
    final imageAspect = image.width / image.height;
    final containerAspect = container.width / container.height;

    if (imageAspect > containerAspect) {
      final width = container.width;
      final height = width / imageAspect;
      final top = (container.height - height) / 2;
      return Rect.fromLTWH(0, top, width, height);
    }

    final height = container.height;
    final width = height * imageAspect;
    final left = (container.width - width) / 2;
    return Rect.fromLTWH(left, 0, width, height);
  }

  Future<void> _reloadSignalLogs() async {
    final logs = await _databaseService.getSignalLogsByRoom(widget.room.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _signalLogs = logs;
    });
  }

  Future<void> _onCanvasTap(TapDownDetails details, Rect imageRect) async {
    final localPosition = details.localPosition;

    if (!imageRect.contains(localPosition)) {
      return;
    }

    final x = localPosition.dx - imageRect.left;
    final y = localPosition.dy - imageRect.top;

    int dbmToSave = 0;
    int? liveDbm;

    if (_canReadWifi) {
      try {
        liveDbm = await _wifiService.getCurrentConnectedRssi();
      } catch (_) {
        liveDbm = null;
      }
      dbmToSave = liveDbm ?? 0;
    }

    try {
      await _databaseService.insertSignalLog(
        roomId: widget.room.id,
        x: x,
        y: y,
        dbm: dbmToSave,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _liveDbm = liveDbm;
      });

      await _reloadSignalLogs();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save signal point: $error')),
      );
    }
  }

  Future<void> _confirmDeleteDot(SignalLogEntry log) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete point?'),
              content: const Text('Remove this signal point from the map?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await _databaseService.deleteSignalLog(
        signalLogId: log.id,
        roomId: widget.room.id,
      );
      await _reloadSignalLogs();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete point: $error')));
    }
  }

  Color _colorForDbm(int dbm) {
    if (dbm == 0) {
      return Colors.blueGrey;
    }
    if (dbm > -60) {
      return Colors.green;
    }
    if (dbm >= -75) {
      return Colors.orange;
    }
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final canvasHeight = math.min(screenSize.height * 0.62, 520.0);

    return Scaffold(
      appBar: AppBar(title: Text(widget.room.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Current RSSI: ${_liveDbm == null ? '--' : '$_liveDbm dBm'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: canvasHeight,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final imageUrl = widget.room.imageUrl;
                          final containerSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          final sourceSize = _sourceImageSize ?? containerSize;
                          final imageRect = _calculateContainRect(
                            container: containerSize,
                            image: sourceSize,
                          );
                          final dotSize = math.max(imageRect.width * 0.02, 8.0);

                          return GestureDetector(
                            onTapDown: (details) =>
                                _onCanvasTap(details, imageRect),
                            child: Stack(
                              children: [
                                Positioned.fromRect(
                                  rect: imageRect,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image(
                                      image: _imageProviderFromUrl(imageUrl),
                                      fit: BoxFit.fill,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.white,
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Unable to load floorplan image',
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                ..._signalLogs.map((log) {
                                  return Positioned(
                                    left:
                                        imageRect.left + log.x - (dotSize / 2),
                                    top: imageRect.top + log.y - (dotSize / 2),
                                    child: GestureDetector(
                                      onTap: () => _confirmDeleteDot(log),
                                      child: Container(
                                        width: dotSize,
                                        height: dotSize,
                                        decoration: BoxDecoration(
                                          color: _colorForDbm(log.dbm),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.black45,
                                            width: 0.7,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Tap on the floorplan to drop a signal point.'),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 10,
                    children: [
                      _LegendDot(color: Colors.green, label: '> -60 dBm'),
                      _LegendDot(color: Colors.orange, label: '-60 to -75 dBm'),
                      _LegendDot(color: Colors.red, label: '< -75 dBm'),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

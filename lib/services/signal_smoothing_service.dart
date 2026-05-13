import 'dart:math' as math;

import '../models/signal_log.dart';

class SignalSmoothingService {
  const SignalSmoothingService();

  List<SignalLogEntry> smooth(
    List<SignalLogEntry> logs, {
    required double radius,
  }) {
    if (logs.isEmpty) {
      return const [];
    }

    final clusters = <_Cluster>[];

    for (final log in logs) {
      _Cluster? bestMatch;
      for (final cluster in clusters) {
        final dx = cluster.centerX - log.x;
        final dy = cluster.centerY - log.y;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance <= radius) {
          bestMatch = cluster;
          break;
        }
      }

      if (bestMatch == null) {
        clusters.add(_Cluster.fromLog(log));
      } else {
        bestMatch.add(log);
      }
    }

    return List<SignalLogEntry>.generate(clusters.length, (index) {
      final cluster = clusters[index];
      return SignalLogEntry(
        id: 'smooth-$index',
        roomId: cluster.roomId,
        x: cluster.centerX,
        y: cluster.centerY,
        dbm: cluster.avgDbm,
      );
    });
  }
}

class _Cluster {
  _Cluster({
    required this.roomId,
    required this.sumX,
    required this.sumY,
    required this.sumDbm,
    required this.count,
    required this.dbmCount,
  });

  factory _Cluster.fromLog(SignalLogEntry log) {
    final hasDbm = log.dbm != 0;
    return _Cluster(
      roomId: log.roomId,
      sumX: log.x,
      sumY: log.y,
      sumDbm: hasDbm ? log.dbm.toDouble() : 0,
      count: 1,
      dbmCount: hasDbm ? 1 : 0,
    );
  }

  final String roomId;
  double sumX;
  double sumY;
  double sumDbm;
  int count;
  int dbmCount;

  double get centerX => sumX / count;
  double get centerY => sumY / count;

  int get avgDbm {
    if (dbmCount == 0) {
      return 0;
    }
    return (sumDbm / dbmCount).round();
  }

  void add(SignalLogEntry log) {
    sumX += log.x;
    sumY += log.y;
    count += 1;
    if (log.dbm != 0) {
      sumDbm += log.dbm.toDouble();
      dbmCount += 1;
    }
  }
}

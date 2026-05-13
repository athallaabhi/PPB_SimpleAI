import 'dart:math' as math;

import '../models/signal_log.dart';

class SignalLabelService {
  const SignalLabelService();

  int? smoothedDbmFor(
    SignalLogEntry target,
    List<SignalLogEntry> allLogs, {
    int neighborCount = 3,
    double minDistance = 1.0,
  }) {
    if (target.dbm == 0 || allLogs.length < 3) {
      return null;
    }

    final neighbors = <_Neighbor>[];
    for (final log in allLogs) {
      if (log.id == target.id || log.dbm == 0) {
        continue;
      }
      final dx = log.x - target.x;
      final dy = log.y - target.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      neighbors.add(_Neighbor(log.dbm, distance));
    }

    if (neighbors.length < 2) {
      return null;
    }

    neighbors.sort((a, b) => a.distance.compareTo(b.distance));
    final topNeighbors = neighbors.take(neighborCount).toList();

    double weightedSum = 0;
    double weightTotal = 0;
    for (final neighbor in topNeighbors) {
      final weight = 1 / math.max(neighbor.distance, minDistance);
      weightedSum += neighbor.dbm * weight;
      weightTotal += weight;
    }

    if (weightTotal == 0) {
      return null;
    }

    return (weightedSum / weightTotal).round();
  }

  String labelForDbm(int? dbm) {
    if (dbm == null || dbm == 0) {
      return 'Unknown';
    }
    if (dbm > -60) {
      return 'Good';
    }
    if (dbm >= -75) {
      return 'Fair';
    }
    return 'Poor';
  }
}

class _Neighbor {
  const _Neighbor(this.dbm, this.distance);

  final int dbm;
  final double distance;
}

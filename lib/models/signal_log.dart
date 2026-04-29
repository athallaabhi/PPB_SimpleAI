import 'package:cloud_firestore/cloud_firestore.dart';

class SignalLogEntry {
  const SignalLogEntry({
    required this.id,
    required this.roomId,
    required this.x,
    required this.y,
    required this.dbm,
  });

  final String id;
  final String roomId;
  final double x;
  final double y;
  final int dbm;

  Map<String, dynamic> toMap() {
    return {'room_id': roomId, 'x': x, 'y': y, 'dbm': dbm};
  }

  factory SignalLogEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String roomId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SignalLogEntry(
      id: doc.id,
      roomId: roomId,
      x: (data['x'] as num?)?.toDouble() ?? 0,
      y: (data['y'] as num?)?.toDouble() ?? 0,
      dbm: (data['dbm'] as num?)?.toInt() ?? 0,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/room.dart';
import '../models/signal_log.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  CollectionReference<Map<String, dynamic>> _signalLogs(String roomId) =>
      _rooms.doc(roomId).collection('signal_logs');

  Future<String> insertRoom({
    required String userUid,
    required String name,
    required String imageUrl,
  }) async {
    final doc = await _rooms.add({
      'user_uid': userUid,
      'name': name,
      'image_url': imageUrl,
      'created_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<List<Room>> getRoomsByUser(String userUid) async {
    final snapshot = await _rooms
        .where('user_uid', isEqualTo: userUid)
        .orderBy('created_at', descending: true)
        .get();
    return snapshot.docs.map(Room.fromFirestore).toList(growable: false);
  }

  Future<void> updateRoomName({
    required String roomId,
    required String userUid,
    required String name,
  }) async {
    final roomRef = _rooms.doc(roomId);
    final roomSnapshot = await roomRef.get();
    final roomData = roomSnapshot.data();

    if (roomData == null) {
      return;
    }

    if (roomData['user_uid'] != userUid) {
      throw StateError('Room does not belong to the current user.');
    }

    await roomRef.update({'name': name});
  }

  Future<void> deleteRoom({
    required String roomId,
    required String userUid,
  }) async {
    final roomRef = _rooms.doc(roomId);
    final roomSnapshot = await roomRef.get();
    final roomData = roomSnapshot.data();

    if (roomData == null) {
      return;
    }

    if (roomData['user_uid'] != userUid) {
      throw StateError('Room does not belong to the current user.');
    }

    final logsSnapshot = await _signalLogs(roomId).get();
    final batch = _db.batch();

    for (final doc in logsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(roomRef);
    await batch.commit();
  }

  Future<String> insertSignalLog({
    required String roomId,
    required double x,
    required double y,
    required int dbm,
  }) async {
    final doc = await _signalLogs(roomId).add({
      'x': x,
      'y': y,
      'dbm': dbm,
      'created_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<List<SignalLogEntry>> getSignalLogsByRoom(String roomId) async {
    final snapshot = await _signalLogs(roomId).orderBy('created_at').get();
    return snapshot.docs
        .map((doc) => SignalLogEntry.fromFirestore(doc, roomId))
        .toList(growable: false);
  }

  Future<void> deleteSignalLog({
    required String signalLogId,
    required String roomId,
  }) async {
    await _signalLogs(roomId).doc(signalLogId).delete();
  }
}

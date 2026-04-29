import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  const Room({
    required this.id,
    required this.userUid,
    required this.name,
    required this.imageUrl,
  });

  final String id;
  final String userUid;
  final String name;
  final String imageUrl;

  Map<String, dynamic> toMap() {
    return {'user_uid': userUid, 'name': name, 'image_url': imageUrl};
  }

  factory Room.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Room(
      id: doc.id,
      userUid: data['user_uid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      imageUrl: data['image_url'] as String? ?? '',
    );
  }
}

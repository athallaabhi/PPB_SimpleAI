import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  String? _uid;

  String? get uid => _uid;

  bool get isLoggedIn => _uid != null;

  void setUid(String uid) {
    _uid = uid;
    notifyListeners();
  }

  void clearUid() {
    _uid = null;
    notifyListeners();
  }
}

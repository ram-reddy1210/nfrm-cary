import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // Alias to avoid name clash

class UserProvider with ChangeNotifier {
  fb_auth.User? _user;

  fb_auth.User? get user => _user;

  void setUser(fb_auth.User? user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}

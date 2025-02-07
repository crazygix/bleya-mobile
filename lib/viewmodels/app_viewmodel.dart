import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/app_state.dart';

class AppViewModel extends ChangeNotifier {
  AppState _state = AppState();

  AppState get state => _state;

  Future<bool> isLoggedIn() async {
    await Future.delayed(Duration(seconds: 2));
    return true;
  }
}

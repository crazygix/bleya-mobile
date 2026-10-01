import 'package:flutter/material.dart';

// Global navigator key for navigation from interceptors and services
final navigatorKey = GlobalKey<NavigatorState>();

/// Tells screens when they are covered and back on top, e.g. chat screens
/// that hold the socket's room.
final appRouteObserver = RouteObserver<PageRoute<dynamic>>();

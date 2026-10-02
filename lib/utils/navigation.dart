import 'package:flutter/material.dart';

// Global navigator key for navigation from interceptors and services
final navigatorKey = GlobalKey<NavigatorState>();

/// Tells screens when they are covered and back on top, e.g. chat screens
/// that hold the socket's room.
final appRouteObserver = RouteObserver<PageRoute<dynamic>>();

/// Shows the chat list as the only screen, once signing in or onboarding is
/// done. Nothing from signing in stays underneath, so Android back leaves
/// the app and the iOS back swipe does nothing.
Future<void> showHomeAsOnlyRoute(NavigatorState navigator) {
  return navigator.pushNamedAndRemoveUntil<void>('/home', (_) => false);
}

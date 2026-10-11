/// How someone tried to sign in.
enum SignInMethod { google, apple, passkey }

/// Something the app reports for product analytics: only what the backend
/// can't see by itself, namely the app opening and sign-in attempts that end
/// before they reach it. Events carry no personal data; the backend links
/// them to this install (and to the account when signed in).
sealed class AnalyticsEvent {
  final DateTime occurredAt;

  AnalyticsEvent({DateTime? occurredAt})
      : occurredAt = occurredAt ?? DateTime.now();
}

/// The app was opened (a cold start).
class AppOpened extends AnalyticsEvent {
  AppOpened({super.occurredAt});
}

/// The user tapped a sign-in button.
class SignInStarted extends AnalyticsEvent {
  final SignInMethod method;

  SignInStarted(this.method, {super.occurredAt});
}

/// The user closed the Google, Apple or passkey sheet without signing in.
class SignInCancelled extends AnalyticsEvent {
  final SignInMethod method;

  SignInCancelled(this.method, {super.occurredAt});
}

/// A sign-in failed before the backend could answer it: the provider's SDK
/// failed, or the request never got through. [reason] is a short code such
/// as `google:clientConfigurationError` or `network:networkError`.
class SignInFailed extends AnalyticsEvent {
  final SignInMethod method;
  final String reason;

  SignInFailed(this.method, this.reason, {super.occurredAt});
}

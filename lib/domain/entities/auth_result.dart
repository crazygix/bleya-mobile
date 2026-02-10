/// Domain entities for authentication flow results.
class CodeRequestResult {
  final int? codeSentAt;

  const CodeRequestResult({this.codeSentAt});
}

class VerifyCodeResult {
  final String token;
  final bool requiresUsername;

  const VerifyCodeResult({
    required this.token,
    required this.requiresUsername,
  });
}

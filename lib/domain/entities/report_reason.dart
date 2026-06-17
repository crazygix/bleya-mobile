/// Reasons a user can pick when reporting another user, a message, or a room.
/// `apiValue` matches the backend's accepted reasons.
enum ReportReason {
  spam,
  harassment,
  inappropriateContent,
  impersonation,
  other;

  String get apiValue {
    switch (this) {
      case ReportReason.spam:
        return 'spam';
      case ReportReason.harassment:
        return 'harassment';
      case ReportReason.inappropriateContent:
        return 'inappropriate_content';
      case ReportReason.impersonation:
        return 'impersonation';
      case ReportReason.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.harassment:
        return 'Harassment or bullying';
      case ReportReason.inappropriateContent:
        return 'Inappropriate content';
      case ReportReason.impersonation:
        return 'Impersonation';
      case ReportReason.other:
        return 'Something else';
    }
  }
}

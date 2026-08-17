/// Failure types DT1FLOW can present to the user.
///
/// The app is offline-first: almost nothing the user does can fail because of
/// the network, and error copy should never imply data loss. Keeping the
/// failure set small and closed (a `sealed` hierarchy) means every UI that
/// handles failures has to handle all of them — the analyzer enforces it in
/// `switch` expressions.
sealed class AppFailure implements Exception {
  const AppFailure({this.cause, this.stackTrace});

  /// The underlying error, kept for logging. Never shown to the user.
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType(cause: $cause)';
}

/// The local database could not be read or written.
final class StorageFailure extends AppFailure {
  const StorageFailure({super.cause, super.stackTrace});
}

/// A local notification could not be scheduled or cancelled — usually because
/// the OS permission was denied or revoked.
final class NotificationFailure extends AppFailure {
  const NotificationFailure({
    this.permissionDenied = false,
    super.cause,
    super.stackTrace,
  });

  /// When true, the fix is a settings change by the user, not a retry.
  final bool permissionDenied;
}

/// Input that the domain rejected, e.g. a change date before an install date.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(this.field, {super.cause, super.stackTrace});

  /// Identifier of the offending field, so the UI can attach the message to
  /// the right input. Not user-visible copy.
  final String field;
}

/// Anything unclassified. Should be rare; prefer adding a specific case.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.cause, super.stackTrace});
}

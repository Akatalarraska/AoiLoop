import '../utils/clock.dart';
import 'app_database.dart';
import 'id_generator.dart';

/// Shared dependencies for every repository.
///
/// The three of them together are what make the data layer testable: an
/// in-memory database, a pinned clock and deterministic ids. Repositories take
/// them by constructor rather than reaching for globals, so a test can assert
/// that a row was stamped at exactly the instant it expected.
abstract class Repository {
  const Repository({required this.db, required this.clock, required this.ids});

  final AppDatabase db;
  final Clock clock;
  final IdGenerator ids;

  /// The instant to stamp on rows written now. Always UTC.
  DateTime get now => clock.nowUtc();

  /// A fresh primary key.
  String get newId => ids.newId();
}

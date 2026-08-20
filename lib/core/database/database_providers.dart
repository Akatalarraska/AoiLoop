import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// The application-wide [AppDatabase].
///
/// Override this in tests and widget tests with an in-memory database:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     appDatabaseProvider.overrideWithValue(
///       AppDatabase(executor: NativeDatabase.memory()),
///     ),
///   ],
///   child: const BlauLoopApp(),
/// );
/// ```
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

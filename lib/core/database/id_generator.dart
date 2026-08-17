import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Source of primary keys.
///
/// Injected rather than called directly for the same reason as `Clock`: tests
/// that assert on relationships between rows are unreadable when every id is
/// a random 36-character string.
abstract interface class IdGenerator {
  String newId();
}

/// Production generator. Random v4 UUIDs.
class UuidGenerator implements IdGenerator {
  const UuidGenerator();

  static const Uuid _uuid = Uuid();

  @override
  String newId() => _uuid.v4();
}

/// Deterministic generator for tests.
///
/// Produces ids of the form `prefix-0000...0001`, padded to the 36 characters
/// the schema expects so it exercises the same column constraints as the real
/// thing.
class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'test'});

  final String prefix;
  int _next = 0;

  @override
  String newId() {
    _next++;
    final String suffix = _next.toString().padLeft(35 - prefix.length, '0');
    return '$prefix-$suffix';
  }
}

/// The application-wide id generator.
final Provider<IdGenerator> idGeneratorProvider = Provider<IdGenerator>(
  (ref) => const UuidGenerator(),
);

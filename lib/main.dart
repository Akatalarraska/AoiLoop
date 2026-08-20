import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 moved `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';

import 'app/app.dart';
import 'app/startup/app_bootstrap.dart';

Future<void> main() async {
  // Required before any plugin channel is touched. `path_provider`, used by
  // Drift to locate the database file, needs it — and so does everything
  // `bootstrapApp` talks to.
  WidgetsFlutterBinding.ensureInitialized();

  // Awaited rather than fired and forgotten: the time zone database has to be
  // loaded before anything schedules a reminder, and the first screen can
  // reach the scheduler. It is a few milliseconds of local work, and it
  // cannot fail in a way that stops the app.
  final List<Override> overrides = await bootstrapApp();

  runApp(ProviderScope(overrides: overrides, child: const AoiLoopApp()));
}

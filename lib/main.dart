import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // Required before any plugin channel is touched. `path_provider`, used by
  // Drift to locate the database file, needs it.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: DT1FlowApp()));
}

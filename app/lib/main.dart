import 'package:flutter/material.dart';

import 'features/capture/presentation/scan_test_page.dart';

void main() => runApp(const MandiDogApp());

class MandiDogApp extends StatelessWidget {
  const MandiDogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MandiDog IA',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const ScanTestPage(),
    );
  }
}

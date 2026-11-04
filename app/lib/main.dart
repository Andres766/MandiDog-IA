import 'package:flutter/material.dart';

import 'core/api/mandidog_api.dart';
import 'core/config.dart';
import 'features/capture/data/tooth_scanner.dart';
import 'features/capture/presentation/scan_test_page.dart';

void main() => runApp(const MandiDogApp());

class MandiDogApp extends StatelessWidget {
  const MandiDogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MandiDog IA',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: ScanTestPage(
        api: MandiDogApi(
          baseUrl: AppConfig.apiBaseUrl,
          devUser: AppConfig.devUser,
        ),
        scanner: ToothScanner(sdkKey: AppConfig.aiforpetSdkKey),
        sdkAvailable: AppConfig.aiforpetSdkAvailable,
      ),
    );
  }
}

/*
 * Campus Lost & Found Management System - Demo App
 * 
 * HOW TO RUN:
 * 1. Ensure Flutter 3.x and Dart 3.x are installed
 * 2. Run: flutter pub get
 * 3. Run: flutter pub run build_runner build --delete-conflicting-outputs
 * 4. Run: flutter run
 * 
 * FEATURES:
 * - Found Item Registration (Officer role)
 * - Search & Claim (Student role)
 * - Claim Review & Handover (Officer role)
 * - Role-based access control
 * - QR code generation for items
 * - Audit logging
 * 
 * DEMO MODE:
 * - All data is stored in-memory (no persistence)
 * - Use Settings to toggle between Student/Officer roles
 * - Debug mode includes "Reset Demo Data" button
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_lost_found/app/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:campus_lost_found/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}


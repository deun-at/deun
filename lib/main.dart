import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

import 'auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jlyxidzhsxbdcitphipg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpseXhpZHpoc3hiZGNpdHBoaXBnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjU5ODY4MjksImV4cCI6MjA0MTU2MjgyOX0.HVdWyO4YmIn-mxHRqKY8kiponI-3kUA15BCTPxfLAlg',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const AuthGate();
  }
}

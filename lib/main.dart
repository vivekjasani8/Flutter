import 'package:flutter/material.dart';

import 'features/mine/mine_screen.dart';

void main() {
  runApp(const IdleMinerApp());
}

class IdleMinerApp extends StatelessWidget {
  const IdleMinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idle Miner Sim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DDC84),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MineScreen(),
    );
  }
}

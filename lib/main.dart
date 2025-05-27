import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:p42/pages/home.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  final secureKey = await _generateHiveKey();
  await Hive.openBox('LocalDB', encryptionKey: secureKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'pFour2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 29, 25, 36),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

Future<List<int>> _generateHiveKey() async {
  final secureRandom = FortunaRandom();
  secureRandom.seed(KeyParameter(Uint8List.fromList(
      List.generate(32, (_) => Random.secure().nextInt(256)))));
  return secureRandom.nextBytes(32);
}

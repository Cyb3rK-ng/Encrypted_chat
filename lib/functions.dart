import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:uuid/uuid.dart';
import 'dart:typed_data';

String getRandomNickname() {
  List<String> nicknames = [
    "Goku", "Naruto", "Luffy", "Saitama", "Vegeta", "Sonic", "Spike", "Ash",
    // ... (rest of your nicknames)
  ];
  return nicknames[Random().nextInt(nicknames.length)];
}

Future<bool> isUserIdExists(String userId) async {
  final snapshot =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  return snapshot.exists;
}

Future<String> generateUniqueUserId() async {
  const String chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  String userId;
  bool exists;

  do {
    userId =
        List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    exists = await isUserIdExists(userId);
  } while (exists);

  return userId;
}

AsymmetricKeyPair<PublicKey, PrivateKey> generateRSAKeyPair() {
  final secureRandom = FortunaRandom();
  secureRandom.seed(KeyParameter(Uint8List.fromList(
      List.generate(32, (_) => Random.secure().nextInt(256)))));
  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom));
  return keyGen.generateKeyPair();
}

String serializeRSAPublicKey(RSAPublicKey publicKey) {
  return '${publicKey.modulus!.toRadixString(16)}:${publicKey.exponent!.toRadixString(16)}';
}

RSAPublicKey deserializeRSAPublicKey(String keyString) {
  final parts = keyString.split(':');
  return RSAPublicKey(
    BigInt.parse(parts[0], radix: 16),
    BigInt.parse(parts[1], radix: 16),
  );
}

String serializeRSAPrivateKey(RSAPrivateKey privateKey) {
  return '${privateKey.modulus!.toRadixString(16)}:${privateKey.exponent!.toRadixString(16)}:${privateKey.p!.toRadixString(16)}:${privateKey.q!.toRadixString(16)}';
}

RSAPrivateKey deserializeRSAPrivateKey(String keyString) {
  final parts = keyString.split(':');
  return RSAPrivateKey(
    BigInt.parse(parts[0], radix: 16),
    BigInt.parse(parts[1], radix: 16),
    BigInt.parse(parts[2], radix: 16),
    BigInt.parse(parts[3], radix: 16),
  );
}

String encryptText(String plainText, String receiverPublicKey) {
  final key = encrypt.Key.fromSecureRandom(32); // AES session key
  final iv = encrypt.IV.fromSecureRandom(16); // Random IV
  final encrypter =
      encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
  final encrypted = encrypter.encrypt(plainText, iv: iv).base64;

  final rsaPublicKey = deserializeRSAPublicKey(receiverPublicKey);
  final rsaEncrypter = RSAEngine()
    ..init(true, PublicKeyParameter<RSAPublicKey>(rsaPublicKey));
  final encryptedKey = base64Encode(rsaEncrypter.process(key.bytes));

  return jsonEncode({
    'encrypted': encrypted,
    'key': encryptedKey,
    'iv': iv.base64,
  });
}

String decryptText(String encryptedData, RSAPrivateKey privateKey) {
  final data = jsonDecode(encryptedData);
  final rsaDecrypter = RSAEngine()
    ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
  final key = encrypt.Key(rsaDecrypter.process(base64Decode(data['key'])));
  final iv = encrypt.IV.fromBase64(data['iv']);
  final encrypter =
      encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
  return encrypter.decrypt64(data['encrypted'], iv: iv);
}

String generateQRData(String userId, RSAPublicKey publicKey) {
  return jsonEncode({
    'userId': userId,
    'publicKey': serializeRSAPublicKey(publicKey),
  });
}

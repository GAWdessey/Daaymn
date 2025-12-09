
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart' as pc;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';


class CryptographyService {
  final parser = encrypt.RSAKeyParser();
  final Map<String, String> _decryptionCache = {};

  Future<pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>> createKeyPair({int bitLength = 2048}) async {
    return Future.value(_generateRSAkeyPair(bitLength: bitLength));
  }

  pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey> _generateRSAkeyPair({int bitLength = 2048}) {
    final secureRandom = pc.FortunaRandom();
    final seed = Uint8List.fromList(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
    secureRandom.seed(pc.KeyParameter(seed));

    final rsaParams = pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64);
    final params = pc.ParametersWithRandom(rsaParams, secureRandom);
    final generator = pc.RSAKeyGenerator();
    generator.init(params);

    final pair = generator.generateKeyPair();
    return pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>(pair.publicKey as pc.RSAPublicKey, pair.privateKey as pc.RSAPrivateKey);
  }

  String encodePublicKeyToPem(pc.RSAPublicKey publicKey) {
    return CryptoUtils.encodeRSAPublicKeyToPemPkcs1(publicKey);
  }

  String encodePrivateKeyToPem(pc.RSAPrivateKey privateKey) {
    return CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey);
  }

  Future<void> storeKeyPair(String userId, pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey> keyPair) async {
    final prefs = await SharedPreferences.getInstance();
    final privatePem = encodePrivateKeyToPem(keyPair.privateKey);
    await prefs.setString('private_key_$userId', privatePem);

    final publicPem = encodePublicKeyToPem(keyPair.publicKey);
    await prefs.setString('public_key_$userId', publicPem);
  }

  Future<pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>?> getKeyPair(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final privatePem = prefs.getString('private_key_$userId');
    final publicPem = prefs.getString('public_key_$userId');

    if (privatePem == null || publicPem == null) return null;

    try {
      final publicKey = parser.parse(publicPem) as pc.RSAPublicKey;
      final privateKey = parser.parse(privatePem) as pc.RSAPrivateKey;
      return pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>(publicKey, privateKey);
    } catch (e) {
      debugPrint('Error parsing stored keys: $e. Returning null.');
      return null;
    }
  }

  Future<pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>> getOrCreateKeyPair(String userId) async {
    var keyPair = await getKeyPair(userId);
    if (keyPair == null) {
      debugPrint('No valid keys found for user $userId. Generating and storing new keys.');
      keyPair = await createKeyPair();
      await storeKeyPair(userId, keyPair);
      final publicKeyPem = encodePublicKeyToPem(keyPair.publicKey);
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'public_key': publicKeyPem})
            .eq('id', userId);
        debugPrint('New public key uploaded for user $userId.');
      } catch (e) {
        debugPrint('Failed to upload new public key: $e');
        // The app can continue to function locally, but others won't be able to send messages.
      }
    }
    return keyPair;
  }
  
  Future<String?> getPublicKey(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('public_key')
          .eq('id', userId)
          .single();
      return response['public_key'] as String?;
    } catch (e) {
      debugPrint('Could not retrieve public key for user $userId: $e');
      return null;
    }
  }


  pc.RSAPublicKey publicKeyFromPem(String pem) {
    return parser.parse(pem) as pc.RSAPublicKey;
  }

  String? encryptString(String message, pc.RSAPublicKey publicKey) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.RSA(publicKey: publicKey, encoding: encrypt.RSAEncoding.PKCS1));
      final encrypted = encrypter.encrypt(message);
      return encrypted.base64;
    } catch (e) {
      debugPrint('Encryption failed: $e');
      return null;
    }
  }

  String? decryptString(String encryptedMessage, pc.RSAPrivateKey privateKey) {
    if (_decryptionCache.containsKey(encryptedMessage)) {
      return _decryptionCache[encryptedMessage];
    }

    try {
      final encrypter = encrypt.Encrypter(encrypt.RSA(privateKey: privateKey, encoding: encrypt.RSAEncoding.PKCS1));
      final encrypted = encrypt.Encrypted.fromBase64(encryptedMessage);
      final decrypted = encrypter.decrypt(encrypted);
      _decryptionCache[encryptedMessage] = decrypted;
      return decrypted;
    } catch (e) {
      debugPrint('Decryption failed: $e');
      return null;
    }
  }

  Future<void> removeKeyPair(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('private_key_$userId');
    await prefs.remove('public_key_$userId');
  }
}

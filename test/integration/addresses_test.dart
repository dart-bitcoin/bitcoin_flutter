import '../../lib/src/models/networks.dart' as NETWORKS;
import '../../lib/src/ecpair.dart' show ECPair;
import '../../lib/src/payments/p2pkh.dart' show P2PKH, P2PKHData;
import '../../lib/src/payments/p2wpkh.dart' show P2WPKH, P2WPKHData;
import "package:pointycastle/digests/sha256.dart";
import 'dart:convert';
import 'package:test/test.dart';
NETWORKS.NetworkType litecoin = new NETWORKS.NetworkType(
    messagePrefix: '\x19Litecoin Signed Message:\n',
    bip32: new NETWORKS.Bip32Type(
        public: 0x019da462,
        private: 0x019d9cfe
    ),
    pubKeyHash: 0x30,
    scriptHash: 0x32,
    wif: 0xb0
);
// deterministic RNG for testing only
rng (int number) { return utf8.encode('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'); }
main() {
  group('bitcoinjs-lib (addresses)', () {
    test('can generate a random address', () {
      final keyPair = ECPair.makeRandom(rng: rng);
      final address = new P2PKH(data: new P2PKHData(pubkey: keyPair.publicKey)).data.address;
      expect(address, '1F5VhMHukdnUES9kfXqzPzMeF1GPHKiF64');
    });
    test('can generate an address from a SHA256 hash', () {
      final hash = new SHA256Digest().process(utf8.encode("correct horse battery staple"));
      final keyPair = ECPair.fromPrivateKey(hash);
      final address = new P2PKH(data: new P2PKHData(pubkey: keyPair.publicKey)).data.address;
      expect(address, '1C7zdTfnkzmr13HfA2vNm5SJYRK6nEKyq8');
    });
    test('can import an address via WIF', () {
      final keyPair = ECPair.fromWIF('Kxr9tQED9H44gCmp6HAdmemAzU3n84H3dGkuWTKvE23JgHMW8gct');
      final address = new P2PKH(data: new P2PKHData(pubkey: keyPair.publicKey)).data.address;
      expect(address, '19AAjaTUbRjQCMuVczepkoPswiZRhjtg31');
    });
    test('can generate a Testnet address', () {
      final testnet = NETWORKS.testnet;
      final keyPair = ECPair.makeRandom(network: testnet, rng: rng);
      final wif = keyPair.toWIF();
      final address = new P2PKH(data: new P2PKHData(pubkey: keyPair.publicKey), network: testnet).data.address;
      expect(address, 'mubSzQNtZfDj1YdNP6pNDuZy6zs6GDn61L');
      expect(wif, 'cRgnQe9MUu1JznntrLaoQpB476M8PURvXVQB5R2eqms5tXnzNsrr');
    });
    test('can generate a Litecoin address', () {
      final keyPair = ECPair.makeRandom(network: litecoin, rng: rng);
      final wif = keyPair.toWIF();
      final address = new P2PKH(data: new P2PKHData(pubkey: keyPair.publicKey), network: litecoin).data.address;
      expect(address, 'LZJSxZbjqJ2XVEquqfqHg1RQTDdfST5PTn');
      expect(wif, 'T7A4PUSgTDHecBxW1ZiYFrDNRih2o7M8Gf9xpoCgudPF9gDiNvuS');
    });
    test('can generate a SegWit address', () {
      final keyPair = ECPair.fromWIF('KwDiBf89QgGbjEhKnhXJuH7LrciVrZi3qYjgd9M7rFU73sVHnoWn');
      final address = new P2WPKH(data: new P2WPKHData(pubkey: keyPair.publicKey)).data.address;
      expect(address, 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4');
    });
    test('can generate a SegWit testnet address', () {
      final testnet = NETWORKS.testnet;
      final keyPair = ECPair.fromWIF('cPaJYBMDLjQp5gSUHnBfhX4Rgj95ekBS6oBttwQLw3qfsKKcDfuB');
      final address = new P2WPKH(data: new P2WPKHData(pubkey: keyPair.publicKey), network: testnet).data.address;
      expect(address, 'tb1qgmp0h7lvexdxx9y05pmdukx09xcteu9sx2h4ya');
    });
  });
}

import 'package:test/test.dart';
import 'package:hex/hex.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import '../lib/src/ecpair.dart' show ECPair;
import '../lib/src/models/networks.dart' as NETWORKS;

final ZERO = Uint8List.fromList(List.generate(32, (i) => 0));
final ONE = HEX.decode('0000000000000000000000000000000000000000000000000000000000000001');
final GROUP_ORDER = HEX.decode('fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141');
final GROUP_ORDER_LESS_1 = HEX.decode('fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140');

main() {
  final fixtures = json.decode(new File("test/fixtures/ecpair.json").readAsStringSync(encoding: utf8));
  group('ECPair', () {

    group('fromPrivateKey', () {
      test('defaults to compressed', () {
        final keyPair = ECPair.fromPrivateKey(ONE);
        expect(keyPair.compressed, true);
      });
      test('supports the uncompressed option', () {
        final keyPair = ECPair.fromPrivateKey(ONE, compressed: false);
        expect(keyPair.compressed, false);
      });
      test('supports the network option', () {
        final keyPair = ECPair.fromPrivateKey(ONE, network: NETWORKS.testnet, compressed: false);
        expect(keyPair.network, NETWORKS.testnet);
      });
      (fixtures['valid'] as List).forEach((f) {
        test('derives public key for ${f['WIF']}', () {
          final d = HEX.decode(f['d']);
          final keyPair = ECPair.fromPrivateKey(d, compressed: f['compressed']);
          expect(HEX.encode(keyPair.publicKey), f['Q']);
        });
      });
    });
  });
}
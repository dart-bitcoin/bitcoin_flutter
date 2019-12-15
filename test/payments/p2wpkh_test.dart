import 'package:bitcoin_flutter/src/payments/index.dart' show PaymentData;
import 'package:bitcoin_flutter/src/payments/p2wpkh.dart';
import 'package:test/test.dart';
import 'package:bitcoin_flutter/src/utils/script.dart' as bscript;
import 'dart:io';
import 'dart:convert';
import 'package:hex/hex.dart';
import 'dart:typed_data';

main() {

  final fixtures = json.decode(new File("./test/fixtures/p2wpkh.json").readAsStringSync(encoding: utf8));

  group('(valid case)', () {
    (fixtures["valid"] as List<dynamic>).forEach((f) {
      test(f['description'] + ' as expected', () {
        final arguments = _preformP2WPKH(f['arguments']);
        final p2wpkh = new P2WPKH(data: arguments);
        if (arguments.address == null) {
          expect(p2wpkh.data.address, f['expected']['address']);
        }
        if (arguments.hash == null) {
          expect(_toString(p2wpkh.data.hash), f['expected']['hash']);
        }
        if (arguments.pubkey == null) {
          expect(_toString(p2wpkh.data.pubkey), f['expected']['pubkey']);
        }
        if (arguments.input == null) {
          expect(_toString(p2wpkh.data.input), f['expected']['input']);
        }
        if (arguments.output == null) {
          expect(_toString(p2wpkh.data.output), f['expected']['output']);
        }
        if (arguments.signature == null) {
          expect(_toString(p2wpkh.data.signature), f['expected']['signature']);
        }
        if (arguments.witness == null) {
          expect(_toString(p2wpkh.data.witness), f['expected']['witness']);
        }
      });
    });
  });

  group('(invalid case)', () {
    (fixtures["invalid"] as List<dynamic>).forEach((f) {
      test('throws ' + f['exception'] + (f['description'] != null ? ('for ' + f['description']) : ''), () {
        final arguments = _preformP2WPKH(f['arguments']);
        try {
          expect(new P2WPKH(data: arguments), isArgumentError);
        } catch(err) {
          expect((err as ArgumentError).message, f['exception']);
        }

      });
    });
  });
}

PaymentData _preformP2WPKH(dynamic x) {
  final address   = x['address'];
  final hash      = x['hash'] != null ? HEX.decode(x['hash']) : null;
  final input     = x['input'] != null ? bscript.fromASM(x['input']) : null;
  final witness   = x['witness'] != null ? (x['witness'] as List<dynamic>).map((e) => HEX.decode(e.toString()) as Uint8List).toList() : null;
  final output    = x['output'] != null ? bscript.fromASM(x['output']) : x['outputHex'] != null ? HEX.decode(x['outputHex']) : null;
  final pubkey    = x['pubkey'] != null ? HEX.decode(x['pubkey']) : null;
  final signature = x['signature'] != null ? HEX.decode(x['signature']) : null;
  return new PaymentData(address: address, hash: hash, input: input, output: output, pubkey: pubkey, signature: signature, witness: witness);
}

String _toString(dynamic x) {
  if (x == null) {
    return null;
  }
  if (x is Uint8List) {
    return HEX.encode(x);
  }
  if (x is List<dynamic>) {
    return bscript.toASM(x);
  }
  return '';
}

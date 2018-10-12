import 'package:bitcoin_flutter/src/payments/p2pkh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitcoin_flutter/src/utils/script.dart' as bscript;
import 'dart:io';
import 'dart:convert';
import 'package:hex/hex.dart';
import 'dart:typed_data';
main() {
  final fixtures = json.decode(new File("../test/fixtures/p2pkh.json").readAsStringSync(encoding: utf8));
  group('(valid case)', () {
    (fixtures["valid"] as List<dynamic>).forEach((f) {
      test(f['description'] + ' as expected', () {
        final arguments = _preformP2PKH(f['arguments']);
        final p2pkh = new P2PKH(data: arguments);
        if (arguments.address == null) {
          expect(p2pkh.data.address, f['expected']['address']);
        }
        if (arguments.hash == null) {
          expect(_toString(p2pkh.data.hash), f['expected']['hash']);
        }
        if (arguments.pubkey == null) {
          expect(_toString(p2pkh.data.pubkey), f['expected']['pubkey']);
        }
        if (arguments.input == null) {
          expect(_toString(p2pkh.data.input), f['expected']['input']);
        }
        if (arguments.output == null) {
          expect(_toString(p2pkh.data.output), f['expected']['output']);
        }
        if (arguments.signature == null) {
          expect(_toString(p2pkh.data.signature), f['expected']['signature']);
        }
      });
    });
  });
  group('(invalid case)', () {
    (fixtures["invalid"] as List<dynamic>).forEach((f) {
      test('throws ' + f['exception'] + (f['description'] != null ? ('for ' + f['description']) : ''), () {
        final arguments = _preformP2PKH(f['arguments']);
        try {
          expect(new P2PKH(data: arguments), isArgumentError);
        } catch(err) {
          expect((err as ArgumentError).message, f['exception']);
        }

      });
    });
  });
}
P2PKHData _preformP2PKH(dynamic x) {
  final address = x['address'];
  final hash = x['hash'] != null ? HEX.decode(x['hash']) : null;
  final input = x['input'] != null ? bscript.fromASM(x['input']) : null;
  final output = x['output'] != null ? bscript.fromASM(x['output']) : x['outputHex'] != null ? HEX.decode(x['outputHex']) : null;
  final pubkey = x['pubkey'] != null ? HEX.decode(x['pubkey']) : null;
  final signature = x['signature'] != null ? HEX.decode(x['signature']) : null;
  return new P2PKHData(address: address, hash: hash, input: input, output: output, pubkey: pubkey, signature: signature);
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
}
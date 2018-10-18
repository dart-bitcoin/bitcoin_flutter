import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:hex/hex.dart';
import 'dart:typed_data';
import '../lib/src/utils/script.dart' as bscript;
import '../lib/src/transaction.dart';
main() {
  final fixtures = json.decode(new File("test/fixtures/transaction.json").readAsStringSync(encoding: utf8));
  group('Transaction', () {
    group('fromBuffer/fromHex', () {
      (fixtures['valid'] as List<dynamic>).forEach(importExport);
      (fixtures['hashForSignature'] as List<dynamic>).forEach(importExport);
      (fixtures['invalid']['fromBuffer'] as List<dynamic>).forEach((f) {
        test('throws on ${f['exception']}', () {
          try {
            expect(Transaction.fromHex(f['hex']), isArgumentError);
          } catch (err) {
            expect((err as ArgumentError).message, f['exception']);
          }
        });
      });
      test('.version should be interpreted as an int32le', () {
        final txHex = 'ffffffff0000ffffffff';
        final tx = Transaction.fromHex(txHex);
        expect(-1, tx.version);
      });
    });
    group('toBuffer/toHex', () {
      (fixtures['valid'] as List<dynamic>).forEach((f) {
        test('exports ${f['description']} (${f['id']})', () {
          Transaction actual = fromRaw(f['raw']);
          expect(actual.toHex(), f['hex']);
        });
      });
    });
    group('weight/virtualSize', () {
      test('computes virtual size', () {
        (fixtures['valid'] as dynamic).forEach((f) {
          final transaction = Transaction.fromHex(f['hex']);
          expect(transaction.virtualSize(), f['virtualSize']);
        });
      });
    });
    group('addInput', ()
    {
      var prevTxHash;
      setUp(() {
        prevTxHash = HEX.decode(
            'ffffffff00ffff000000000000000000000000000000000000000000101010ff');
      });
      test('returns an index', () {
        final tx = new Transaction();
        expect(tx.addInput(prevTxHash, 0), 0);
        expect(tx.addInput(prevTxHash, 0), 1);
      });
      test('defaults to empty script, and 0xffffffff SEQUENCE number', () {
        final tx = new Transaction();
        tx.addInput(prevTxHash, 0);
        expect(tx.ins[0].script.length, 0);
        expect(tx.ins[0].sequence, 0xffffffff);
      });
      (fixtures['invalid']['addInput'] as List<dynamic>).forEach((f) {
        test('throws on ' + f['exception'], () {
          final tx = new Transaction();
          final hash = HEX.decode(f['hash']);
          try {
            expect(tx.addInput(hash, f['index']), isArgumentError);
          } catch (err) {
            expect((err as ArgumentError).message, f['exception']);
          }
        });
      });
    });
    test('addOutput returns an index', () {
      final tx = new Transaction();
      expect(tx.addOutput(new Uint8List(0), 0), 0);
      expect(tx.addOutput(new Uint8List(0), 0), 1);
    });
    group('getHash/getId', () {
      verify (f) {
        test('should return the id for ${f['id']} (${f['description']})', () {
        final tx = Transaction.fromHex(f['hex']);
          expect(HEX.encode(tx.getHash()), f['hash']);
          expect(tx.getId(), f['id']);
        });
      }
      (fixtures['valid'] as List<dynamic>).forEach(verify);
    });
    group('isCoinbase', () {
      verify (f) {
        test('should return ${f['coinbase']} for ${f['id']} (${f['description']})', () {
          final tx = Transaction.fromHex(f['hex']);
          expect(tx.isCoinbase(), f['coinbase']);
        });
      }
      (fixtures['valid'] as List<dynamic>).forEach(verify);
    });
    group('hashForSignature', () {
      (fixtures['hashForSignature'] as List<dynamic>).forEach((f) {
        test('should return ${f['hash']} for ${f['description'] != null ? 'case "' + f['description'] + '"' : f['script']}', () {
          final tx = Transaction.fromHex(f['txHex']);
          final script = bscript.fromASM(f['script']);
          expect(HEX.encode(tx.hashForSignature(f['inIndex'], script, f['type'])), f['hash']);
        });
      });
    });
  });
}
importExport(dynamic f) {
  final id = f['id'] ?? f['hash'];
  final txHex = f['hex'] ?? f['txHex'];
  test('imports ${f['description']} ($id)', () {
    final actual = Transaction.fromHex(txHex);
    expect(actual.toHex(), txHex);
  });
}
Transaction fromRaw (raw) {
  final tx = new Transaction();
  tx.version = raw['version'];
  tx.locktime = raw['locktime'];

  (raw['ins'] as List<dynamic>).forEach((txIn) {
    final txHash = HEX.decode(txIn['hash']);
    var scriptSig;

    if (txIn['data'] != null) {
      scriptSig = HEX.decode(txIn['data']);
    } else if (txIn['script'] != null) {
      scriptSig = bscript.fromASM(txIn['script']);
    }
    tx.addInput(txHash, txIn['index'], txIn['sequence'], scriptSig);
  });
  (raw['outs'] as List<dynamic>).forEach((txOut) {
    var script;
    if (txOut['data'] != null) {
      script = HEX.decode(txOut['data']);
    } else if (txOut['script'] != null) {
      script = bscript.fromASM(txOut['script']);
    }
    tx.addOutput(script, txOut['value']);
  });
  return tx;
}
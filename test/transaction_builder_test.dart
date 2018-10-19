import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hex/hex.dart';
import '../lib/src/models/networks.dart';
import '../lib/src/ecpair.dart';
import '../lib/src/transaction.dart';
import '../lib/src/transaction_builder.dart';
import '../lib/src/utils/script.dart' as bscript;
import '../lib/src/payments/p2pkh.dart';
final NETWORKS = {
  'bitcoin': bitcoin,
  'testnet': testnet
};

constructSign(f, TransactionBuilder txb) {
  final network = NETWORKS[f['network']];
  final inputs = f['inputs'] as List<dynamic>;
  for(var i = 0; i < inputs.length; i++) {
    if (inputs[i]['signs'] == null) continue;
    (inputs[i]['signs'] as List<dynamic>).forEach((sign) {
      ECPair keyPair = ECPair.fromWIF(sign['keyPair'], network: network);
      txb.sign(i, keyPair, sign['hashType']);
    });
  }
  return txb;
}
TransactionBuilder construct(f, [bool dontSign]) {
  final network = NETWORKS[f['network']];
  final txb = new TransactionBuilder(network: network);
  if (f['version'] != null) txb.setVersion(f['version']);
  (f['inputs'] as List<dynamic>).forEach((input) {
    var prevTx;
    if (input['txRaw'] != null) {
      final constructed = construct(input['txRaw']);
      if (input['txRaw']['incomplete']) prevTx = constructed.buildIncomplete();
      else prevTx = constructed.build();
    } else if (input['txHex'] != null) {
      prevTx = Transaction.fromHex(input['txHex']);
    } else {
      prevTx = input['txId'];
    }
    var prevTxScript;
    if (input['prevTxScript'] != null) {
      prevTxScript = bscript.fromASM(input['prevTxScript']);
    }
    txb.addInput(prevTx, input['vout'], input['sequence'], prevTxScript);
  });
  (f['outputs'] as List<dynamic>).forEach((output) {
    if(output['address'] != null) {
      txb.addOutput(output['address'], output['value']);
    } else {
      txb.addOutput(bscript.fromASM(output['script']), output['value']);
    }
  });
  if (dontSign != null && dontSign) return txb;
  return constructSign(f, txb);
}
main() {
  final fixtures = json.decode(new File("test/fixtures/transaction_builder.json").readAsStringSync(encoding: utf8));
  group('TransactionBuilder', () {
//    final keyPair = ECPair.fromPrivateKey(HEX.decode('0000000000000000000000000000000000000000000000000000000000000001'));
//    final scripts = [
//      '1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH',
//      '1cMh228HTCiwS8ZsaakH8A8wze1JR5ZsP'
//    ].map((x) => addressToOutputScript(x));
//    final txHash = HEX.decode('0e7cea811c0be9f73c0aca591034396e7264473fc25c1ca45195d7417b36cbe2');
//    group('fromTransaction', () {
//      (fixtures['valid']['build'] as List<dynamic>).forEach((f) {
//        test('returns TransactionBuilder, with ${f['description']}', () {
//          final network = NETWORKS[f['network'] ?? 'bitcoin'];
//          final tx = Transaction.fromHex(f['txHex']);
//          final txb = TransactionBuilder.fromTransaction(tx, network);
//          final txAfter = f['incomplete'] != null ? txb.buildIncomplete() : txb.build();
//          expect(txAfter.toHex(), f['txHex']);
//          expect(txb.network, network);
//        });
//      });
//      (fixtures['valid']['fromTransaction'] as List<dynamic>).forEach((f) {
//        test('returns TransactionBuilder, with ${f['description']}', () {
//          final tx = new Transaction();
//          f['inputs'] as List<dynamic>..forEach((input) {
//            final txHash2 = Uint8List.fromList(HEX.decode(input['txId']).reversed.toList());
//            tx.addInput(txHash2, input['vout'], null, bscript.fromASM(input['scriptSig']));
//          });
//          f['outputs'] as List<dynamic>..forEach((output) {
//            tx.addOutput(bscript.fromASM(output['script']), output['value']);
//          });
//
//          final txb = TransactionBuilder.fromTransaction(tx);
//          final txAfter = f['incomplete'] ? txb.buildIncomplete() : txb.build();
//
//          for(var i = 0; i < txAfter.ins.length; i++) {
//            test(bscript.toASM(txAfter.ins[i].script), f['inputs'][i]['scriptSigAfter']);
//          }
//          for(var i = 0; i < txAfter.outs.length; i++) {
//            test(bscript.toASM(txAfter.outs[i].script), f['outputs'][i]['script']);
//          }
//        });
//      });
//      fixtures['invalid']['fromTransaction'] as List..forEach((f) {
//        test('throws ${f['exception']}', () {
//          final tx = Transaction.fromHex(f['txHex']);
//          try {
//            expect(TransactionBuilder.fromTransaction(tx), isArgumentError);
//          } catch(err) {
//            expect((err as ArgumentError).message, f['exception']);
//          }
//        });
//      });
//    });
//    group('addInput', () {
//      TransactionBuilder txb;
//      setUp(() {
//        txb = new TransactionBuilder();
//      });
//      test('accepts a txHash, index [and sequence number]', () {
//        final vin = txb.addInput(txHash, 1, 54);
//        expect(vin, 0);
//        final txIn = txb.tx.ins[0];
//        expect(txIn.hash, txHash);
//        expect(txIn.index, 1);
//        expect(txIn.sequence, 54);
//        expect(txb.inputs[0].prevOutScript, null);
//      });
//      test('accepts a txHash, index [, sequence number and scriptPubKey]', () {
//        final vin = txb.addInput(txHash, 1, 54, scripts.elementAt(1));
//        expect(vin, 0);
//        final txIn = txb.tx.ins[0];
//        expect(txIn.hash, txHash);
//        expect(txIn.index, 1);
//        expect(txIn.sequence, 54);
//        expect(txb.inputs[0].prevOutScript, scripts.elementAt(1));
//      });
//      test('accepts a prevTx, index [and sequence number]', () {
//        final prevTx = new Transaction();
//        prevTx.addOutput(scripts.elementAt(0), 0);
//        prevTx.addOutput(scripts.elementAt(1), 1);
//
//        final vin = txb.addInput(prevTx, 1, 54);
//        expect(vin, 0);
//
//        final txIn = txb.tx.ins[0];
//        expect(txIn.hash, prevTx.getHash());
//        expect(txIn.index, 1);
//        expect(txIn.sequence, 54);
//        expect(txb.inputs[0].prevOutScript, scripts.elementAt(1));
//      });
//      test('returns the input index', () {
//        expect(txb.addInput(txHash, 0), 0);
//        expect(txb.addInput(txHash, 1), 1);
//      });
//      test('throws if SIGHASH_ALL has been used to sign any existing scriptSigs', () {
//        txb.addInput(txHash, 0);
//        txb.addOutput(scripts.elementAt(0), 1000);
//        txb.sign(0, keyPair);
//        try {
//          expect(txb.addInput(txHash, 0), isArgumentError);
//        } catch (err) {
//          expect((err as ArgumentError).message, 'No, this would invalidate signatures');
//        }
//      });
//    });
//    group('addOutput', () {
//      TransactionBuilder txb;
//      setUp(() {txb = new TransactionBuilder();});
//      test('accepts an address string and value', () {
//        final address = new P2PKH(data: new P2PKHData(pubkey: keyPair.publicKey)).data.address;
//        final vout = txb.addOutput(address, 1000);
//        expect(vout, 0);
//        final txout = txb.tx.outs[0];
//        expect(txout.script, scripts.elementAt(0));
//        expect(txout.value, 1000);
//      });
//      test('accepts a ScriptPubKey and value', () {
//        final vout = txb.addOutput(scripts.elementAt(0), 1000);
//        expect(vout, 0);
//        final txout = txb.tx.outs[0];
//        expect(txout.script, scripts.elementAt(0));
//        expect(txout.value, 1000);
//      });
//      test('throws if address is of the wrong network', () {
//        try {
//          expect(txb.addOutput('2NGHjvjw83pcVFgMcA7QvSMh2c246rxLVz9', 1000),
//              isArgumentError);
//        } catch (err) {
//          expect((err as ArgumentError).message, 'Invalid version or Network mismatch');
//        }
//      });
//      test('add second output after signed first input with SIGHASH_NONE', () {
//        txb.addInput(txHash, 0);
//        txb.addOutput(scripts.elementAt(0), 2000);
//        txb.sign(0, keyPair, SIGHASH_NONE);
//        expect(txb.addOutput(scripts.elementAt(1), 9000), 1);
//      });
//      test('add first output after signed first input with SIGHASH_NONE', () {
//        txb.addInput(txHash, 0);
//        txb.sign(0, keyPair, SIGHASH_NONE);
//        expect(txb.addOutput(scripts.elementAt(0), 2000), 0);
//      });
//      test('add second output after signed first input with SIGHASH_SINGLE', () {
//        txb.addInput(txHash, 0);
//        txb.addOutput(scripts.elementAt(0), 2000);
//        txb.sign(0, keyPair, SIGHASH_SINGLE);
//        expect(txb.addOutput(scripts.elementAt(1), 9000), 1);
//      });
//      test('add first output after signed first input with SIGHASH_SINGLE', () {
//        txb.addInput(txHash, 0);
//        txb.sign(0, keyPair,  SIGHASH_SINGLE);
//        try {
//          expect(txb.addOutput(scripts.elementAt(0), 2000), isArgumentError);
//        } catch(err) {
//          expect((err as ArgumentError).message, 'No, this would invalidate signatures');
//        }
//      });
//      test('throws if SIGHASH_ALL has been used to sign any existing scriptSigs', () {
//        txb.addInput(txHash, 0);
//        txb.addOutput(scripts.elementAt(0), 2000);
//        txb.sign(0, keyPair);
//        try {
//          expect(txb.addOutput(scripts.elementAt(1), 9000), isArgumentError);
//        } catch(err) {
//          expect((err as ArgumentError).message, 'No, this would invalidate signatures');
//        }
//      });
//    });
//    group('setLockTime', () {
//      test('throws if if there exist any scriptSigs', () {
//        final txb = new TransactionBuilder();
//        txb.addInput(txHash, 0);
//        txb.addOutput(scripts.elementAt(0), 100);
//        txb.sign(0, keyPair);
//        try {
//          expect(txb.setLockTime(65535), isArgumentError);
//        } catch(err) {
//          expect((err as ArgumentError).message, 'No, this would invalidate signatures');
//        }
//      });
//    });
//    group('sign', () {
//      fixtures['invalid']['sign'] as List<dynamic>..forEach((f) {
//        test('throws ${f['exception']} ${f['description'] != null ? f['description'] : ''}', () {
//          final txb = construct(f, true);
//          var threw = false;
//          final inputs = f['inputs'] as List;
//          for(var i = 0; i < inputs.length; i++) {
//            inputs[i]['signs'] as List<dynamic>..forEach((sign) {
//              final keyPairNetwork = NETWORKS[sign['network'] ?? f['network']];
//              final keyPair2 = ECPair.fromWIF(sign['keyPair'], network: keyPairNetwork);
//              if (sign['throws'] != null && sign['throws']) {
//                try {
//                  expect(txb.sign(i, keyPair2, sign['hashType']), isArgumentError);
//                } catch(err) {
//                  print(err);
//                  expect((err as ArgumentError).message, f['exception']);
//                }
//                threw = true;
//              } else {
//                txb.sign(i, keyPair2, sign['hashType']);
//              }
//            });
//          }
//          expect(threw, true);
//        });
//      });
//    });
    group('build', () {
//      fixtures['valid']['build'] as List<dynamic>..forEach((f) {
//        test('builds ${f['description']}', () {
//          final txb = construct(f);
//          final tx = f['incomplete'] != null ? txb.buildIncomplete() : txb.build();
//
//          expect(tx.toHex(), f['txHex']);
//        });
//      });
      fixtures['invalid']['build'] as List<dynamic>..forEach((f) {
        group('for ${f['description'] ?? f['exception']}', () {
          test('throws ${f['exception']}', () {
            try {
              TransactionBuilder txb;
              if (f['txHex'] != null) {
                txb = TransactionBuilder.fromTransaction(Transaction.fromHex(f['txHex']));
              } else {
                txb = construct(f);
              }
              expect(txb.build(), isArgumentError);
            } catch (err) {
              print(err);
              expect((err as ArgumentError).message, f['exception']);
            }
          });
        });
      });
    });
  });
}
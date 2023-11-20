import 'dart:typed_data';
// import 'package:bip32_defichain/src/utils/ecurve.dart' show isPoint;
import 'package:bs58check/bs58check.dart' as bs58check;

import '../crypto.dart';
import '../models/networks.dart';
import '../payments/index.dart' show PaymentData;
import '../utils/script.dart' as bscript;
import '../utils/constants/op.dart';

class P2SH {
  PaymentData? data;
  late NetworkType network;
  P2SH({required data, network}) {
    this.network = network ?? bitcoin;
    this.data = data;
    _init();
  }
  void _init() {
    data!.name = 'p2sh';

    if (data!.address == null && data!.hash == null && data!.output == null && data!.redeem == null && data!.input == null) throw ArgumentError('Not enough data');

    if (data!.address != null) {
      _getDataFromAddress(data!.address!);
      _getDataFromHash();
    }

    if (data!.hash != null) {
      _getDataFromHash();
    }

    if (data!.output != null) {
      if (data!.output!.length != 23 || data!.output![0] != OPS['OP_HASH160'] || data!.output![1] != 0x14 || data!.output![22] != OPS['OP_EQUAL']) {
        throw ArgumentError('Output is invalid');
      }
      final hash = data!.output!.sublist(2, 22);

      if (data!.hash != null && data!.hash.toString() != hash.toString()) {
        throw ArgumentError('Hash mismatch');
      }
      data!.hash = hash;
      _getDataFromHash();
    }

    if (data!.input != null) {
      _getDataFromInput();
      _checkRedeem(data!.redeem!);
      _getDataFromRedeem();
    }

    if (data!.redeem != null) {
      _checkRedeem(data!.redeem!);
      _getDataFromRedeem();
    }

    if (data!.witness != null) {
      if (data!.redeem != null && data!.redeem!.witness != null && !_stacksEqual(data!.redeem!.witness!, data!.witness!)) {
        throw ArgumentError('Witness and redeem.witness mismatch');
      }
    }
  }

  void _getDataFromAddress(String address) {
    var payload = bs58check.decode(address);
    final version = payload.buffer.asByteData().getUint8(0);
    if (version != network.scriptHash) {
      throw ArgumentError('Invalid version or Network mismatch');
    }

    final hash = payload.sublist(1);

    if (data!.hash != null && data!.hash.toString() != hash.toString()) {
      throw ArgumentError('Hash mismatch');
    }

    data!.hash = hash;

    if (data!.hash!.length != 20) throw ArgumentError('Invalid address');
  }

  void _getDataFromHash() {
    if (data!.address == null) {
      final payload = Uint8List(21);
      payload.buffer.asByteData().setUint8(0, network.scriptHash);
      payload.setRange(1, payload.length, data!.hash!);
      data!.address = bs58check.encode(payload);
    }

    data!.output ??= bscript.compile([
      OPS['OP_HASH160'],
      data!.hash,
      OPS['OP_EQUAL'],
    ]);
  }

  void _checkRedeem(PaymentData redeem) {
    // is the redeem output empty/invalid?
    if (redeem.output != null) {
      final decompile = bscript.decompile(redeem.output)!;
      if (decompile.isEmpty) {
        throw ArgumentError('Redeem.output too short');
      }

      // match hash against other sources
      final hash2 = hash160(redeem.output!);
      if (data!.hash != null && data!.hash!.isNotEmpty && (data!.hash.toString() != hash2.toString())) {
        throw ArgumentError('Hash mismatch');
      }
    }

    if (redeem.input != null) {
      final hasInput = redeem.input!.isNotEmpty;
      final hasWitness = redeem.witness != null && redeem.witness!.isNotEmpty;
      if (!hasInput && !hasWitness) {
        throw ArgumentError('Empty input');
      }
      if (hasInput && hasWitness) {
        throw ArgumentError('Input and witness provided');
      }
      if (hasInput) {
        final richunks = bscript.decompile(redeem.input);
        if (!bscript.isPushOnly(richunks)) {
          throw ArgumentError('Non push-only scriptSig');
        }
      }
    }
  }

  void _getDataFromRedeem() {
    if (data!.redeem!.output != null) {
      data!.hash = hash160(data!.redeem!.output!);
      _getDataFromHash();

      if (data!.redeem!.input != null) {
        var _chunks = bscript.decompile(data!.redeem!.input)!;
        _chunks.add(data!.redeem!.output);
        _getDataFromChunk(_chunks);
      }
    }

    data!.witness ??= data!.redeem!.witness ?? [];
  }

  void _getDataFromChunk([List<dynamic>? _chunks]) {
    if (data!.input == null && _chunks != null) {
      data!.input = bscript.compile(_chunks);
    }
  }

  void _getDataFromInput() {
    final chunks = _chunks();
    if (chunks == null || chunks.isEmpty) {
      throw ArgumentError('Input too short');
    }

    if (_redeem().output == null) throw ArgumentError('Input is invalid');

    data!.redeem ??= _redeem();
  }

  List<dynamic>? _chunks() {
    return bscript.decompile(data!.input);
  }

  PaymentData _redeem() {
    final chunks = bscript.decompile(data!.input)!;
    final output = chunks[chunks.length - 1] is Uint8List ? chunks[chunks.length - 1] : null;
    return PaymentData(
      output: output,
      input: bscript.compile(chunks.sublist(0, chunks.length - 1)),
      witness: data!.witness ?? [],
    );
  }

  bool _stacksEqual(List<Uint8List?> a, List<Uint8List?> b) {
    if (a.length != b.length) return false;
    var i = 0;
    return a.every((x) {
      final res = x.toString() == b[i].toString();
      i += 1;
      return res;
    });
  }
}
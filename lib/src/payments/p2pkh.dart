import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:bip32/src/utils/ecurve.dart' show isPoint;
import 'package:bs58check/bs58check.dart' as bs58check;

import '../crypto.dart';
import '../models/networks.dart';
import '../payments/index.dart' show PaymentData;
import '../utils/script.dart' as bscript;
import '../utils/constants/op.dart';

class P2PKH {
  late PaymentData data;
  late NetworkType network;
  P2PKH({required data, network}) {
    this.network = network ?? bitcoin;
    this.data = data;
    _init();
  }
  _init() {
    if (data.address != null) {
      _getDataFromAddress(data.address!);
      _getDataFromHash();
    } else if (data.hash != null) {
      _getDataFromHash();
    } else if (data.output != null) {
      if (!isValidOutput(data.output!))
        throw new ArgumentError('Output is invalid');
      data.hash = data.output!.sublist(3, 23);
      _getDataFromHash();
    } else if (data.pubkey != null) {
      data.hash = hash160(data.pubkey!);
      _getDataFromHash();
      _getDataFromChunk();
    } else if (data.input != null) {
      List<dynamic> _chunks = bscript.decompile(data.input)!;
      _getDataFromChunk(_chunks);
      if (_chunks.length != 2) throw new ArgumentError('Input is invalid');
      if (!bscript.isCanonicalScriptSignature(_chunks[0]))
        throw new ArgumentError('Input has invalid signature');
      if (!isPoint(_chunks[1]))
        throw new ArgumentError('Input has invalid pubkey');
    } else {
      throw new ArgumentError('Not enough data');
    }
  }

  void _getDataFromChunk([List<dynamic>? _chunks]) {
    if (data.pubkey == null && _chunks != null) {
      data.pubkey = (_chunks[1] is int)
          ? new Uint8List.fromList([_chunks[1]])
          : _chunks[1];
      data.hash = hash160(data.pubkey!);
      _getDataFromHash();
    }
    if (data.signature == null && _chunks != null)
      data.signature = (_chunks[0] is int)
          ? new Uint8List.fromList([_chunks[0]])
          : _chunks[0];
    if (data.input == null && data.pubkey != null && data.signature != null) {
      data.input = bscript.compile([data.signature, data.pubkey]);
    }
  }

  void _getDataFromHash() {
    if (data.address == null) {
      final payload = new Uint8List(21);
      payload.buffer.asByteData().setUint8(0, network.pubKeyHash);
      payload.setRange(1, payload.length, data.hash!);
      data.address = bs58check.encode(payload);
    }
    if (data.output == null) {
      data.output = bscript.compile([
        OPS['OP_DUP'],
        OPS['OP_HASH160'],
        data.hash,
        OPS['OP_EQUALVERIFY'],
        OPS['OP_CHECKSIG']
      ]);
    }
  }

  void _getDataFromAddress(String address) {
    Uint8List payload = bs58check.decode(address);
    final version = payload.buffer.asByteData().getUint8(0);
    if (version != network.pubKeyHash)
      throw new ArgumentError('Invalid version or Network mismatch');
    data.hash = payload.sublist(1);
    if (data.hash!.length != 20) throw new ArgumentError('Invalid address');
  }
}

isValidOutput(Uint8List data) {
  return data.length == 25 &&
      data[0] == OPS['OP_DUP'] &&
      data[1] == OPS['OP_HASH160'] &&
      data[2] == 0x14 &&
      data[23] == OPS['OP_EQUALVERIFY'] &&
      data[24] == OPS['OP_CHECKSIG'];
}

// Backward compatibility
@Deprecated(
    "The 'P2PKHData' class is deprecated. Use the 'PaymentData' package instead.")
class P2PKHData extends PaymentData {
  P2PKHData({address, hash, output, pubkey, input, signature, witness})
      : super(
            address: address,
            hash: hash,
            output: output,
            pubkey: pubkey,
            input: input,
            signature: signature,
            witness: witness);
}

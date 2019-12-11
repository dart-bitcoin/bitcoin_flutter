import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:bip32/src/utils/ecurve.dart' show isPoint;
import 'package:bech32/bech32.dart';

import '../crypto.dart';
import '../models/networks.dart';
import '../utils/script.dart' as bscript;
import '../utils/constants/op.dart';

class P2WPKH {
  P2WPKHData data;
  NetworkType network;
  P2WPKH({@required data, network}) {
    this.network = network ?? bitcoin;
    this.data = data;
    _init();
  }

  _init() {
    if (data.address == null && data.hash == null && data.output == null && data.pubkey == null && data.witness == null)
      throw new ArgumentError('Not enough data');
    if (data.address != null) {
      _getDataFromAddress(data.address);
    }
    if (data.hash != null) {
      _getDataFromHash();
    }
    if (data.output != null) {
      if (data.output.length != 22 || data.output[0] != OPS['OP_0'] || data.output[2] != 20) // 0x14
        throw new ArgumentError('Output is invalid');
      if (data.hash == null) {
        data.hash = data.output.sublist(2);
      }
      _getDataFromHash();
    }
    if (data.pubkey != null) {
      data.hash = hash160(data.pubkey);
      _getDataFromHash();
    }
    if (data.witness != null) {
      List<dynamic> _chunks = bscript.decompile(data.witness);
      _getDataFromChunk(_chunks);
      if (_chunks.length != 2)
        throw new ArgumentError('Witness is invalid');
      if (!bscript.isCanonicalScriptSignature(_chunks[0]))
        throw new ArgumentError('Input has invalid signature');
      if (!isPoint(_chunks[1]))
        throw new ArgumentError('Input has invalid pubkey');
    }
  }

  void _getDataFromChunk([List<dynamic> _chunks]) {
    if (data.pubkey == null && _chunks != null) {
      data.pubkey = (_chunks[1] is int) ? new Uint8List.fromList([_chunks[1]]) : _chunks[1];
      if (data.hash == null) {
        data.hash = hash160(data.pubkey);
      }
      _getDataFromHash();
    }
    if (data.signature == null && _chunks != null)
      data.signature = (_chunks[0] is int) ? new Uint8List.fromList([_chunks[0]]) : _chunks[0];
    if (data.witness == null && data.pubkey != null && data.signature != null) {
      data.witness = bscript.compile([data.signature, data.pubkey]);
    }
  }

  void _getDataFromHash() {
    if (data.address == null) {
      data.address = segwit.encode(Segwit(network.bech32, 0, data.hash));
    }
    if (data.output == null) {
      data.output = bscript.compile([ OPS['OP_0'], data.hash]);
    }
  }

  void _getDataFromAddress(String address) {
    Segwit _address = segwit.decode(data.address);
    if (network.bech32 != _address.hrp)
      throw new ArgumentError('Invalid prefix or Network mismatch');
    if (_address.version != 0)
      throw new ArgumentError('Invalid address version');
    if (_address.program.length != 20)
      throw new ArgumentError('Invalid address data');
    data.hash = _address.program;
  }
}

class P2WPKHData {
  String address;
  Uint8List hash;
  Uint8List output;
  Uint8List signature;
  Uint8List pubkey;
  Uint8List input;
  Uint8List witness;

  P2WPKHData(
      {this.address,
      this.hash,
      this.output,
      this.pubkey,
      this.input,
      this.signature,
      this.witness});

  @override
  String toString() {
    return 'P2WPKHData{address: $address, hash: $hash, output: $output, signature: $signature, pubkey: $pubkey, input: $input, witness: $witness}';
  }
}

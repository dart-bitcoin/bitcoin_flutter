import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:bip32/src/utils/ecurve.dart' show isPoint;
import 'package:bech32/bech32.dart';

import '../crypto.dart';
import '../models/networks.dart';
import '../payments/index.dart' show PaymentData;
import '../utils/script.dart' as bscript;
import '../utils/constants/op.dart';

class P2WPKH {
  final EMPTY_SCRIPT = Uint8List.fromList([]);

  late PaymentData data;
  late NetworkType network;
  P2WPKH({required data, network}) {
    this.network = network ?? bitcoin;
    this.data = data;
    _init();
  }

  _init() {
    if (data.address == null &&
        data.hash == null &&
        data.output == null &&
        data.pubkey == null &&
        data.witness == null) throw new ArgumentError('Not enough data');

    if (data.address != null) {
      _getDataFromAddress(data.address!);
    }

    if (data.hash != null) {
      _getDataFromHash();
    }

    if (data.output != null) {
      if (data.output!.length != 22 ||
          data.output![0] != OPS['OP_0'] ||
          data.output![1] != 20) // 0x14
        throw new ArgumentError('Output is invalid');
      if (data.hash == null) {
        data.hash = data.output!.sublist(2);
      }
      _getDataFromHash();
    }

    if (data.pubkey != null) {
      data.hash = hash160(data.pubkey!);
      _getDataFromHash();
    }

    if (data.witness != null) {
      if (data.witness!.length != 2)
        throw new ArgumentError('Witness is invalid');
      if (!bscript.isCanonicalScriptSignature(data.witness![0]!))
        throw new ArgumentError('Witness has invalid signature');
      if (!isPoint(data.witness![1]!))
        throw new ArgumentError('Witness has invalid pubkey');
      _getDataFromWitness(data.witness);
    } else if (data.pubkey != null && data.signature != null) {
      data.witness = [data.signature, data.pubkey];
      if (data.input == null) data.input = EMPTY_SCRIPT;
    }
  }

  void _getDataFromWitness([List<Uint8List?>? witness]) {
    if (data.input == null) {
      data.input = EMPTY_SCRIPT;
    }
    if (data.pubkey == null) {
      data.pubkey = witness![1];
      if (data.hash == null) {
        data.hash = hash160(data.pubkey!);
      }
      _getDataFromHash();
    }
    if (data.signature == null) data.signature = witness![0];
  }

  void _getDataFromHash() {
    if (data.address == null) {
      data.address = segwit.encode(Segwit(network.bech32!, 0, data.hash!));
    }
    if (data.output == null) {
      data.output = bscript.compile([OPS['OP_0'], data.hash]);
    }
  }

  void _getDataFromAddress(String address) {
    try {
      Segwit _address = segwit.decode(address);
      if (network.bech32 != _address.hrp)
        throw new ArgumentError('Invalid prefix or Network mismatch');
      if (_address.version != 0) // Only support version 0 now;
        throw new ArgumentError('Invalid address version');
      data.hash = Uint8List.fromList(_address.program);
    } on InvalidHrp {
      throw new ArgumentError('Invalid prefix or Network mismatch');
    } on InvalidProgramLength {
      throw new ArgumentError('Invalid address data');
    } on InvalidWitnessVersion {
      throw new ArgumentError('Invalid witness address version');
    }
  }
}

import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:bip32/src/utils/ecurve.dart' show isPoint;
import 'package:bs58check/bs58check.dart' as bs58check;

import '../crypto.dart';
import '../models/networks.dart';
import '../payments/index.dart' show PaymentData;
import '../utils/script.dart' as bscript;
import '../utils/constants/op.dart';

class P2PK {
  late PaymentData data;
  NetworkType? network;
  P2PK({required data, network}) {
    this.network = network ?? bitcoin;
    this.data = data;
    _init();
  }

  _init() {
    if (data.output != null) {
      if (data.output![data.output!.length - 1] != OPS['OP_CHECKSIG'])
        throw new ArgumentError('Output is invalid');
      if (!isPoint(data.output!.sublist(1, -1)))
        throw new ArgumentError('Output pubkey is invalid');
    }
    if (data.input != null) {
      // TODO
    }
  }
}

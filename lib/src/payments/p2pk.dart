
import 'package:bip32/src/utils/ecurve.dart' show isPoint;

import '../models/networks.dart';
import '../payments/index.dart' show PaymentData;
import '../utils/constants/op.dart';

class P2PK {
  final PaymentData data;
  late NetworkType network;
  P2PK({required this.data, NetworkType? network}) {
    this.network = network ?? bitcoin;
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

import 'dart:typed_data';
import 'models/networks.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:bech32/bech32.dart';
import 'payments/index.dart' show PaymentData;
import 'payments/p2pkh.dart';
import 'payments/p2wpkh.dart';

class Address {
  static bool validateAddress(String address, [NetworkType? nw]) {
    try {
      addressToOutputScript(address, nw);
      return true;
    } catch (err) {
      return false;
    }
  }

  static Uint8List addressToOutputScript(String address, [NetworkType? nw]) {
    NetworkType network = nw ?? bitcoin;
    var decodeBase58;
    var decodeBech32;
    try {
      decodeBase58 = bs58check.decode(address);
    } catch (err) {}
    if (decodeBase58 != null) {
      if (decodeBase58[0] != network.pubKeyHash) throw ArgumentError('Invalid version or Network mismatch');
      P2PKH p2pkh = P2PKH(data: PaymentData(address: address), network: network);
      return p2pkh.data.output!;
    } else {
      try {
        decodeBech32 = segwit.decode(address);
      } catch (err) {}
      if (decodeBech32 != null) {
        if (network.bech32 != decodeBech32.hrp) throw ArgumentError('Invalid prefix or Network mismatch');
        if (decodeBech32.version != 0) throw ArgumentError('Invalid address version');
        P2WPKH p2wpkh = P2WPKH(data: PaymentData(address: address), network: network);
        if (p2wpkh.data.output == null) throw ArgumentError('p2wpkh.data.output is null');
        return p2wpkh.data.output!;
      }
    }
    throw ArgumentError(address + ' has no matching Script');
  }
}

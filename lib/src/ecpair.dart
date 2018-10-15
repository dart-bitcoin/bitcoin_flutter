import 'dart:typed_data';
import 'package:bip32/src/utils/ecurve.dart' as ecc;
import 'package:bip32/src/utils/wif.dart' as wif;
import 'models/networks.dart';
import 'dart:math';
class ECPair {
  Uint8List _d;
  Uint8List _Q;
  NetworkType network;
  bool compressed;
  ECPair(Uint8List _d, Uint8List _Q, {network, compressed}) {
    this._d = _d;
    this._Q = _Q;
    this.network = network ?? bitcoin;
    this.compressed = compressed ?? true;
  }
  Uint8List get publicKey {
    if (_Q == null) _Q = ecc.pointFromScalar(_d, compressed);
    return _Q;
  }
  Uint8List get privateKey => _d;
  String toWIF() {
    if (privateKey == null) {
      throw new ArgumentError("Missing private key");
    }
    return wif.encode(new wif.WIF(
        version: network.wif,
        privateKey:  privateKey,
        compressed: compressed
    ));
  }
  sign(Uint8List hash) {
    return ecc.sign(hash, privateKey);
  }
  verify(Uint8List hash, Uint8List signature) {
    return ecc.verify(hash, publicKey, signature);
  }
  factory ECPair.fromWIF(String w, {NetworkType network}) {
    wif.WIF decoded = wif.decode(w);
    final version = decoded.version;
    // TODO support multi networks
    NetworkType nw;
    if (network != null) {
      nw = network;
      if (nw.wif != version) throw new ArgumentError("Invalid network version");
    } else {
      if (version == bitcoin.wif) {
        nw = bitcoin;
      } else if (version == testnet.wif) {
        nw = testnet;
      } else {
        throw new ArgumentError("Unknown network version");
      }
    }
    return ECPair.fromPrivateKey(decoded.privateKey, compressed: decoded.compressed, network: nw);
  }
  factory ECPair.fromPublicKey(Uint8List publicKey, {NetworkType network, bool compressed}) {
    if (!ecc.isPoint(publicKey)) {
      throw new ArgumentError("Point is not on the curve");
    }
    return new ECPair(null, publicKey, network: network, compressed: compressed);
  }
  factory ECPair.fromPrivateKey(Uint8List privateKey, {NetworkType network, bool compressed}) {
    if (privateKey.length != 32) throw new ArgumentError("Expected property privateKey of type Buffer(Length: 32)");
    if (!ecc.isPrivate(privateKey)) throw new ArgumentError("Private key not in range [1, n)");
    return new ECPair(privateKey, null, network: network, compressed: compressed);
  }
  factory ECPair.makeRandom({NetworkType network, bool compressed, Function rng}) {
    final rfunc = rng ?? _randomBytes;
    Uint8List d;
//    int beginTime = DateTime.now().millisecondsSinceEpoch;
    do {
      d = rfunc(32);
      if (d.length != 32) throw ArgumentError("Expected Buffer(Length: 32)");
//      if (DateTime.now().millisecondsSinceEpoch - beginTime > 5000) throw ArgumentError("Timeout");
    } while (!ecc.isPrivate(d));
    return ECPair.fromPrivateKey(d, network: network, compressed: compressed);
  }
}
const int _SIZE_BYTE = 255;
Uint8List _randomBytes(int size) {
  final rng = Random.secure();
  final bytes = Uint8List(size);
  for (var i = 0; i < size; i++) {
    bytes[i] = rng.nextInt(_SIZE_BYTE);
  }
  return bytes;
}
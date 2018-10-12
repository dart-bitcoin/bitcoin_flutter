import 'dart:typed_data';
import '../../src/crypto.dart';
import '../../src/models/networks.dart';
import 'package:bip32/src/utils/ecurve.dart' show isPoint;
import 'package:bs58check/bs58check.dart' as bs58check;
import '../utils/script.dart' as bscript;
import '../utils/constants/op.dart' as OPS;
import 'package:meta/meta.dart';
class P2PKH {
  P2PKHData data;
  NetworkType network;
  P2PKH({@required data, network}) {
    this.network = network ?? bitcoin;
    this.data = data;
    _init();
  }
  _init() {
    if (data.address != null) {
      AddressType _address = _getAddress(data.address);
      if (_address.version != network.pubKeyHash) throw new ArgumentError('Invalid version or Network mismatch');
      if (_address.hash.length != 20) throw new ArgumentError('Invalid address');
      data.hash = _address.hash;
      _getDataFromHash();
    } else if (data.hash != null) {
      _getDataFromHash();
    } else if (data.output != null) {
      if (data.output.length != 25 ||
          data.output[0] != OPS.OP_DUP ||
          data.output[1] != OPS.OP_HASH160 ||
          data.output[2] != 0x14 ||
          data.output[23] != OPS.OP_EQUALVERIFY ||
          data.output[24] != OPS.OP_CHECKSIG) throw new ArgumentError('Output is invalid');
      data.hash = data.output.sublist(3, 23);
      _getDataFromHash();
    } else if (data.pubkey != null) {
      data.hash = hash160(data.pubkey);
      _getDataFromHash();
      _getDataFromChunk();
    } else if (data.input != null) {
      List<Uint8List> _chunks = bscript.decompile(data.input);
      _getDataFromChunk(_chunks);
      if (_chunks.length != 2) throw new ArgumentError('Input is invalid');
      if (!bscript.isCanonicalScriptSignature(_chunks[0])) throw new ArgumentError('Input has invalid signature');
      if (!isPoint(_chunks[1])) throw new ArgumentError('Input has invalid pubkey');
    } else {
      throw new ArgumentError("Not enough data");
    }
  }
  void _getDataFromChunk([List<dynamic> _chunks]) {
    if (data.pubkey == null && _chunks != null) data.pubkey = (_chunks[1] is int) ? new Uint8List.fromList([_chunks[1]]) : _chunks[1];
    if (data.signature == null && _chunks != null) data.signature = (_chunks[0] is int) ? new Uint8List.fromList([_chunks[0]]) : _chunks[0];
    if (data.input == null && data.pubkey != null && data.signature != null) {
      Uint8List combine = Uint8List.fromList([data.pubkey, data.signature].expand((i) => i).toList(growable: false));
      data.input = bscript.compile(combine);
    }
  }
  void _getDataFromHash() {
    if (data.address == null) {
      final payload = new Uint8List(21);
      payload.buffer.asByteData().setUint8(0, network.pubKeyHash);
      payload.setRange(1, payload.length, data.hash);
      data.address = bs58check.encode(payload);
    }
    if (data.output == null) {
      data.output = bscript.compile([
        OPS.OP_DUP,
        OPS.OP_HASH160,
        data.hash,
        OPS.OP_EQUALVERIFY,
        OPS.OP_CHECKSIG
      ]);
    }
  }
  AddressType _getAddress(String address) {
    Uint8List payload = bs58check.decode(address);
    final version = payload.buffer.asByteData().getUint8(0);
    final hash = payload.sublist(1);
    return new AddressType(version: version, hash: hash);
  }
}

class AddressType {
  int version;
  Uint8List hash;

  AddressType({this.version, this.hash});

}
class P2pkhOutput {
  NetworkType network;
}
class P2PKHData {
  String address;
  Uint8List hash;
  Uint8List output;
  Uint8List signature;
  Uint8List pubkey;
  Uint8List input;
  P2PKHData({this.address, this.hash, this.output, this.pubkey, this.input});
}
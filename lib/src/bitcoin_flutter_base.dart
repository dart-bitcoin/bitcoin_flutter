// TODO: Put public facing types in this file.
import 'dart:typed_data';
import 'package:bip32/bip32.dart' show BIP32, fromSeed;
import 'package:bip39/bip39.dart' as bip39;
import 'models/networks.dart';
import 'package:hex/hex.dart';
import 'payments/p2pkh.dart';

/// Checks if you are awesome. Spoiler: you are.
class HDWallet {
  BIP32 _bip32;
  P2PKH _p2pkh;
  String passphrase;
  String seed;
  NetworkType network;
  String get privKey => _bip32 != null ? HEX.encode(_bip32.privateKey) : null;
  String get pubKey => _bip32 != null ? HEX.encode(_bip32.publicKey) : null;
  String get base58Priv => _bip32 != null ? _bip32.toBase58() : null;
  String get base58 => _bip32 != null ? _bip32.neutered().toBase58() : null;
  String get wif => _bip32 != null ? _bip32.toWIF() : null;
  String get address => _p2pkh != null ? _p2pkh.data.address : null;

  HDWallet({String passphrase, NetworkType network}) {
    if (passphrase != null) {
      this.passphrase = passphrase;
    } else {
      this.passphrase = bip39.generateMnemonic();
    }
    Uint8List seed = bip39.mnemonicToSeed(this.passphrase);
    this.network = network ?? bitcoin;
    this.seed = HEX.encode(seed);
    this._bip32 = fromSeed(seed);
    this._p2pkh = new P2PKH(data: new P2PKHData(pubkey: this._bip32.publicKey), network: network);
  }

}

import 'package:bitcoin_flutter/src/models/networks.dart';
import 'package:bitcoin_flutter/src/payments/index.dart' show PaymentData;
import 'package:bitcoin_flutter/src/payments/p2pkh.dart';
import 'package:test/test.dart';
import 'package:hex/hex.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;

void main() {
  group('bitcoin-dart (BIP32)', () {
    test('can import a BIP32 testnet xpriv and export to WIF', () {
      const xpriv =
          'tprv8ZgxMBicQKsPd7Uf69XL1XwhmjHopUGep8GuEiJDZmbQz6o58LninorQAfcKZWARbtRtfnLcJ5MQ2AtHcQJCCRUcMRvmDUjyEmNUWwx8UbK';
      final node = bip32.BIP32.fromBase58(
          xpriv,
          bip32.NetworkType(
              wif: testnet.wif,
              bip32: new bip32.Bip32Type(
                  public: testnet.bip32.public,
                  private: testnet.bip32.private)));
      expect(
          node.toWIF(), 'cQfoY67cetFNunmBUX5wJiw3VNoYx3gG9U9CAofKE6BfiV1fSRw7');
    });
    test('can export a BIP32 xpriv, then import it', () {
      const mnemonic =
          'praise you muffin lion enable neck grocery crumble super myself license ghost';
      final seed = bip39.mnemonicToSeed(mnemonic);
      final node = bip32.BIP32.fromSeed(seed);
      final string = node.toBase58();
      final restored = bip32.BIP32.fromBase58(string);
      expect(getAddress(node), getAddress(restored)); // same public key
      expect(node.toWIF(), restored.toWIF()); // same private key
    });
    test('can export a BIP32 xpub', () {
      const mnemonic =
          'praise you muffin lion enable neck grocery crumble super myself license ghost';
      final seed = bip39.mnemonicToSeed(mnemonic);
      final node = bip32.BIP32.fromSeed(seed);
      final string = node.neutered().toBase58();
      expect(string,
          'xpub661MyMwAqRbcGhVeaVfEBA25e3cP9DsJQZoE8iep5fZSxy3TnPBNBgWnMZx56oreNc48ZoTkQfatNJ9VWnQ7ZcLZcVStpaXLTeG8bGrzX3n');
    });
    test('can create a BIP32, bitcoin, account 0, external address', () {
      const path = "m/0'/0/0";
      final root = bip32.BIP32.fromSeed(HEX.decode(
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'));
      final child1 = root.derivePath(path);
      // option 2, manually
      final child1b = root.deriveHardened(0).derive(0).derive(0);
      expect(getAddress(child1), '1JHyB1oPXufr4FXkfitsjgNB5yRY9jAaa7');
      expect(getAddress(child1b), '1JHyB1oPXufr4FXkfitsjgNB5yRY9jAaa7');
    });
    test('can create a BIP44, bitcoin, account 0, external address', () {
      final root = bip32.BIP32.fromSeed(HEX.decode(
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'));
      final child1 = root.derivePath("m/44'/0'/0'/0/0");
      // option 2, manually
      final child1b = root
          .deriveHardened(44)
          .deriveHardened(0)
          .deriveHardened(0)
          .derive(0)
          .derive(0);
      expect(getAddress(child1), '12Tyvr1U8A3ped6zwMEU5M8cx3G38sP5Au');
      expect(getAddress(child1b), '12Tyvr1U8A3ped6zwMEU5M8cx3G38sP5Au');
    });
    /* TODO Support BIP49
    test('can create a BIP49, bitcoin testnet, account 0, external address', () {
    }); */
    test('can use BIP39 to generate BIP32 addresses', () {
      final mnemonic =
          'praise you muffin lion enable neck grocery crumble super myself license ghost';
      assert(bip39.validateMnemonic(mnemonic));
      final seed = bip39.mnemonicToSeed(mnemonic);
      final root = bip32.BIP32.fromSeed(seed);
      // receive addresses
      expect(getAddress(root.derivePath("m/0'/0/0")),
          '1AVQHbGuES57wD68AJi7Gcobc3RZrfYWTC');
      expect(getAddress(root.derivePath("m/0'/0/1")),
          '1Ad6nsmqDzbQo5a822C9bkvAfrYv9mc1JL');
      // change addresses
      expect(getAddress(root.derivePath("m/0'/1/0")),
          '1349KVc5NgedaK7DvuD4xDFxL86QN1Hvdn');
      expect(getAddress(root.derivePath("m/0'/1/1")),
          '1EAvj4edpsWcSer3duybAd4KiR4bCJW5J6');
    });
  });
}

String getAddress(node, [network]) {
  return P2PKH(data: new PaymentData(pubkey: node.publicKey), network: network)
      .data
      .address;
}

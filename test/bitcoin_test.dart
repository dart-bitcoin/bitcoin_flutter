import 'package:bitcoin_flutter/bitcoin_flutter.dart';
import 'package:test/test.dart';
import 'package:bip39/bip39.dart' as bip39;

void main() {
  group('bitcoin-dart (HDWallet)', () {
    var seed = bip39.mnemonicToSeed(
        'praise you muffin lion enable neck grocery crumble super myself license ghost');
    HDWallet hdWallet = new HDWallet.fromSeed(seed);
    test('valid seed', () {
      expect(hdWallet.seed,
          'f4f0cda65a9068e308fad4c96e8fe22213dd535fe7a7e91ca70c162a38a49aaacfe0dde5fafbbdf63cf783c2619db7174bc25cbfff574fb7037b1b9cec3d09b6');
    });
    test('valid address', () {
      expect(hdWallet.address, '12eUJoaWBENQ3tNZE52ZQaHqr3v4tTX4os');
    });
    test('valid public key', () {
      expect(hdWallet.base58,
          'xpub661MyMwAqRbcGhVeaVfEBA25e3cP9DsJQZoE8iep5fZSxy3TnPBNBgWnMZx56oreNc48ZoTkQfatNJ9VWnQ7ZcLZcVStpaXLTeG8bGrzX3n');
    });
    test('valid private key', () {
      expect(hdWallet.base58Priv,
          'xprv9s21ZrQH143K4DRBUU8Dp25M61mtjm9T3LsdLLFCXL2U6AiKEqs7dtCJWGFcDJ9DtHpdwwmoqLgzPrW7unpwUyL49FZvut9xUzpNB6wbEnz');
    });
  });
}

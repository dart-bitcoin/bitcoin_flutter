<a href="https://pub.dartlang.org/packages/bitcoin_flutter"><img alt="pub version" src="https://img.shields.io/pub/v/bitcoin_flutter.svg?style=flat-square"></a>

# bitcoin_flutter

A dart Bitcoin library for Flutter.

Released under the terms of the [MIT LICENSE](LICENSE).

Inspired by [bitcoinjs](https://github.com/bitcoinjs/bitcoinjs-lib)

Otherwise, pull requests are appreciated.

## Installing

[Flutter Packages](https://pub.dartlang.org/packages/bitcoin_flutter#-installing-tab-)

## Examples

```dart
import 'package:bitcoin_flutter/bitcoin_flutter.dart';
import 'package:bip39/bip39.dart' as bip39;

main() {
  var seed = bip39.mnemonicToSeed("praise you muffin lion enable neck grocery crumble super myself license ghost");
  var hdWallet = new HDWallet(seed);
  print(hdWallet.address);
  // => 12eUJoaWBENQ3tNZE52ZQaHqr3v4tTX4os
  print(hdWallet.pubKey);
  // => 0360729fb3c4733e43bf91e5208b0d240f8d8de239cff3f2ebd616b94faa0007f4
  print(hdWallet.privKey);
  // => 01304181d699cd89db7de6337d597adf5f78dc1f0784c400e41a3bd829a5a226
  print(hdWallet.wif);
  // => KwG2BU1ERd3ndbFUrdpR7ymLZbsd7xZpPKxsgJzUf76A4q9CkBpY
  
  var wallet = Wallet.fromWIF("Kxr9tQED9H44gCmp6HAdmemAzU3n84H3dGkuWTKvE23JgHMW8gct");
  print(wallet.address);
  // => 19AAjaTUbRjQCMuVczepkoPswiZRhjtg31
  print(wallet.pubKey);
  // => 03aea0dfd576151cb399347aa6732f8fdf027b9ea3ea2e65fb754803f776e0a509
  print(wallet.privKey);
  // => 3095cb26affefcaaa835ff968d60437c7c764da40cdd1a1b497406c7902a8ac9
  print(wallet.wif);
  // => Kxr9tQED9H44gCmp6HAdmemAzU3n84H3dGkuWTKvE23JgHMW8gct
}
```

The below examples are implemented as integration tests:
- [Generate a random address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/addresses_test.dart#L21)
- [Validating address](https://github.com/anicdh/bitcoin-dart/blob/master/test/address_test.dart)
- [Generate an address from a SHA256 hash](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/addresses_test.dart#L26)
- [Import an address via WIF](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/addresses_test.dart#L32)
- [Generate a Testnet address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/addresses_test.dart#L37)
- [Generate a Litecoin address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/addresses_test.dart#L45)
- [Generate a native Segwit address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/addresses_test.dart#L53)
- [Create a 1-to-1 Transaction](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/transactions_test.dart#L7)
- [Create a 2-to-2 Transaction](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/transactions_test.dart#L21)
- [Create a Transaction with a SegWit P2WPKH input](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/transactions_test.dart#L45)
- [Import a BIP32 testnet xpriv and export to WIF](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L9)
- [Export a BIP32 xpriv, then import it](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L14)
- [Export a BIP32 xpub](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L23)
- [Create a BIP32, bitcoin, account 0, external address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L30)
- [Create a BIP44, bitcoin, account 0, external address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L41)
- [Use BIP39 to generate BIP32 addresses](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L56)


### TODO
- Generate a SegWit P2SH address
- Generate a SegWit multisig address
- Create a Transaction with a P2SH(multisig) input
- Build a Transaction w/ psbt format
- Add Tapscript / Taproot feature

### Running the test suite

``` bash
pub run test
```

## Complementing Libraries
- [BIP39](https://github.com/anicdh/bip39) - Mnemonic generation for deterministic keys
- [BIP32](https://github.com/anicdh/bip32) - BIP32
- [Base58 Check](https://github.com/anicdh/bs58check-dart) - Base58 check encoding/decoding

## LICENSE [MIT](LICENSE)

</a> <a href="https://pub.dartlang.org/packages/bitcoin_flutter"><img alt="pub version" src="https://img.shields.io/pub/v/bitcoin_flutter.svg?style=flat-square"></a>

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
}
```

The below examples are implemented as integration tests:

- [Import a BIP32 testnet xpriv and export to WIF](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L9)
- [Export a BIP32 xpriv, then import it](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L14)
- [Export a BIP32 xpub](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L23)
- [Create a BIP32, bitcoin, account 0, external address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L30)
- [Create a BIP44, bitcoin, account 0, external address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L41)
- [Use BIP39 to generate BIP32 addresses](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L56)


### Running the test suite

``` bash
flutter test
```

## Complementing Libraries
- [BIP39](https://github.com/anicdh/bip39) - Mnemonic generation for deterministic keys
- [BIP32](https://github.com/anicdh/bip32) - BIP32
- [Base58 Check](https://github.com/anicdh/bs58check) - Base58 check encoding/decoding

## LICENSE [MIT](LICENSE)

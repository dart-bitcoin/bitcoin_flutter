# bitcoin-flutter

A dart Bitcoin library for Flutter.

Released under the terms of the [MIT LICENSE](LICENSE).

Inspired by [bitcoinjs](https://github.com/bitcoinjs/bitcoinjs-lib)

## Examples
The below examples are implemented as integration tests, they should be very easy to understand.
Otherwise, pull requests are appreciated.

- [Import a BIP32 testnet xpriv and export to WIF](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L9)
- [Export a BIP32 xpriv, then import it](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L14)
- [Export a BIP32 xpub](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L23)
- [Create a BIP32, bitcoin, account 0, external address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L30)
- [Create a BIP44, bitcoin, account 0, external address](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L41)
- [Use BIP39 to generate BIP32 addresses](https://github.com/anicdh/bitcoin-dart/blob/master/test/integration/bip32_test.dart#L56)


### Running the test suite

``` bash
pub run test
```

## Complementing Libraries
- [BIP39](https://github.com/anicdh/bip39) - Mnemonic generation for deterministic keys
- [BIP32](https://github.com/anicdh/bip32) - BIP32
- [Base58 Check](https://github.com/anicdh/bs58check) - Base58 check encoding/decoding

## LICENSE [MIT](LICENSE)

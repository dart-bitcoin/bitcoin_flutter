import 'package:bitcoin_dart/bitcoin_dart.dart';

main() {
  var hdWallet = new HDWallet(passphrase: "praise you muffin lion enable neck grocery crumble super myself license ghost");
  print(hdWallet.address);
  // => 12eUJoaWBENQ3tNZE52ZQaHqr3v4tTX4os
  print(hdWallet.pubKey);
  // => 0360729fb3c4733e43bf91e5208b0d240f8d8de239cff3f2ebd616b94faa0007f4
  print(hdWallet.privKey);
  // => 01304181d699cd89db7de6337d597adf5f78dc1f0784c400e41a3bd829a5a226
  print(hdWallet.wif);
  // => KwG2BU1ERd3ndbFUrdpR7ymLZbsd7xZpPKxsgJzUf76A4q9CkBpY
}

import 'package:bitcoin_flutter/bitcoin_flutter.dart';
import 'package:bip39/bip39.dart' as bip39;

main() {
  var seed = bip39.mnemonicToSeed(
      "praise you muffin lion enable neck grocery crumble super myself license ghost");
  var hdWallet = new HDWallet.fromSeed(seed);
  print(hdWallet.address);
  // => 12eUJoaWBENQ3tNZE52ZQaHqr3v4tTX4os
  print(hdWallet.pubKey);
  // => 0360729fb3c4733e43bf91e5208b0d240f8d8de239cff3f2ebd616b94faa0007f4
  print(hdWallet.privKey);
  // => 01304181d699cd89db7de6337d597adf5f78dc1f0784c400e41a3bd829a5a226
  print(hdWallet.wif);
  // => KwG2BU1ERd3ndbFUrdpR7ymLZbsd7xZpPKxsgJzUf76A4q9CkBpY

  var wallet =
      Wallet.fromWIF("Kxr9tQED9H44gCmp6HAdmemAzU3n84H3dGkuWTKvE23JgHMW8gct");
  print(wallet.address);
  // => 19AAjaTUbRjQCMuVczepkoPswiZRhjtg31
  print(wallet.pubKey);
  // => 03aea0dfd576151cb399347aa6732f8fdf027b9ea3ea2e65fb754803f776e0a509
  print(wallet.privKey);
  // => 3095cb26affefcaaa835ff968d60437c7c764da40cdd1a1b497406c7902a8ac9
  print(wallet.wif);
  // => Kxr9tQED9H44gCmp6HAdmemAzU3n84H3dGkuWTKvE23JgHMW8gct
}

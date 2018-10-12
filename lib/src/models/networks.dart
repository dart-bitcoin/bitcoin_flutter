class NetworkType {
  String messagePrefix;
  String bech32;
  Bip32Type bip32;
  int pubKeyHash;
  int scriptHash;
  int wif;

  NetworkType({this.messagePrefix, this.bech32, this.bip32, this.pubKeyHash,
      this.scriptHash, this.wif});

}
class Bip32Type {
  int public;
  int private;

  Bip32Type({this.public, this.private});

}
final bitcoin = new NetworkType(
  messagePrefix: '\x18Bitcoin Signed Message:\n',
  bech32: 'bc',
  bip32: new Bip32Type(
    public: 0x0488b21e,
    private: 0x0488ade4
  ),
  pubKeyHash: 0x00,
  scriptHash: 0x05,
  wif: 0x80
);
final testnet = new NetworkType(
  messagePrefix: '\x18Bitcoin Signed Message:\n',
  bech32: 'tb',
  bip32: new Bip32Type(
    public: 0x043587cf,
    private: 0x04358394
  ),
  pubKeyHash: 0x6f,
  scriptHash: 0xc4,
  wif: 0xef
);
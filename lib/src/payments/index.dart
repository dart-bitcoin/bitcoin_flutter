import 'dart:typed_data';

class PaymentData {
  String address;
  Uint8List hash;
  Uint8List output;
  Uint8List signature;
  Uint8List pubkey;
  Uint8List input;
  List<Uint8List> witness;

  PaymentData({
    this.address,
    this.hash,
    this.output,
    this.pubkey,
    this.input,
    this.signature,
    this.witness
  });

  @override
  String toString() {
    return 'PaymentData{address: $address, hash: $hash, output: $output, signature: $signature, pubkey: $pubkey, input: $input, witness: $witness}';
  }
}

// Backward compatibility
@Deprecated('The "P2PKHData" class is deprecated. Use the "PaymentData" package instead.')
class P2PKHData extends PaymentData {
  P2PKHData({address, hash, output, pubkey, input, signature, witness}) :
    super(
        address: address,
        hash: hash,
        output: output,
        pubkey: pubkey,
        input: input,
        signature: signature,
        witness: witness
    );
}

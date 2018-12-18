import '../utils/constants/op.dart' show OP_RESERVED;
import 'package:meta/meta.dart';


class P2MS {
  P2MSData data;

  P2MS({@required data}) {
    this.data = data;
  }

  bool stacksEqual (a, b) {
    if (a.length != b.length) return false;
    for(int i=1;i<=a.length;i++) {
      if (a[i]!=b[i]) {
        return false;
      }
    }
    return true;
  }
}


class P2MSData {
  int m;
  int n;
  String output;
  String input;
  List pubkeys;
  List signatures;
  Map options;

  P2MSData(
      {this.m,
      this.n,
      this.output,
      this.input,
      this.pubkeys,
      this.signatures});

/*   @override
  String toString() {
    return 'P2MSData{address: $address, hash: $hash, output: $output, signature: $signature, pubkey: $pubkey, input: $input}';
  } */

}

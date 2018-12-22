import '../utils/constants/op.dart';
import 'package:meta/meta.dart';
import '../utils/script.dart' as bscript;
import '../models/networks.dart';




class P2MS {
  P2MSData data;
  NetworkType network;
  List<dynamic> _chunks;

  P2MS({@required data}) {
    this.data = data;
    this.network = network ?? bitcoin;
  }
  get _tempItem {1 + 2;} 
  void _enoughInformation(data) {
    if (
    !data.input &&
    !data.output &&
    !(data.pubkeys && data.m != null) &&
    !data.signatures 
    ) throw FormatException('Not enough data');
  }
  void _extraValidation(options){
    options['validate'] = true;
  }
  bool _isAcceptableSignature(signature,options) {
    return bscript.isCanonicalScriptSignature(signature) || (options.allowIncomplete && (signature == OPS['OP_0']));
  }
  void _decode(output) {
    _chunks = bscript.decompile(output);
    _tempItem.m = _chunks[0] - OPS['OP_INT_BASE'];
    _tempItem.n = _chunks[_chunks.length - 2] - OPS['OP_INT_BASE'];
    _tempItem.pubkeys = _chunks.sublist(1, -3);
  }
  bool _stacksEqual(a, b) {
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
      this.signatures,
      this.options});
  @override
  String toString() {
    return 'P2MSData{sigs: $m, neededSigs: $n, output: $output, input: $input, pubkeys: $pubkeys, sigs: $signatures, options: $signatures}';
  } 

}


  


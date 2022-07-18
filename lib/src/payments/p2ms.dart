import '../utils/constants/op.dart';
import 'package:meta/meta.dart';
import '../utils/script.dart' as bscript;
import '../models/networks.dart';
import 'dart:typed_data';
import 'package:bip32/src/utils/ecurve.dart' show isPoint;

class P2MS {
  P2MSData data;
  NetworkType network;
  List<dynamic> _chunks;
  bool _isDecoded;

  P2MS({@required data}) {
    this.data = data;
    this.network = network ?? bitcoin;
    this._isDecoded = false;
    _init();
  }
  void _init() {
    _enoughInformation(data);
    _extraValidation(data.options);
    _setNetwork(this.network);
    _extendedValidation();
  }

  void _enoughInformation(data) {
    if (data.input == null &&
        data.output == null &&
        !((data.pubkeys  != null) && (data.m != null)) &&
        data.signatures == null) {
      throw new ArgumentError('Not enough data');
    }
  }
  void _setNetwork(network){
      this.network == network;
  }
  void _extraValidation(options) {
    if(data.options == null){data.options = {};}
    data.options['validate'] = true;
  }

  void _extendedValidation(){
    if(data.options['validate']==true){
      _check();
    }
  }
   void _decode(output){
     
    if(_isDecoded) {return;}
    else{
      _isDecoded = true;
      _chunks = bscript.decompile(output);
      data.m = _chunks[0] - OPS['OP_RESERVED'];
      data.n = _chunks[_chunks.length - 2] - OPS['OP_RESERVED'];
      data.pubkeys = _chunks.sublist(1,_chunks.length-2);
    }
  }
  void _setOutput(){
    if (data.m == null){ return;}
    if (data.n == null) {return;}
    if (data.pubkeys == null) {return;}
    List<dynamic> list = [OPS['OP_RESERVED']+data.m];
    data.pubkeys.forEach((pubkey) => list.add(pubkey));
    list.add(OPS['OP_RESERVED'] + data.n);
    list.add(OPS['OP_CHECKMULTISIG']);
    data.output = bscript.compile(list);
  }
  void _setSigs(){
    if (data.input == null) {return;}
    var list = bscript.decompile(data.input);
    list.removeAt(0);
    List<Uint8List> _chunks = [];
    
    for (var i = 0; i < list.length; i++) {
      dynamic temp = list[i];
      if(list[i] is int ){
        List<int> temp1 = [];
        temp1.add(list[i]);
        temp = Uint8List.fromList(temp1);
      }
      _chunks.add(temp);
    }
    
    data.signatures = _chunks;
  }
  void _setInput(){
    if (data.signatures == null) {return;}
    String tempString = 'OP_0 ';
    List<Uint8List> tempsignatures = [];
    for (var i = 0; i < data.signatures.length; i++) {
      if(data.signatures[i].toString()=='[0]'){
        tempString = tempString + 'OP_0 ';
      }else{
        tempsignatures.add(data.signatures[i]);
      }
    }
    tempString = tempString+(bscript.toASM(tempsignatures));
    Uint8List tempList = bscript.fromASM(tempString);
    data.input = bscript.compile(tempList);  
  }
  void _setWitness(){
    if (data.input == null && data.input == null) {return;}
    List <Uint8List> temp = [];
    data.witness = temp;
  }

  void _setM(){
    if (data.output == null) {return;}
    _decode(data.output);
  }
    void _setN(){
    _setPubkeys();
    if (data.pubkeys == null) {return;}
    data.n= data.pubkeys.length;
  }
    void _setPubkeys(){
    if (data.output == null) {return;}
    _decode(data.output);
  }
    bool _stacksEqual(a, b) {
    if (a.length != b.length) {return false;}
    for (int i = 0; i <= a.length-1; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
    bool _isAcceptableSignature(signature, options) {
    return (bscript.isCanonicalScriptSignature(signature) ||
        ((options['allowIncomplete'] == true) && (signature[0] == 0)));
  }
  void _check(){
    if (data.output != null){
      final tempChunks = bscript.decompile(data.output);
      if (tempChunks[0] == null) {throw new ArgumentError('Output is invalid');}
      if (tempChunks.length < 2 ) {throw new ArgumentError('Output is invalid');}
      if (tempChunks[tempChunks.length - 1] != OPS['OP_CHECKMULTISIG']) {throw new ArgumentError('Output is invalid');}
      _decode(data.output);
    if(data.m <= 0 ||
        data.n > 16 ||
        data.m > data.n ||
        data.n != _chunks.length - 3) {throw new ArgumentError('Output is invalid');}
    if (!data.pubkeys.every((x) => isPoint(x))) {throw new ArgumentError('Output is invalid');}
    if (data.m != null && data.m != data.m) {throw new ArgumentError('m mismatch');}
    if (data.n != null && data.n != data.n) {throw new ArgumentError('n mismatch');}
    if (data.pubkeys != null && !_stacksEqual(data.pubkeys, data.pubkeys)) {throw new ArgumentError('Pubkeys mismatch');}
  }
  if (data.pubkeys != null){
    if (data.n != null && data.n != data.pubkeys.length) {throw new ArgumentError('Pubkey count mismatch');}
    data.n = data.pubkeys.length;
    _setOutput();
    _setM();
    _setN();
    if (data.n < data.m) {throw new ArgumentError('Pubkey count cannot be less than m');}
  }
  if (data.signatures != null) {
    _setSigs();
    _setInput();
    if (data.signatures.length < data.m) {throw new ArgumentError('Not enough signatures provided');}
    if (data.signatures.length > data.m) {throw new ArgumentError('Too many signatures provided');}
    }

    
  if (data.input != null) {
      if (data.input[0] != OPS['OP_0']) {throw new ArgumentError('Input is invalid');}
      _setSigs();
      if (data.signatures.length == 0 || !data.signatures.every((x) => _isAcceptableSignature(x,data.options)))
      {throw new ArgumentError('Input has invalid signature(s)');}
      if (data.signatures != null&& !_stacksEqual(data.signatures,data.signatures)) {throw new ArgumentError('Signature mismatch');}
      if (data.m != null && data.m != data.signatures.length) {throw new ArgumentError('Signature count mismatch');}
    }
  _setInput();
  _setWitness();
  }
  

}


class P2MSData {
  int m;
  int n;
  Uint8List output;
  Uint8List input;
  List<dynamic> pubkeys;
  List<Uint8List> signatures;
  List<Uint8List> witness;
  Map options;

  P2MSData(
      {this.m,
      this.n,
      this.output,
      this.input,
      this.pubkeys,
      this.signatures,
      this.witness,
      this.options});
  @override
  String toString() {
    return 'P2MSData{m: $m, n: $n, output: $output, input: $input, pubkeys: $pubkeys, sigs: $signatures, options: $signatures, witness: $witness}';
  }
}

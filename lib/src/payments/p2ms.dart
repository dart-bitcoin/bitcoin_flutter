import '../utils/constants/op.dart';
import 'package:meta/meta.dart';
import '../utils/script.dart' as bscript;
import '../models/networks.dart';
import 'dart:typed_data';
import 'package:bip32/src/utils/ecurve.dart' show isPoint;
//Notes
//OP_Reserved<OP_INT_BASE https://github.com/bitcoinjs/bitcoinjs-lib/issues/1242
class P2MS {
  P2MSData data;
  NetworkType network;
  List<dynamic> _chunks;
  Map _temp;
  bool _isDecoded;

  P2MS({@required data}) {
    this.data = data;
    this.network = network ?? bitcoin;
    this._isDecoded = false;
    this._temp = {};
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
      _temp['network'] == network;
  }
  void _extraValidation(options) {
    if(data.options == null){data.options = {};}
    data.options['validate'] = true;
  }

  void _extendedValidation(){
    if(data.options['validate']==true){
      _check();
    }
    _assignVariables();
  }
   void _decode(output){
     
    if(_isDecoded) {return;}
    else{
      _isDecoded = true;
      _chunks = bscript.decompile(output);
      _temp['m'] = _chunks[0] - OPS['OP_RESERVED'];
      _temp['n'] = _chunks[_chunks.length - 2] - OPS['OP_RESERVED'];
      _temp['pubkeys'] = _chunks.sublist(1,_chunks.length-2);
    }
  }
  void _setOutput(){
    if (data.m == null){ return;}
    if (_temp['n'] == null) {return;}
    if (data.pubkeys == null) {return;}
    List<dynamic> list = [OPS['OP_RESERVED']+data.m];
    data.pubkeys.forEach((pubkey) => list.add(pubkey));
    list.add(OPS['OP_RESERVED'] + _temp['n']);
    list.add(OPS['OP_CHECKMULTISIG']);
    _temp['output'] = bscript.compile(list);
  }
  void _setSigs(){
    if (data.input == null) {return;}
    var list = bscript.decompile(data.input);
    list.removeAt(0);
    List<Uint8List> uintList = [];
    for (var i = 0; i < list.length; i++) {
      uintList.add(list[i]);
    }
    
    _temp['signatures'] = uintList;

    //print(bscript.toASM(_temp['signatures']));
  }
  void _setInput(){
    print(data.signatures);
    print('ran');
    if (data.signatures == null) {return;}
    String tempString = 'OP_0 ';
    tempString = tempString+(bscript.toASM(data.signatures));
    //print(tempString);
    Uint8List tempList = bscript.fromASM(tempString);
    _temp['input'] = bscript.compile(tempList);
    _setWitness();   
  }
  void _setWitness(){
    //print(_temp['input']);
    if (_temp['input'] == null) {return;}
    List <Uint8List> temp = [];
    _temp['witness'] = temp;
    
    
  }

  void _setM(){
    if (_temp['output'] == null) {return;}
    _decode(_temp['output']);
  }
    void _setN(){
    if (_temp['pubkeys'] == null) {return;}
    _temp['n']= _temp['pubkeys'].length;
  }
    void _setPubkeys(){
    if (data.output == null) {return;}
    _decode(data.output);
  }
  void _assignVariables(){
    if (_temp['m'] != null) {data.m = _temp['m'];}
    if (_temp['n'] != null) {data.n = _temp['n'];}
    if (_temp['output'] != null) {data.output = _temp['output'];}
    if (_temp['pubkeys'] != null) {data.pubkeys = _temp['pubkeys'];}
    if (_temp['signatures'] != null) {data.signatures = _temp['signatures'];}
    if (_temp['input'] != null) {data.input= _temp['input'];}
    if (_temp['witness'] != null) {data.witness= _temp['witness'];}
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
        ((options['allowIncomplete'] == true) && (signature == OPS['OP_0'])));
  }
  void _check(){
    if (data.output != null){
      final temp = bscript.decompile(data.output);
      if (temp[0] == null) {throw new ArgumentError('Output is invalid');}
      if (temp.length < 2 ) {throw new ArgumentError('Output is invalid');}
      if (temp[temp.length - 1] != OPS['OP_CHECKMULTISIG']) {throw new ArgumentError('Output is invalid');}
      _decode(data.output);
    if(_temp['m'] <= 0 ||
        _temp['n'] > 16 ||
        _temp['m'] > _temp['n'] ||
        _temp['n'] != _chunks.length - 3) {throw new ArgumentError('Output is invalid');}
    if (!_temp['pubkeys'].every((x) => isPoint(x))) {throw new ArgumentError('Output is invalid');}
    if (data.m != null && data.m != _temp['m']) {throw new ArgumentError('m mismatch');}
    if (data.n != null && data.n != _temp['n']) {throw new ArgumentError('n mismatch');}
    if (data.pubkeys != null && !_stacksEqual(data.pubkeys, _temp['pubkeys'])) {throw new ArgumentError('Pubkeys mismatch');}
  }
  if (data.pubkeys != null){
    if (data.n != null && data.n != data.pubkeys.length) {throw new ArgumentError('Pubkey count mismatch');}
    _temp['n'] = data.pubkeys.length;
    _setOutput();
    _setM();
    if (_temp['n'] < _temp['m']) {throw new ArgumentError('Pubkey count cannot be less than m');}
  }
  if (data.signatures != null) {
    _setSigs();
    _setInput();
    if (data.signatures.length < _temp['m']) {throw new ArgumentError('Not enough signatures provided');}
    if (data.signatures.length > _temp['m']) {throw new ArgumentError('Too many signatures provided');}
    }

    
  if (data.input != null) {
      if (data.input[0] != OPS['OP_0']) {throw new ArgumentError('Input is invalid');}
      _setSigs();
      if (_temp['signatures'].length == 0 || !_temp['signatures'].every((x) => _isAcceptableSignature(x,data.options)))
      {throw new ArgumentError('Input has invalid signature(s)');}
      if (data.signatures != null&& !_stacksEqual(data.signatures,_temp['signatures'])) {throw new ArgumentError('Signature mismatch');}
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

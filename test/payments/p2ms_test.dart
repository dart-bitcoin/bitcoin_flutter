import 'package:bitcoin_flutter/src/payments/p2ms.dart';
import 'package:test/test.dart';
import 'package:bitcoin_flutter/src/utils/script.dart' as bscript;
import 'dart:io';
import 'dart:convert';
import 'package:hex/hex.dart';
import 'dart:typed_data';

main() {
  final fixtures = json.decode(new File("./test/fixtures/p2ms.json").readAsStringSync(encoding: utf8));
   group('(valid case)', () {
    (fixtures["valid"] as List<dynamic>).forEach((f) {
      test(f['description'] + ' as expected', () {
        final arguments = _preformP2MS(f['arguments'], f['options']);
        final p2ms = new P2MS(data: arguments);
        expect(p2ms.data.m, f['expected']['m']);
        expect(p2ms.data.n, f['expected']['n']);
        expect(_toDataForm(p2ms.data.output), f['expected']['output']); 
        expect(p2ms.data.pubkeys, _convertToList(f['expected']['pubkeys']));
        expect(p2ms.data.signatures, _convertSigs(f['expected']['signatures']));
        expect(_toDataForm(p2ms.data.input), f['expected']['input']);
        expect(_toDataForm(p2ms.data.witness), f['expected']['witness']);
        
      });
    });
  }); 
  group('(invalid case)', () {
    (fixtures["invalid"] as List<dynamic>).forEach((f) {
      test('throws ' + f['exception'] + (f['description'] != null ? ('for ' + f['description']) : ''), () {
        final arguments = _preformP2MS(f['arguments'], f['options']);
        try {
          expect(new P2MS(data: arguments), isArgumentError);
        } catch(err) {
          expect((err as ArgumentError).message, f['exception']);
        }

      });
    });
  });
}
P2MSData _preformP2MS(dynamic x, option) {
  final m = x['m'] != null ? x['m'] : null;
  final n = x['n'] != null ? x['n'] : null;
  final input = x['input'] != null ? bscript.fromASM(x['input']) : null;
  final output = x['output'] != null ? bscript.fromASM(x['output']) : x['outputHex'] != null ? HEX.decode(x['outputHex']) : null;
  final pubkeys = x['pubkeys']!= null ? _convertToList(x['pubkeys']) : null;
  final signatures = x['signatures']!= null ? _convertSigs(x['signatures']) : null;
  final witness = x['witness'];
  final options = option;

  return new P2MSData(m: m, n: n, input: input, output: output, pubkeys: pubkeys, signatures: signatures, witness: witness, options: options);
}
dynamic _convertSigs(dynamic x){
  if (x == null){return null;}
  else{ List<Uint8List> properList = [];
        for( var i = 0; i < x.length; i++ ) {
          if(x[i]==0){properList.add(HEX.decode('0'));}
          else{ 
          properList.add(HEX.decode(x[i]));}
        } 
      return properList;}
}
List<dynamic> _convertToList(dynamic x){
  List<Uint8List> properList = [];
  for( var i = 0; i < x.length; i++ ) { 
    var temp = x[i];
    properList.add(HEX.decode(temp));
   } 
  return properList;}

dynamic _toDataForm(dynamic x) {
  if (x == null) {
    return null;
  }
  if (x is Uint8List) {
    return bscript.toASM(x);
  }
  if (x is List<dynamic>) {
    List<dynamic> temp = [];
    for (var i = 0 ; i < x.length; i++ ) { 
      temp.add(x[0]); 
   } 

    return temp;
  }
  return '';
}

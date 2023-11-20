import 'dart:typed_data';
import '../utils/script.dart' as bscript;
import '../utils/constants/op.dart';

bool inputCheck(List<dynamic> chunks) {
  return chunks.length == 1 && bscript.isCanonicalScriptSignature(chunks[0]);
}

// bool outputCheck(Uint8List script) {
//   // TODO
// }

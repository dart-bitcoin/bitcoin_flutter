import 'dart:typed_data';
import '../utils/script.dart' as bscript;
import '../utils/constants/op.dart';

bool inputCheck(List<dynamic> chunks) {
  return chunks != null &&
      chunks.length == 2 &&
      bscript.isCanonicalScriptSignature(chunks[0]) &&
      bscript.isCanonicalPubKey(chunks[1]);
}

bool outputCheck(Uint8List script) {
  final buffer = bscript.compile(script)!;
  return buffer.length == 22 && buffer[0] == OPS['OP_0'] && buffer[1] == 0x14;
}

import 'dart:typed_data';
import '../utils/script.dart' as bscript;
import './pubkeyhash.dart' as p2pkh;
import './witnesspubkeyhash.dart' as p2wpkh;
import '../utils/constants/op.dart';

bool inputCheck(List<dynamic> chunks, bool allowIncomplete) {
  if (chunks.isEmpty) return false;

  final lastChunk = chunks.last;

  if (!(lastChunk is Uint8List)) return false;

  final scriptSigChunks = bscript.decompile(
    bscript.compile(chunks.sublist(0, chunks.length - 1)),
  );

  final redeemScriptChunks = bscript.decompile(lastChunk);
  // is redeemScript a valid script?
  if (redeemScriptChunks == null) return false;
  // is redeemScriptSig push only?
  if (!bscript.isPushOnly(scriptSigChunks)) return false;
  // is witness?
  if (chunks.length == 1) {
    // TODO p2wsh
    return p2wpkh.outputCheck(bscript.compile(redeemScriptChunks)!);
  }

  if (p2pkh.inputCheck(scriptSigChunks!) &&
      p2pkh.outputCheck(bscript.compile(redeemScriptChunks)!)) {
    return true;
  }

  return false;
}

bool outputCheck(Uint8List script) {
  final buffer = bscript.compile(script)!;
  return buffer.length == 23 &&
      buffer[0] == OPS['OP_HASH160'] &&
      buffer[1] == 0x14 &&
      buffer[22] == OPS['OP_EQUAL'];
}

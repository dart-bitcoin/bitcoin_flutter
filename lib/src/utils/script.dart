import 'dart:typed_data';
import '../utils/constants/op.dart' as OPS;
import '../utils/push_data.dart' as pushData;
const OP_INT_BASE = OPS.OP_RESERVED;
Uint8List compile(List<dynamic> chunks) {
  final bufferSize = chunks.fold(0, (acc, chunk) {
    if (chunk is int) return acc + 1;
    if (chunk.length == 1 && asMinimalOP(chunk) != null) {
      return acc + 1;
    }
    return acc + pushData.encodingLength(chunk.length) + chunk.length;
  });
  var buffer = new Uint8List(bufferSize);

  var offset = 0;
  chunks.forEach((chunk) {
    // data chunk
    if (chunk is Uint8List) {
    // adhere to BIP62.3, minimal push policy
      final opcode = asMinimalOP(chunk);
      if (opcode != null) {
        buffer.buffer.asByteData().setUint8(offset, opcode);
        offset += 1;
        return null;
      }
      pushData.EncodedPushData epd = pushData.encode(buffer, chunk.length, offset);
      offset += epd.size;
      buffer = epd.buffer;
      buffer.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    // opcode
    } else {
      buffer.buffer.asByteData().setUint8(offset, chunk);
      offset += 1;
    }
  });

  if (offset != buffer.length) throw new ArgumentError("Could not decode chunks");
  return buffer;
}

List<dynamic> decompile(Uint8List buffer) {
  List<dynamic> chunks = [];
  var i = 0;

  while (i < buffer.length) {
    final opcode = buffer[i];

    // data chunk
    if ((opcode > OPS.OP_0) && (opcode <= OPS.OP_PUSHDATA4)) {
      final d = pushData.decode(buffer, i);

      // did reading a pushDataInt fail?
      if (d == null) return null;
      i += d.size;

      // attempt to read too much data?
      if (i + d.number > buffer.length) return null;

      final data = buffer.sublist(i, i + d.number);
      i += d.number;

      // decompile minimally
      final op = asMinimalOP(data);
      if (op != null) {
        chunks.add(op);
      } else {
        chunks.add(data);
      }

      // opcode
    } else {
      chunks.add(opcode);
      i += 1;
    }
  }
  return chunks;
}
int asMinimalOP (Uint8List buffer) {
  if (buffer.length == 0) return OPS.OP_0;
  if (buffer.length != 1) return null;
  if (buffer[0] >= 1 && buffer[0] <= 16) return OP_INT_BASE + buffer[0];
  if (buffer[0] == 0x81) return OPS.OP_1NEGATE;
  return null;
}
bool isDefinedHashType (hashType) {
  final hashTypeMod = hashType & ~0x80;
  // return hashTypeMod > SIGHASH_ALL && hashTypeMod < SIGHASH_SINGLE
  return hashTypeMod > 0x00 && hashTypeMod < 0x04;
}
bool isCanonicalScriptSignature (Uint8List buffer) {
  if (!isDefinedHashType(buffer[buffer.length - 1])) return false;
  return bip66check(buffer.sublist(0, buffer.length - 1));
}
bool bip66check (buffer) {
  if (buffer.length < 8) return false;
  if (buffer.length > 72) return false;
  if (buffer[0] != 0x30) return false;
  if (buffer[1] != buffer.length - 2) return false;
  if (buffer[2] != 0x02) return false;

  var lenR = buffer[3];
  if (lenR == 0) return false;
  if (5 + lenR >= buffer.length) return false;
  if (buffer[4 + lenR] != 0x02) return false;

  var lenS = buffer[5 + lenR];
  if (lenS == 0) return false;
  if ((6 + lenR + lenS) != buffer.length) return false;

  if (buffer[4] & 0x80) return false;
  if (lenR > 1 && (buffer[4] == 0x00) && !(buffer[5] & 0x80)) return false;

  if (buffer[lenR + 6] & 0x80) return false;
  if (lenS > 1 && (buffer[lenR + 6] == 0x00) && !(buffer[lenR + 7] & 0x80)) return false;
  return true;
}

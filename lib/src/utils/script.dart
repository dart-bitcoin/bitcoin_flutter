import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:bip32/src/utils/ecurve.dart' as ecc;
import 'constants/op.dart';
import 'push_data.dart' as pushData;
import 'check_types.dart';

Map<int, String> REVERSE_OPS =
    OPS.map((String string, int number) => new MapEntry(number, string));
final OP_INT_BASE = OPS['OP_RESERVED'];
final ZERO = Uint8List.fromList([0]);

Uint8List? compile(List<dynamic> chunks) {
  final bufferSize = chunks.fold(0, (dynamic acc, chunk) {
    if (chunk is int) return acc + 1;
    if (chunk.length == 1 && asMinimalOP(chunk) != null) {
      return acc + 1;
    }
    return acc + pushData.encodingLength(chunk.length) + chunk.length;
  });
  Uint8List? buffer = new Uint8List(bufferSize);

  var offset = 0;
  chunks.forEach((chunk) {
    // data chunk
    if (chunk is Uint8List) {
      // adhere to BIP62.3, minimal push policy
      final opcode = asMinimalOP(chunk);
      if (opcode != null) {
        buffer!.buffer.asByteData().setUint8(offset, opcode);
        offset += 1;
        return null;
      }
      pushData.EncodedPushData epd =
          pushData.encode(buffer, chunk.length, offset);
      offset += epd.size!;
      buffer = epd.buffer;
      buffer!.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
      // opcode
    } else {
      buffer!.buffer.asByteData().setUint8(offset, chunk);
      offset += 1;
    }
  });

  if (offset != buffer!.length)
    throw new ArgumentError("Could not decode chunks");
  return buffer;
}

List<dynamic>? decompile(dynamic buffer) {
  List<dynamic> chunks = [];

  if (buffer == null) return chunks;
  if (buffer is List && buffer.length == 2) return buffer;

  var i = 0;
  while (i < buffer.length) {
    final opcode = buffer[i];

    // data chunk
    if ((opcode > OPS['OP_0']) && (opcode <= OPS['OP_PUSHDATA4'])) {
      final d = pushData.decode(buffer, i);

      // did reading a pushDataInt fail?
      if (d == null) return null;
      i += d.size!;

      // attempt to read too much data?
      if (i + d.number! > buffer.length) return null;

      final data = buffer.sublist(i, i + d.number!);
      i += d.number!;

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

Uint8List? fromASM(String? asm) {
  if (asm == '') return Uint8List.fromList([]);
  return compile(asm!.split(' ').map((chunkStr) {
    if (OPS[chunkStr] != null) return OPS[chunkStr];
    return HEX.decode(chunkStr);
  }).toList());
}

String toASM(List<dynamic> c) {
  List<dynamic>? chunks;
  if (c is Uint8List) {
    chunks = decompile(c);
  } else {
    chunks = c;
  }
  return chunks!.map((chunk) {
    // data?
    if (chunk is Uint8List) {
      final op = asMinimalOP(chunk);
      if (op == null) return HEX.encode(chunk);
      chunk = op;
    }
    // opcode!
    return REVERSE_OPS[chunk];
  }).join(' ');
}

int? asMinimalOP(Uint8List buffer) {
  if (buffer.length == 0) return OPS['OP_0'];
  if (buffer.length != 1) return null;
  if (buffer[0] >= 1 && buffer[0] <= 16) return OP_INT_BASE! + buffer[0];
  if (buffer[0] == 0x81) return OPS['OP_1NEGATE'];
  return null;
}

bool isDefinedHashType(hashType) {
  final hashTypeMod = hashType & ~0x80;
  // return hashTypeMod > SIGHASH_ALL && hashTypeMod < SIGHASH_SINGLE
  return hashTypeMod > 0x00 && hashTypeMod < 0x04;
}

bool isCanonicalPubKey(Uint8List buffer) {
  return ecc.isPoint(buffer);
}

bool isCanonicalScriptSignature(Uint8List buffer) {
  if (!isDefinedHashType(buffer[buffer.length - 1])) return false;
  return bip66check(buffer.sublist(0, buffer.length - 1));
}

bool bip66check(buffer) {
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

  if (buffer[4] & 0x80 != 0) return false;
  if (lenR > 1 && (buffer[4] == 0x00) && buffer[5] & 0x80 == 0) return false;

  if (buffer[lenR + 6] & 0x80 != 0) return false;
  if (lenS > 1 && (buffer[lenR + 6] == 0x00) && buffer[lenR + 7] & 0x80 == 0)
    return false;
  return true;
}

Uint8List bip66encode(r, s) {
  var lenR = r.length;
  var lenS = s.length;
  if (lenR == 0) throw new ArgumentError('R length is zero');
  if (lenS == 0) throw new ArgumentError('S length is zero');
  if (lenR > 33) throw new ArgumentError('R length is too long');
  if (lenS > 33) throw new ArgumentError('S length is too long');
  if (r[0] & 0x80 != 0) throw new ArgumentError('R value is negative');
  if (s[0] & 0x80 != 0) throw new ArgumentError('S value is negative');
  if (lenR > 1 && (r[0] == 0x00) && r[1] & 0x80 == 0)
    throw new ArgumentError('R value excessively padded');
  if (lenS > 1 && (s[0] == 0x00) && s[1] & 0x80 == 0)
    throw new ArgumentError('S value excessively padded');

  var signature = new Uint8List(6 + lenR + lenS as int);

  // 0x30 [total-length] 0x02 [R-length] [R] 0x02 [S-length] [S]
  signature[0] = 0x30;
  signature[1] = signature.length - 2;
  signature[2] = 0x02;
  signature[3] = r.length;
  signature.setRange(4, 4 + lenR as int, r);
  signature[4 + lenR as int] = 0x02;
  signature[5 + lenR as int] = s.length;
  signature.setRange(6 + lenR as int, 6 + lenR + lenS as int, s);
  return signature;
}

Uint8List encodeSignature(Uint8List signature, int hashType) {
  if (!isUint(hashType, 8)) throw ArgumentError("Invalid hasType $hashType");
  if (signature.length != 64) throw ArgumentError("Invalid signature");
  final hashTypeMod = hashType & ~0x80;
  if (hashTypeMod <= 0 || hashTypeMod >= 4)
    throw new ArgumentError('Invalid hashType $hashType');

  final hashTypeBuffer = new Uint8List(1);
  hashTypeBuffer.buffer.asByteData().setUint8(0, hashType);
  final r = toDER(signature.sublist(0, 32));
  final s = toDER(signature.sublist(32, 64));
  List<int> combine = List.from(bip66encode(r, s));
  combine.addAll(List.from(hashTypeBuffer));
  return Uint8List.fromList(combine);
}

Uint8List toDER(Uint8List x) {
  var i = 0;
  while (x[i] == 0) ++i;
  if (i == x.length) return ZERO;
  x = x.sublist(i);
  List<int> combine = List.from(ZERO);
  combine.addAll(x);
  if (x[0] & 0x80 != 0) return Uint8List.fromList(combine);
  return x;
}

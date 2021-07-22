import 'dart:typed_data';
import 'constants/op.dart';

class DecodedPushData {
  int? opcode;
  int? number;
  int? size;

  DecodedPushData({this.opcode, this.number, this.size});
}

class EncodedPushData {
  int? size;
  Uint8List? buffer;

  EncodedPushData({this.size, this.buffer});
}

EncodedPushData encode(Uint8List buffer, number, offset) {
  var size = encodingLength(number);
  // ~6 bit
  if (size == 1) {
    buffer.buffer.asByteData().setUint8(offset, number);

    // 8 bit
  } else if (size == 2) {
    buffer.buffer.asByteData().setUint8(offset, OPS['OP_PUSHDATA1']!);
    buffer.buffer.asByteData().setUint8(offset + 1, number);

    // 16 bit
  } else if (size == 3) {
    buffer.buffer.asByteData().setUint8(offset, OPS['OP_PUSHDATA2']!);
    buffer.buffer.asByteData().setUint16(offset + 1, number, Endian.little);

    // 32 bit
  } else {
    buffer.buffer.asByteData().setUint8(offset, OPS['OP_PUSHDATA4']!);
    buffer.buffer.asByteData().setUint32(offset + 1, number, Endian.little);
  }

  return new EncodedPushData(size: size, buffer: buffer);
}

DecodedPushData? decode(Uint8List bf, int offset) {
  ByteBuffer buffer = bf.buffer;
  int opcode = buffer.asByteData().getUint8(offset);
  int number, size;

  // ~6 bit
  if (opcode < OPS['OP_PUSHDATA1']!) {
    number = opcode;
    size = 1;

    // 8 bit
  } else if (opcode == OPS['OP_PUSHDATA1']) {
    if (offset + 2 > buffer.lengthInBytes) return null;
    number = buffer.asByteData().getUint8(offset + 1);
    size = 2;

    // 16 bit
  } else if (opcode == OPS['OP_PUSHDATA2']) {
    if (offset + 3 > buffer.lengthInBytes) return null;
    number = buffer.asByteData().getUint16(offset + 1);
    size = 3;

    // 32 bit
  } else {
    if (offset + 5 > buffer.lengthInBytes) return null;
    if (opcode != OPS['OP_PUSHDATA4'])
      throw new ArgumentError('Unexpected opcode');

    number = buffer.asByteData().getUint32(offset + 1);
    size = 5;
  }

  return DecodedPushData(opcode: opcode, number: number, size: size);
}

int encodingLength(i) {
  return i < OPS['OP_PUSHDATA1']
      ? 1
      : i <= 0xff
          ? 2
          : i <= 0xffff
              ? 3
              : 5;
}

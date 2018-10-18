import 'check_types.dart';
import 'dart:typed_data';
Uint8List encode(number, [Uint8List buffer,int offset]) {
  if (!isUint(number, 53));

  buffer = buffer ?? new Uint8List(encodingLength(number));
  offset = offset ?? 0;
  ByteData bytes = buffer.buffer.asByteData();
  // 8 bit
  if (number < 0xfd) {
    bytes.setUint8(offset, number);
    // 16 bit
  } else if (number <= 0xffff) {
    bytes.setUint8(offset, 0xfd);
    bytes.setUint16(offset + 1, number, Endian.little);

    // 32 bit
  } else if (number <= 0xffffffff) {
    bytes.setUint8(offset, 0xfe);
    bytes.setUint32(offset + 1, number, Endian.little);

    // 64 bit
  } else {
    bytes.setUint8(offset, 0xff);
    bytes.setUint32(offset + 1, number, Endian.little);
    bytes.setUint32(offset + 5, (number / 0x100000000) | 0, Endian.little);
  }

  return buffer;
}
int decode (Uint8List buffer, [int offset]) {
  offset = offset ?? 0;
  ByteData bytes = buffer.buffer.asByteData();
  final first = bytes.getUint8(offset);

  // 8 bit
  if (first < 0xfd) {
    return first;
    // 16 bit
  } else if (first == 0xfd) {
    return bytes.getUint16(offset + 1, Endian.little);

    // 32 bit
  } else if (first == 0xfe) {
    return bytes.getUint32(offset + 1, Endian.little);
    // 64 bit
  } else {
    var lo = bytes.getUint32(offset + 1, Endian.little);
    var hi = bytes.getUint32(offset + 5, Endian.little);
    var number = hi * 0x0100000000 + lo;
    if (!isUint(number, 53)) throw ArgumentError("Expected UInt53");
    return number;
  }
}

int encodingLength(int number) {
  if (!isUint(number, 53)) throw ArgumentError("Expected UInt53");
  return (
      number < 0xfd ? 1
          : number <= 0xffff ? 3
          : number <= 0xffffffff ? 5
          : 9
  );
}


int readUInt64LE (ByteData bytes, int offset) {
  final a = bytes.getUint32(offset, Endian.little);
  var b = bytes.getUint32(offset + 4, Endian.little);
  b *= 0x100000000;
  isUint(b + a, 64);
  return b + a;
}

int writeUInt64LE (ByteData bytes, int offset, int value) {
  isUint(value, 64);
  bytes.setInt32(offset, value & -1, Endian.little);
  print('meo');
  print(value & 1);
  print(value ~/ 0x100000000);
  bytes.setUint32(offset + 4, value ~/ 0x100000000, Endian.little);
  return offset + 8;
}
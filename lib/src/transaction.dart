import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'payments/p2pkh.dart' show P2PKH, P2PKHData;
import 'crypto.dart' as bcrypto;
import 'utils/check_types.dart';
import 'utils/script.dart' as bscript;
import 'utils/constants/op.dart';
import 'utils/varuint.dart' as varuint;

const DEFAULT_SEQUENCE = 0xffffffff;
const SIGHASH_ALL = 0x01;
const SIGHASH_NONE = 0x02;
const SIGHASH_SINGLE = 0x03;
const SIGHASH_ANYONECANPAY = 0x80;
const ADVANCED_TRANSACTION_MARKER = 0x00;
const ADVANCED_TRANSACTION_FLAG = 0x01;
final EMPTY_SCRIPT = Uint8List.fromList([]);
final ZERO = HEX
    .decode('0000000000000000000000000000000000000000000000000000000000000000');
final ONE = HEX
    .decode('0000000000000000000000000000000000000000000000000000000000000001');
final VALUE_UINT64_MAX = HEX.decode('ffffffffffffffff');
final BLANK_OUTPUT =
    new Output(script: EMPTY_SCRIPT, valueBuffer: VALUE_UINT64_MAX);

class Transaction {
  int version = 1;
  int locktime = 0;
  List<Input> ins = [];
  List<Output> outs = [];
  Transaction();
  int addInput(Uint8List hash, int index, [int sequence, Uint8List scriptSig]) {
    ins.add(new Input(
        hash: hash,
        index: index,
        sequence: sequence ?? DEFAULT_SEQUENCE,
        script: scriptSig ?? EMPTY_SCRIPT));
    return ins.length - 1;
  }

  int addOutput(Uint8List scriptPubKey, int value) {
    outs.add(new Output(script: scriptPubKey, value: value));
    return outs.length - 1;
  }

  setInputScript(int index, Uint8List scriptSig) {
    ins[index].script = scriptSig;
  }

  hashForSignature(int inIndex, Uint8List prevOutScript, int hashType) {
    if (inIndex >= ins.length) return ONE;
    // ignore OP_CODESEPARATOR
    final ourScript =
        bscript.compile(bscript.decompile(prevOutScript).where((x) {
      return x != OPS['OP_CODESEPARATOR'];
    }).toList());
    final txTmp = Transaction.clone(this);
    // SIGHASH_NONE: ignore all outputs? (wildcard payee)
    if ((hashType & 0x1f) == SIGHASH_NONE) {
      txTmp.outs = [];
      // ignore sequence numbers (except at inIndex)
      for (var i = 0; i < txTmp.ins.length; i++) {
        if (i != inIndex) {
          txTmp.ins[i].sequence = 0;
        }
      }

      // SIGHASH_SINGLE: ignore all outputs, except at the same index?
    } else if ((hashType & 0x1f) == SIGHASH_SINGLE) {
      // https://github.com/bitcoin/bitcoin/blob/master/src/test/sighash_tests.cpp#L60
      if (inIndex >= outs.length) return ONE;

      // truncate outputs after
      txTmp.outs.length = inIndex + 1;

      // "blank" outputs before
      for (var i = 0; i < inIndex; i++) {
        txTmp.outs[i] = BLANK_OUTPUT;
      }
      // ignore sequence numbers (except at inIndex)
      for (var i = 0; i < txTmp.ins.length; i++) {
        if (i != inIndex) {
          txTmp.ins[i].sequence = 0;
        }
      }
    }

    // SIGHASH_ANYONECANPAY: ignore inputs entirely?
    if (hashType & SIGHASH_ANYONECANPAY != 0) {
      txTmp.ins = [txTmp.ins[inIndex]];
      txTmp.ins[0].script = ourScript;
      // SIGHASH_ALL: only ignore input scripts
    } else {
      // "blank" others input scripts
      txTmp.ins.forEach((input) {
        input.script = EMPTY_SCRIPT;
      });
      txTmp.ins[inIndex].script = ourScript;
    }
    // serialize and hash
    final buffer = Uint8List(txTmp.virtualSize() + 4);
    buffer.buffer
        .asByteData()
        .setUint32(buffer.length - 4, hashType, Endian.little);
    txTmp._toBuffer(buffer, 0);
    return bcrypto.hash256(buffer);
  }

  int virtualSize() {
    return 8 +
        varuint.encodingLength(ins.length) +
        varuint.encodingLength(outs.length) +
        ins.fold(0, (sum, input) => sum + 40 + varSliceSize(input.script)) +
        outs.fold(0, (sum, output) => sum + 8 + varSliceSize(output.script));
  }

  Uint8List toBuffer([Uint8List buffer, int initialOffset]) {
    return this._toBuffer(buffer, initialOffset);
  }

  String toHex() {
    return HEX.encode(this.toBuffer());
  }

  bool isCoinbaseHash(buffer) {
    isHash256bit(buffer);
    for (var i = 0; i < 32; ++i) {
      if (buffer[i] != 0) return false;
    }
    return true;
  }

  bool isCoinbase() {
    return ins.length == 1 && isCoinbaseHash(ins[0].hash);
  }

  Uint8List getHash() {
    return bcrypto.hash256(_toBuffer());
  }

  String getId() {
    return HEX.encode(getHash().reversed.toList());
  }

  _toBuffer([Uint8List buffer, initialOffset]) {
    if (buffer == null) buffer = new Uint8List(virtualSize());
    var bytes = buffer.buffer.asByteData();
    var offset = initialOffset ?? 0;
    writeSlice(slice) {
      buffer.setRange(offset, offset + slice.length, slice);
      offset += slice.length;
    }

    writeUInt32(i) {
      bytes.setUint32(offset, i, Endian.little);
      offset += 4;
    }

    writeInt32(i) {
      bytes.setInt32(offset, i, Endian.little);
      offset += 4;
    }

    writeUInt64(i) {
      bytes.setUint64(offset, i, Endian.little);
      offset += 8;
    }

    writeVarInt(i) {
      varuint.encode(i, buffer, offset);
      offset += varuint.encodingLength(i);
    }

    writeVarSlice(slice) {
      writeVarInt(slice.length);
      writeSlice(slice);
    }

    writeInt32(version);
    writeVarInt(this.ins.length);
    ins.forEach((txIn) {
      writeSlice(txIn.hash);
      writeUInt32(txIn.index);
      writeVarSlice(txIn.script);
      writeUInt32(txIn.sequence);
    });
    varuint.encode(outs.length, buffer, offset);
    offset += varuint.encodingLength(outs.length);
    outs.forEach((txOut) {
      if (txOut.valueBuffer == null) {
        writeUInt64(txOut.value);
      } else {
        writeSlice(txOut.valueBuffer);
      }
      writeVarSlice(txOut.script);
    });
    writeUInt32(this.locktime);
    // avoid slicing unless necessary
    if (initialOffset != null) return buffer.sublist(initialOffset, offset);
    return buffer;
  }

  factory Transaction.clone(Transaction _tx) {
    Transaction tx = new Transaction();
    tx.version = _tx.version;
    tx.locktime = _tx.locktime;
    tx.ins = _tx.ins.map((input) {
      return Input.clone(input);
    }).toList();
    tx.outs = _tx.outs.map((output) {
      return Output.clone(output);
    }).toList();
    return tx;
  }
  factory Transaction.fromBuffer(Uint8List buffer) {
    var offset = 0;
    ByteData bytes = buffer.buffer.asByteData();
    Uint8List readSlice(n) {
      offset += n;
      return buffer.sublist(offset - n, offset);
    }

    int readUInt32() {
      final i = bytes.getUint32(offset, Endian.little);
      offset += 4;
      return i;
    }

    int readInt32() {
      final i = bytes.getInt32(offset, Endian.little);
      offset += 4;
      return i;
    }

    int readUInt64() {
      final i = bytes.getUint64(offset, Endian.little);
      offset += 8;
      return i;
    }

    int readVarInt() {
      final vi = varuint.decode(buffer, offset);
      offset += varuint.encodingLength(vi);
      return vi;
    }

    Uint8List readVarSlice() {
      return readSlice(readVarInt());
    }

    final tx = new Transaction();
    tx.version = readInt32();

    final vinLen = readVarInt();
    for (var i = 0; i < vinLen; ++i) {
      tx.ins.add(new Input(
          hash: readSlice(32),
          index: readUInt32(),
          script: readVarSlice(),
          sequence: readUInt32()));
    }
    final voutLen = readVarInt();
    for (var i = 0; i < voutLen; ++i) {
      tx.outs.add(new Output(value: readUInt64(), script: readVarSlice()));
    }
    tx.locktime = readUInt32();
    if (offset != buffer.length)
      throw new ArgumentError('Transaction has unexpected data');
    return tx;
  }
  factory Transaction.fromHex(String hex) {
    return Transaction.fromBuffer(HEX.decode(hex));
  }
}

class Input {
  Uint8List hash;
  int index;
  int sequence;
  int value;
  Uint8List script;
  Uint8List signScript;
  Uint8List prevOutScript;
  List<Uint8List> pubkeys;
  List<Uint8List> signatures;
  Input(
      {this.hash,
      this.index,
      this.script,
      this.sequence,
      this.value,
      this.prevOutScript,
      this.pubkeys,
      this.signatures}) {
    if (this.hash != null && !isHash256bit(this.hash))
      throw new ArgumentError("Invalid input hash");
    if (this.index != null && !isUint(this.index, 32))
      throw new ArgumentError("Invalid input index");
    if (this.sequence != null && !isUint(this.sequence, 32))
      throw new ArgumentError("Invalid input sequence");
    if (this.value != null && !isShatoshi(this.value))
      throw ArgumentError("Invalid ouput value");
  }
  factory Input.expandInput(Uint8List scriptSig) {
    if (_isP2PKHInput(scriptSig) == false) {
      throw ArgumentError("Invalid or non-support script");
    }
    P2PKH p2pkh = new P2PKH(data: new P2PKHData(input: scriptSig));
    return new Input(
        prevOutScript: p2pkh.data.output,
        pubkeys: [p2pkh.data.pubkey],
        signatures: [p2pkh.data.signature]);
  }
  factory Input.clone(Input input) {
    return new Input(
      hash: input.hash != null ? Uint8List.fromList(input.hash) : null,
      index: input.index,
      script: input.script != null ? Uint8List.fromList(input.script) : null,
      sequence: input.sequence,
      value: input.value,
      prevOutScript: input.prevOutScript != null
          ? Uint8List.fromList(input.prevOutScript)
          : null,
      pubkeys: input.pubkeys != null
          ? input.pubkeys.map(
              (pubkey) => pubkey != null ? Uint8List.fromList(pubkey) : null)
          : null,
      signatures: input.signatures != null
          ? input.signatures.map((signature) =>
              signature != null ? Uint8List.fromList(signature) : null)
          : null,
    );
  }
  @override
  String toString() {
    return 'Input{hash: $hash, index: $index, sequence: $sequence, value: $value, script: $script, signScript: $signScript, prevOutScript: $prevOutScript, pubkeys: $pubkeys, signatures: $signatures}';
  }
}

class Output {
  Uint8List script;
  int value;
  Uint8List valueBuffer;
  List<Uint8List> pubkeys;
  List<Uint8List> signatures;
  Output(
      {this.script,
      this.value,
      this.pubkeys,
      this.signatures,
      this.valueBuffer}) {
    if (value != null && !isShatoshi(value))
      throw ArgumentError("Invalid ouput value");
  }
  factory Output.expandOutput(Uint8List script, Uint8List ourPubKey) {
    if (_isP2PKHOutput(script) == false) {
      throw ArgumentError("Unsupport script!");
    }
    // does our hash160(pubKey) match the output scripts?
    Uint8List pkh1 = new P2PKH(data: new P2PKHData(output: script)).data.hash;
    Uint8List pkh2 = bcrypto.hash160(ourPubKey);
    if (pkh1 != pkh2) throw ArgumentError("Hash mismatch!");
    return new Output(pubkeys: [ourPubKey], signatures: [null]);
  }
  factory Output.clone(Output output) {
    return new Output(
      script: output.script != null ? Uint8List.fromList(output.script) : null,
      value: output.value,
      valueBuffer: output.valueBuffer != null
          ? Uint8List.fromList(output.valueBuffer)
          : null,
      pubkeys: output.pubkeys != null
          ? output.pubkeys.map(
              (pubkey) => pubkey != null ? Uint8List.fromList(pubkey) : null)
          : null,
      signatures: output.signatures != null
          ? output.signatures.map((signature) =>
              signature != null ? Uint8List.fromList(signature) : null)
          : null,
    );
  }

  @override
  String toString() {
    return 'Output{script: $script, value: $value, valueBuffer: $valueBuffer, pubkeys: $pubkeys, signatures: $signatures}';
  }
}

bool isCoinbaseHash(Uint8List buffer) {
  if (!isHash256bit(buffer)) throw new ArgumentError("Invalid hash");
  for (var i = 0; i < 32; ++i) {
    if (buffer[i] != 0) return false;
  }
  return true;
}

bool _isP2PKHInput(script) {
  final chunks = bscript.decompile(script);
  return chunks != null &&
      chunks.length == 2 &&
      bscript.isCanonicalScriptSignature(chunks[0]) &&
      bscript.isCanonicalPubKey(chunks[1]);
}

bool _isP2PKHOutput(script) {
  final buffer = bscript.compile(script);
  return buffer.length == 25 &&
      buffer[0] == OPS['OP_DUP'] &&
      buffer[1] == OPS['OP_HASH160'] &&
      buffer[2] == 0x14 &&
      buffer[23] == OPS['OP_EQUALVERIFY'] &&
      buffer[24] == OPS['OP_CHECKSIG'];
}

int varSliceSize(Uint8List someScript) {
  final length = someScript.length;
  return varuint.encodingLength(length) + length;
}

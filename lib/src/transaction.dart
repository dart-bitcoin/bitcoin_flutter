import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'payments/index.dart' show PaymentData;
import 'payments/p2pkh.dart' show P2PKH;
import 'payments/p2wpkh.dart' show P2WPKH;
import 'crypto.dart' as bcrypto;
import 'classify.dart';
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
final EMPTY_WITNESS = new List<Uint8List>();
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
        script: scriptSig ?? EMPTY_SCRIPT,
        witness: EMPTY_WITNESS));
    return ins.length - 1;
  }

  int addOutput(Uint8List scriptPubKey, int value) {
    outs.add(new Output(script: scriptPubKey, value: value));
    return outs.length - 1;
  }

  bool hasWitnesses() {
    var witness = ins.firstWhere(
        (input) => input.witness != null && input.witness.length != 0,
                   orElse: () => null);
    return witness != null;
  }

  setInputScript(int index, Uint8List scriptSig) {
    ins[index].script = scriptSig;
  }

  setWitness(int index, List<Uint8List> witness) {
    ins[index].witness = witness;
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

  _byteLength(_ALLOW_WITNESS) {
    var hasWitness = _ALLOW_WITNESS && hasWitnesses();
    return (hasWitness ? 10 : 8)  +
        varuint.encodingLength(ins.length) +
        varuint.encodingLength(outs.length) +
        ins.fold(0, (sum, input) => sum + 40 + varSliceSize(input.script)) +
        outs.fold(0, (sum, output) => sum + 8 + varSliceSize(output.script)) +
        (hasWitness ? ins.fold(0, (sum, input) => sum + vectorSize(input.witness)) : 0);
  }

  int vectorSize(List<Uint8List> someVector) {
    var length = someVector.length;
    return varuint.encodingLength(length) + someVector.fold(0, (sum, witness) => sum + varSliceSize(witness));
  }

  int weight() {
    var base = _byteLength(false);
    var total = _byteLength(true);
    return base * 3 + total;
  }

  int byteLength() {
    return _byteLength(true);
  }

  int virtualSize() {
    return (weight() / 4).ceil();
  }

  Uint8List toBuffer([Uint8List buffer, int initialOffset]) {
    return this._toBuffer(buffer, initialOffset, true);
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
    // if (isCoinbase()) return Uint8List.fromList(List.generate(32, (i) => 0));
    return bcrypto.hash256(_toBuffer(null, null, false));
  }

  String getId() {
    return HEX.encode(getHash().reversed.toList());
  }

  _toBuffer([Uint8List buffer, initialOffset, bool _ALLOW_WITNESS=false]) {
    // _ALLOW_WITNESS is used to separate witness part when calculating tx id
    if (buffer == null) buffer = new Uint8List(_byteLength(_ALLOW_WITNESS));

    var bytes = buffer.buffer.asByteData();
    var offset = initialOffset ?? 0;

    writeSlice(slice) {
      buffer.setRange(offset, offset + slice.length, slice);
      offset += slice.length;
    }

    writeUInt8(i) {
      bytes.setUint8(offset, i);
      offset++;
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

    writeVector(vector) {
      writeVarInt(vector.length);
      vector.forEach((buf) { writeVarSlice(buf); });
    }

    // Start writeBuffer
    writeInt32(version);

    if (_ALLOW_WITNESS && hasWitnesses()) {
      writeUInt8(ADVANCED_TRANSACTION_MARKER);
      writeUInt8(ADVANCED_TRANSACTION_FLAG);
    }

    writeVarInt(this.ins.length);

    ins.forEach((txIn) {
      writeSlice(txIn.hash);
      writeUInt32(txIn.index);
      writeVarSlice(txIn.script);
      writeUInt32(txIn.sequence);
    });

    writeVarInt(this.outs.length);

    outs.forEach((txOut) {
      if (txOut.valueBuffer == null) {
        writeUInt64(txOut.value);
      } else {
        writeSlice(txOut.valueBuffer);
      }
      writeVarSlice(txOut.script);
    });

    if (_ALLOW_WITNESS && hasWitnesses()) {
      ins.forEach((txInt) { writeVector(txInt.witness); });
    }

    writeUInt32(this.locktime);
    // End writeBuffer

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

    int readUInt8() {
      final i = bytes.getUint8(offset);
      offset++;
      return i;
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

    Uint8List readSlice(n) {
      offset += n;
      return buffer.sublist(offset - n, offset);
    }

    int readVarInt() {
      final vi = varuint.decode(buffer, offset);
      offset += varuint.encodingLength(vi);
      return vi;
    }

    Uint8List readVarSlice() {
      return readSlice(readVarInt());
    }

    List<Uint8List> readVector() {
      var count = readVarInt();
      List<Uint8List> vector = [];
      for (var i = 0; i < count; ++i) {
        vector.add(readVarSlice());
      }
      return vector;
    }

    final tx = new Transaction();
    tx.version = readInt32();

    final marker = readUInt8();
    final flag = readUInt8();

    var hasWitnesses = false;
    if (marker == ADVANCED_TRANSACTION_MARKER && flag == ADVANCED_TRANSACTION_FLAG) {
      hasWitnesses = true;
    } else {
      offset -= 2; // Reset offset if not segwit tx
    }

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

    if (hasWitnesses) {
      for (var i = 0; i < vinLen; ++i) {
        tx.ins[i].witness = readVector();
      }
    }

    tx.locktime = readUInt32();

    if (offset != buffer.length)
      throw new ArgumentError('Transaction has unexpected data');

    return tx;
  }

  factory Transaction.fromHex(String hex) {
    return Transaction.fromBuffer(HEX.decode(hex));
  }

  @override
  String toString() {
    this.ins.forEach((txInput) { print(txInput.toString()); });
    this.outs.forEach((txOutput) { print(txOutput.toString()); });
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
  String prevOutType;
  List<Uint8List> pubkeys;
  List<Uint8List> signatures;
  List<Uint8List> witness;

  Input(
      {this.hash,
      this.index,
      this.script,
      this.sequence,
      this.value,
      this.prevOutScript,
      this.pubkeys,
      this.signatures,
      this.witness,
      this.prevOutType}) {
    if (this.hash != null && !isHash256bit(this.hash))
      throw new ArgumentError("Invalid input hash");
    if (this.index != null && !isUint(this.index, 32))
      throw new ArgumentError("Invalid input index");
    if (this.sequence != null && !isUint(this.sequence, 32))
      throw new ArgumentError("Invalid input sequence");
    if (this.value != null && !isShatoshi(this.value))
      throw ArgumentError("Invalid ouput value");
  }

  factory Input.expandInput(
      Uint8List scriptSig,
      List<Uint8List> witness,
      [String type,
      Uint8List scriptPubKey]
  ) {
    if (type == null || type == '') {
      var ssType = classifyInput(scriptSig);
      var wsType = classifyWitness(witness);
      if (ssType == SCRIPT_TYPES['NONSTANDARD']) ssType = null;
      if (wsType == SCRIPT_TYPES['NONSTANDARD']) wsType = null;
      type = ssType ?? wsType;
    }
    if (type == SCRIPT_TYPES['P2WPKH']) {
      P2WPKH p2wpkh = new P2WPKH(data: new PaymentData(witness: witness));
      return new Input(
          prevOutScript: p2wpkh.data.output,
          prevOutType: SCRIPT_TYPES['P2WPKH'],
          pubkeys: [p2wpkh.data.pubkey],
          signatures: [p2wpkh.data.signature]
      );
    } else if (type == SCRIPT_TYPES['P2PKH']) {
      P2PKH p2pkh = new P2PKH(data: new PaymentData(input: scriptSig));
      return new Input(
          prevOutScript: p2pkh.data.output,
          prevOutType: SCRIPT_TYPES['P2PKH'],
          pubkeys: [p2pkh.data.pubkey],
          signatures: [p2pkh.data.signature]
      );
    }
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
    return 'Input{hash: $hash, index: $index, sequence: $sequence, value: $value, script: $script, signScript: $signScript, prevOutScript: $prevOutScript, pubkeys: $pubkeys, signatures: $signatures, witness: $witness, prevOutType: $prevOutType}';
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

  factory Output.expandOutput(Uint8List script, [Uint8List ourPubKey]) {
    if (ourPubKey == null) return new Output();
    var type = classifyOutput(script);
    if (type == SCRIPT_TYPES['P2WPKH']) {
      Uint8List wpkh1 = new P2WPKH(data: new PaymentData(output: script)).data.hash;
      Uint8List wpkh2 = bcrypto.hash160(ourPubKey);
      if (wpkh1 != wpkh2) throw ArgumentError("Hash mismatch!");
      return new Output(pubkeys: [ourPubKey], signatures: [null]);
    } else if (type == SCRIPT_TYPES['P2PKH']) {
      Uint8List pkh1 = new P2PKH(data: new PaymentData(output: script)).data.hash;
      Uint8List pkh2 = bcrypto.hash160(ourPubKey);
      if (pkh1 != pkh2) throw ArgumentError("Hash mismatch!");
      return new Output(pubkeys: [ourPubKey], signatures: [null]);
    }
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

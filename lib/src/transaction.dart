import 'dart:typed_data';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:hex/hex.dart';
import 'payments/index.dart' show PaymentData;
import 'payments/p2pkh.dart' show P2PKH;
import 'payments/p2pk.dart' show P2PK;
import 'payments/p2wpkh.dart' show P2WPKH;
import 'payments/p2sh.dart' show P2SH;
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
final EMPTY_WITNESS = <Uint8List>[];
final ZERO = HEX.decode('0000000000000000000000000000000000000000000000000000000000000000');
final ONE = HEX.decode('0000000000000000000000000000000000000000000000000000000000000001');
final VALUE_UINT64_MAX = HEX.decode('ffffffffffffffff');
final BLANK_OUTPUT = Output(script: EMPTY_SCRIPT, valueBuffer: Uint8List.fromList(VALUE_UINT64_MAX));

const int SERIALIZE_TRANSACTION_NO_WITNESS = 0x40000000;
const int SERIALIZE_TRANSACTION_NO_TOKENS = 0x20000000;
const MIN_VERSION_NO_TOKENS = 3;

class Transaction {
  int? version = 1;
  int? locktime = 0;
  List<Input> ins = [];
  List<OutputBase> outs = [];
  Transaction();

  int addInput(Uint8List hash, int? index, [int? sequence, Uint8List? scriptSig]) {
    ins.add(Input(hash: hash, index: index, sequence: sequence ?? DEFAULT_SEQUENCE, script: scriptSig ?? EMPTY_SCRIPT, witness: EMPTY_WITNESS));
    return ins.length - 1;
  }

  int addOutput(Uint8List? scriptPubKey, int? value) {
    outs.add(Output(script: scriptPubKey, value: value));
    return outs.length - 1;
  }

  int addOutputAt(Uint8List? scriptPubKey, int value, int at) {
    final output = Output(script: scriptPubKey, value: value);
    return addBaseOutputAt(output, at);
  }

  int addBaseOutput(OutputBase output) {
    outs.add(output);
    return outs.length - 1;
  }

  int addBaseOutputAt(OutputBase output, int index) {
    outs.insert(index, output);
    return index;
  }

  bool hasWitnesses() {
    var witness = ins.firstWhereOrNull((input) => input.witness != null && input.witness!.isNotEmpty);
    return witness != null;
  }

  void setInputScript(int index, Uint8List? scriptSig) {
    ins[index].script = scriptSig;
  }

  void setWitness(int index, List<Uint8List?>? witness) {
    ins[index].witness = witness;
  }

  Uint8List hashForWitnessV0(int inIndex, Uint8List prevOutScript, int value, int hashType) {
    var tbuffer = Uint8List.fromList([]);
    var toffset = 0;
    // Any changes made to the ByteData will also change the buffer, and vice versa.
    // https://api.dart.dev/stable/2.7.1/dart-typed_data/ByteBuffer/asByteData.html
    var bytes = tbuffer.buffer.asByteData();
    var hashOutputs = ZERO;
    var hashPrevouts = ZERO;
    var hashSequence = ZERO;

    void writeSlice(List<int>? slice) {
      tbuffer.setRange(toffset, toffset + slice!.length, slice);
      toffset += slice.length;
    }

    // ignore: unused_element
    void writeUInt8(i) {
      bytes.setUint8(toffset, i);
      toffset++;
    }

    void writeUInt32(i) {
      bytes.setUint32(toffset, i, Endian.little);
      toffset += 4;
    }

    // ignore: unused_element
    void writeInt32(i) {
      bytes.setInt32(toffset, i, Endian.little);
      toffset += 4;
    }

    void writeUInt64(i) {
      bytes.setUint64(toffset, i, Endian.little);
      toffset += 8;
    }

    void writeVarInt(i) {
      varuint.encode(i, tbuffer, toffset);
      toffset += varuint.encodingLength(i);
    }

    void writeVarSlice(slice) {
      writeVarInt(slice.length);
      writeSlice(slice);
    }

    // ignore: unused_element
    void writeVector(vector) {
      writeVarInt(vector.length);
      vector.forEach((buf) {
        writeVarSlice(buf);
      });
    }

    if ((hashType & SIGHASH_ANYONECANPAY) == 0) {
      tbuffer = Uint8List(36 * ins.length);
      bytes = tbuffer.buffer.asByteData();
      toffset = 0;

      ins.forEach((txIn) {
        writeSlice(txIn.hash);
        writeUInt32(txIn.index);
      });
      hashPrevouts = bcrypto.hash256(tbuffer);
    }

    if ((hashType & SIGHASH_ANYONECANPAY) == 0 && (hashType & 0x1f) != SIGHASH_SINGLE && (hashType & 0x1f) != SIGHASH_NONE) {
      tbuffer = Uint8List(4 * ins.length);
      bytes = tbuffer.buffer.asByteData();
      toffset = 0;
      ins.forEach((txIn) {
        writeUInt32(txIn.sequence);
      });
      hashSequence = bcrypto.hash256(tbuffer);
    }

    if ((hashType & 0x1f) != SIGHASH_SINGLE && (hashType & 0x1f) != SIGHASH_NONE) {
      var txOutsSize = outs.fold(0, (dynamic sum, output) => sum + (this.version! > MIN_VERSION_NO_TOKENS ? 1 : 0) + 8 + varSliceSize(output.script!));
      tbuffer = Uint8List(txOutsSize);
      bytes = tbuffer.buffer.asByteData();
      toffset = 0;
      outs.forEach((txOut) {
        writeUInt64(txOut.value);
        writeVarSlice(txOut.script);
        if (version! > MIN_VERSION_NO_TOKENS) {
          writeVarInt(txOut.tokenId);
        }
      });
      hashOutputs = bcrypto.hash256(tbuffer);
    } else if ((hashType & 0x1f) == SIGHASH_SINGLE && inIndex < outs.length) {
      // SIGHASH_SINGLE only hash that according output
      var output = outs[inIndex];
      tbuffer = Uint8List(8 + (this.version! > MIN_VERSION_NO_TOKENS ? 1 : 0) + varSliceSize(output.script!));
      bytes = tbuffer.buffer.asByteData();
      toffset = 0;
      writeUInt64(output.value);
      writeVarSlice(output.script);
      if (version! > MIN_VERSION_NO_TOKENS) {
        writeVarInt(output.tokenId);
      }
      hashOutputs = bcrypto.hash256(tbuffer);
    }

    tbuffer = Uint8List(156 + varSliceSize(prevOutScript));
    bytes = tbuffer.buffer.asByteData();
    toffset = 0;
    var input = ins[inIndex];
    writeUInt32(version);
    writeSlice(hashPrevouts);
    writeSlice(hashSequence);
    writeSlice(input.hash);
    writeUInt32(input.index);
    writeVarSlice(prevOutScript);
    writeUInt64(value);
    writeUInt32(input.sequence);
    writeSlice(hashOutputs);
    writeUInt32(locktime);
    writeUInt32(hashType);

    return bcrypto.hash256(tbuffer);
  }

  List<int> hashForSignature(int inIndex, Uint8List? prevOutScript, int? hashType) {
    if (inIndex >= ins.length) return ONE;
    // ignore OP_CODESEPARATOR
    final ourScript = bscript.compile(bscript.decompile(prevOutScript)!.where((x) {
      return x != OPS['OP_CODESEPARATOR'];
    }).toList());
    final txTmp = Transaction.clone(this);
    // SIGHASH_NONE: ignore all outputs? (wildcard payee)
    if ((hashType! & 0x1f) == SIGHASH_NONE) {
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

      // 'blank' outputs before
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
      // 'blank' others input scripts
      txTmp.ins.forEach((input) {
        input.script = EMPTY_SCRIPT;
      });
      txTmp.ins[inIndex].script = ourScript;
    }
    // serialize and hash
    final buffer = Uint8List(txTmp.virtualSize() + 4);
    buffer.buffer.asByteData().setUint32(buffer.length - 4, hashType, Endian.little);
    txTmp._toBuffer(buffer, 0);
    return bcrypto.hash256(buffer);
  }

  num _byteLength(_ALLOW_WITNESS) {
    var hasWitness = _ALLOW_WITNESS && hasWitnesses();
    return (hasWitness ? 10 : 8) +
        varuint.encodingLength(ins.length) +
        varuint.encodingLength(outs.length) +
        ins.fold(0, (sum, input) => sum + 40 + varSliceSize(input.script!)) +
        outs.fold(0, (sum, output) => sum + (this.version! > MIN_VERSION_NO_TOKENS ? 1 : 0) + 8 + varSliceSize(output.script!)) +
        (hasWitness ? ins.fold(0, (sum, input) => sum + vectorSizeNew(input)) : 0);
  }

  int vectorSizeNew(Input input) {
    if (input.witness != null && input.witness!.isNotEmpty) {
      return vectorSize(input.witness!);
    }

    return varuint.encodingLength(0);
  }

  int vectorSize(List<Uint8List?> someVector) {
    var length = someVector.length;
    return varuint.encodingLength(length) + someVector.fold(0, ((sum, witness) => sum + varSliceSize(witness!) as int) as int Function(int, Uint8List?));
  }

  int weight() {
    var base = _byteLength(false);
    var total = _byteLength(true);
    return base * 3 + total as int;
  }

  int byteLength() {
    return _byteLength(true) as int;
  }

  int virtualSize() {
    return (weight() / 4).ceil();
  }

  Uint8List toBuffer([Uint8List? buffer, int? initialOffset]) {
    return _toBuffer(buffer, initialOffset, true);
  }

  String toHex() {
    return HEX.encode(toBuffer());
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

  Uint8List _toBuffer([Uint8List? buffer, initialOffset, bool _ALLOW_WITNESS = false]) {
    // _ALLOW_WITNESS is used to separate witness part when calculating tx id
    buffer ??= Uint8List(_byteLength(_ALLOW_WITNESS) as int);

    // Any changes made to the ByteData will also change the buffer, and vice versa.
    // https://api.dart.dev/stable/2.7.1/dart-typed_data/ByteBuffer/asByteData.html
    var bytes = buffer.buffer.asByteData();
    var offset = initialOffset ?? 0;

    void writeSlice(slice) {
      buffer!.setRange(offset, offset + slice.length, slice);
      offset += slice.length;
    }

    void writeUInt8(i) {
      bytes.setUint8(offset, i);
      offset++;
    }

    void writeUInt32(i) {
      bytes.setUint32(offset, i, Endian.little);
      offset += 4;
    }

    void writeInt32(i) {
      bytes.setInt32(offset, i, Endian.little);
      offset += 4;
    }

    void writeUInt64(i) {
      bytes.setUint64(offset, i, Endian.little);
      offset += 8;
    }

    void writeVarInt(i) {
      varuint.encode(i, buffer, offset);
      offset += varuint.encodingLength(i);
    }

    void writeVarSlice(slice) {
      writeVarInt(slice.length);
      writeSlice(slice);
    }

    void writeVector(vector) {
      writeVarInt(vector.length);
      vector.forEach((buf) {
        writeVarSlice(buf);
      });
    }

    // Start writeBuffer
    writeInt32(version);

    if (_ALLOW_WITNESS && hasWitnesses()) {
      writeUInt8(ADVANCED_TRANSACTION_MARKER);
      writeUInt8(ADVANCED_TRANSACTION_FLAG);
    }

    writeVarInt(ins.length);

    ins.forEach((txIn) {
      writeSlice(txIn.hash);
      writeUInt32(txIn.index);
      writeVarSlice(txIn.script);
      writeUInt32(txIn.sequence);
    });

    writeVarInt(outs.length);

    outs.forEach((txOut) {
      if (txOut.valueBuffer == null) {
        writeUInt64(txOut.value);
      } else {
        writeSlice(txOut.valueBuffer);
      }
      writeVarSlice(txOut.script);
      if (this.version! > MIN_VERSION_NO_TOKENS) {
        writeVarInt(txOut.tokenId);
      }
    });

    if (_ALLOW_WITNESS && hasWitnesses()) {
      ins.forEach((txInt) {
        if (txInt.witness == null) {
          writeVarInt(0);
        } else {
          writeVector(txInt.witness);
        }
      });
    }

    writeUInt32(locktime);
    // End writeBuffer

    // avoid slicing unless necessary
    if (initialOffset != null) return buffer.sublist(initialOffset, offset);

    return buffer;
  }

  factory Transaction.clone(Transaction _tx) {
    var tx = Transaction();
    tx.version = _tx.version;
    tx.locktime = _tx.locktime;
    tx.ins = _tx.ins.map((input) {
      return Input.clone(input);
    }).toList();
    tx.outs = _tx.outs.map((output) {
      return OutputBase.clone(output);
    }).toList();
    return tx;
  }

  factory Transaction.fromBuffer(
    Uint8List buffer, {
    bool noStrict = false,
  }) {
    var offset = 0;
    // Any changes made to the ByteData will also change the buffer, and vice versa.
    // https://api.dart.dev/stable/2.7.1/dart-typed_data/ByteBuffer/asByteData.html
    var bytes = buffer.buffer.asByteData();

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

    Uint8List readSlice(int n) {
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
      var vector = <Uint8List>[];
      for (var i = 0; i < count; ++i) {
        vector.add(readVarSlice());
      }
      return vector;
    }

    final tx = Transaction();
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
      tx.ins.add(Input(hash: readSlice(32), index: readUInt32(), script: readVarSlice(), sequence: readUInt32()));
    }

    final voutLen = readVarInt();
    for (var i = 0; i < voutLen; ++i) {
      tx.outs.add(Output(value: readUInt64(), script: readVarSlice()));
    }

    if (hasWitnesses) {
      for (var i = 0; i < vinLen; ++i) {
        tx.ins[i].witness = readVector();
      }
    }

    tx.locktime = readUInt32();

    if (noStrict) return tx;

    if (offset != buffer.length) {
      throw ArgumentError('Transaction has unexpected data');
    }

    return tx;
  }

  factory Transaction.fromHex(
    String hex, {
    bool noStrict = false,
  }) {
    return Transaction.fromBuffer(
      Uint8List.fromList(HEX.decode(hex)),
      noStrict: noStrict,
    );
  }

  @override
  String toString() {
    final s = [];
    ins.forEach((txInput) {
      s.add(txInput.toString());
      print(txInput.toString());
    });
    outs.forEach((txOutput) {
      s.add(txOutput.toString());
      print(txOutput.toString());
    });
    return s.join('\n');
  }
}

class Input {
  Uint8List? hash;
  int? index;
  int? sequence;
  int? value;
  Uint8List? script;
  Uint8List? signScript;
  Uint8List? prevOutScript;
  Uint8List? redeemScript;
  Uint8List? witnessScript;
  String? signType;
  String? prevOutType;
  String? redeemScriptType;
  String? witnessScriptType;
  bool? hasWitness;
  List<Uint8List?>? pubkeys;
  List<Uint8List?>? signatures;
  List<Uint8List?>? witness;
  int? maxSignatures;

  Input(
      {this.hash,
      this.index,
      this.script,
      this.sequence,
      this.value,
      this.prevOutScript,
      this.redeemScript,
      this.witnessScript,
      this.pubkeys,
      this.signatures,
      this.witness,
      this.signType,
      this.prevOutType,
      this.redeemScriptType,
      this.witnessScriptType,
      this.maxSignatures}) {
    hasWitness = false; // Default value
    if (hash != null && !isHash256bit(hash!)) {
      throw ArgumentError('Invalid input hash');
    }
    if (index != null && !isUint(index!, 32)) {
      throw ArgumentError('Invalid input index');
    }
    if (sequence != null && !isUint(sequence!, 32)) {
      throw ArgumentError('Invalid input sequence');
    }
    if (value != null && !isShatoshi(value!)) {
      throw ArgumentError('Invalid ouput value');
    }
  }

  factory Input.expandInput(Uint8List scriptSig, List<Uint8List?>? witness, [String? type, Uint8List? scriptPubKey]) {
    if (scriptSig.isEmpty && witness!.isEmpty) {
      return Input();
    }
    if (type == null || type == '') {
      var ssType = classifyInput(scriptSig, true);
      var wsType = classifyWitness(witness);
      if (ssType == SCRIPT_TYPES['NONSTANDARD']) ssType = null;
      if (wsType == SCRIPT_TYPES['NONSTANDARD']) wsType = null;
      type = ssType ?? wsType;
    }
    if (type == SCRIPT_TYPES['P2WPKH']) {
      var p2wpkh = P2WPKH(data: PaymentData(witness: witness));
      return Input(prevOutScript: p2wpkh.data!.output, prevOutType: SCRIPT_TYPES['P2WPKH'], pubkeys: [p2wpkh.data!.pubkey], signatures: [p2wpkh.data!.signature]);
    }
    if (type == SCRIPT_TYPES['P2PKH']) {
      var p2pkh = P2PKH(data: PaymentData(input: scriptSig));
      return Input(prevOutScript: p2pkh.data!.output, prevOutType: SCRIPT_TYPES['P2PKH'], pubkeys: [p2pkh.data!.pubkey], signatures: [p2pkh.data!.signature]);
    }
    if (type == SCRIPT_TYPES['P2PK']) {
      var p2pk = P2PK(data: PaymentData(input: scriptSig));
      return Input(prevOutType: SCRIPT_TYPES['P2PK'], pubkeys: [], signatures: [p2pk.data.signature]);
    }
    if (type == SCRIPT_TYPES['P2MS']) {
      // TODO
    }
    if (type == SCRIPT_TYPES['P2SH']) {
      var p2sh = P2SH(data: PaymentData(input: scriptSig, witness: witness));
      final output = p2sh.data!.output;
      final redeem = p2sh.data!.redeem!;
      final outputType = classifyOutput(redeem.output!);
      final expanded = Input.expandInput(
        redeem.input!,
        redeem.witness,
        outputType,
        redeem.output,
      );
      if (expanded.prevOutType == null) return Input();
      return Input(
          prevOutScript: output,
          prevOutType: SCRIPT_TYPES['P2SH'],
          redeemScript: redeem.output,
          redeemScriptType: expanded.prevOutType,
          witnessScript: expanded.witnessScript,
          witnessScriptType: expanded.witnessScriptType,
          pubkeys: expanded.pubkeys,
          signatures: expanded.signatures);
    }
    return Input(
      prevOutType: SCRIPT_TYPES['NONSTANDARD'],
      prevOutScript: scriptSig,
    );
  }

  factory Input.clone(Input input) {
    return Input(
      hash: input.hash != null ? Uint8List.fromList(input.hash!) : null,
      index: input.index,
      script: input.script != null ? Uint8List.fromList(input.script!) : null,
      sequence: input.sequence,
      value: input.value,
      prevOutScript: input.prevOutScript != null ? Uint8List.fromList(input.prevOutScript!) : null,
      pubkeys: input.pubkeys != null ? input.pubkeys!.map((pubkey) => pubkey != null ? Uint8List.fromList(pubkey) : null) as List<Uint8List?>? : null,
      signatures: input.signatures != null ? input.signatures!.map((signature) => signature != null ? Uint8List.fromList(signature) : null) as List<Uint8List?>? : null,
    );
  }

  @override
  String toString() {
    return '''
    Input{
      hash: $hash,
      index: $index,
      sequence: $sequence,
      value: $value,
      script: $script,
      signScript: $signScript,
      prevOutScript: $prevOutScript,
      redeemScript: $redeemScript,
      witnessScript: $witnessScript,
      pubkeys: $pubkeys,
      signatures: $signatures,
      witness: $witness,
      signType: $signType,
      prevOutType: $prevOutType,
      redeemScriptType: $redeemScriptType,
      witnessScriptType: $witnessScriptType,
    }
    ''';
  }
}

class OutputBase {
  String? type;
  Uint8List? script;
  int? value;
  Uint8List? valueBuffer;
  List<Uint8List>? pubkeys;
  List<Uint8List?>? signatures;
  int? maxSignatures;

  final int tokenId;

  OutputBase({this.type, this.script, this.value, this.pubkeys, this.signatures, this.valueBuffer, this.maxSignatures, this.tokenId = 0}) {}

  factory OutputBase.expandOutput(Uint8List? script, [Uint8List? ourPubKey]) {
    if (ourPubKey == null) return OutputBase();
    var type = classifyOutput(script!);
    if (type == SCRIPT_TYPES['P2WPKH']) {
      var wpkh1 = P2WPKH(data: PaymentData(output: script)).data!.hash;
      var wpkh2 = bcrypto.hash160(ourPubKey);
      if (wpkh1.toString() != wpkh2.toString()) {
        throw ArgumentError('Hash mismatch!');
      }
      return OutputBase(type: type, pubkeys: [ourPubKey], signatures: [null]);
    }

    if (type == SCRIPT_TYPES['P2PKH']) {
      var pkh1 = P2PKH(data: PaymentData(output: script)).data!.hash;
      var pkh2 = bcrypto.hash160(ourPubKey);
      if (pkh1.toString() != pkh2.toString()) {
        throw ArgumentError('Hash mismatch!');
      }
      return OutputBase(type: type, pubkeys: [ourPubKey], signatures: [null]);
    }

    return OutputBase();
  }

  factory OutputBase.clone(OutputBase output) {
    return OutputBase(
      type: output.type,
      script: output.script != null ? Uint8List.fromList(output.script!) : null,
      value: output.value,
      valueBuffer: output.valueBuffer != null ? Uint8List.fromList(output.valueBuffer!) : null,
      pubkeys: output.pubkeys != null ? output.pubkeys!.map((pubkey) => pubkey != null ? Uint8List.fromList(pubkey) : null) as List<Uint8List>? : null,
      signatures: output.signatures != null ? output.signatures!.map((signature) => signature != null ? Uint8List.fromList(signature) : null) as List<Uint8List?>? : null,
    );
  }

  @override
  String toString() {
    return '''
      Output{
        type: $type,
        script: $script,
        value: $value,
        valueBuffer: $valueBuffer,
        pubkeys: $pubkeys,
        signatures: $signatures
      }
    ''';
  }
}

class Output extends OutputBase {
  Output({String? type, Uint8List? script, int? value, Uint8List? valueBuffer, List<Uint8List>? pubkeys, List<Uint8List>? signartures, int? maxSignatures})
      : super(type: type, script: script, value: value, valueBuffer: valueBuffer, pubkeys: pubkeys, signatures: signartures, maxSignatures: maxSignatures) {
    if (value != null && !isShatoshi(value)) {
      throw ArgumentError('Invalid ouput value');
    }
  }
}

bool isCoinbaseHash(Uint8List buffer) {
  if (!isHash256bit(buffer)) throw ArgumentError('Invalid hash');
  for (var i = 0; i < 32; ++i) {
    if (buffer[i] != 0) return false;
  }
  return true;
}

int varSliceSize(Uint8List someScript) {
  final length = someScript.length;
  return varuint.encodingLength(length) + length;
}

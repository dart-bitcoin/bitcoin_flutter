import 'dart:typed_data';
import '../src/crypto.dart';
import 'utils/check_types.dart';
import 'package:hex/hex.dart';
import 'utils/script.dart' as bscript;
import 'payments/p2pkh.dart' show P2PKH, P2PKHData;
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
final ZERO = HEX.decode('0000000000000000000000000000000000000000000000000000000000000000');
final ONE = HEX.decode('0000000000000000000000000000000000000000000000000000000000000001');
final VALUE_UINT64_MAX =  HEX.decode('ffffffffffffffff');
final BLANK_OUTPUT = new Output(script: EMPTY_SCRIPT, valueBuffer: VALUE_UINT64_MAX);

class Transaction {
  int version = 1;
  List<Input> ins = [];
  List<Output> outs = [];
  Transaction();
  int addInput(Uint8List hash, int index, [int sequence, Uint8List scriptSig]) {
    ins.add(new Input(hash: hash, index: index, sequence: sequence ?? DEFAULT_SEQUENCE, script: scriptSig ?? EMPTY_SCRIPT));
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
    final ourScript = bscript.compile(bscript.decompile(prevOutScript).where((x) {
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
      txTmp.ins.forEach((input) { input.script = EMPTY_SCRIPT; });
      txTmp.ins[inIndex].script = ourScript;
    }
    // serialize and hash
    final buffer = Uint8List(txTmp.virtualSize() + 4);
    buffer.buffer.asByteData().setUint32(buffer.length - 4, hashType, Endian.little);
    txTmp._toBuffer(buffer, 0);
    return hash256(buffer);
  }
  int virtualSize() {
    return 8 + varuint.encodingLength(ins.length) + varuint.encodingLength(outs.length)
        + ins.fold(0, (sum, input) => sum + 40 + varSliceSize(input.script))
        + outs.fold(0, (sum, output) => sum + 8 + varSliceSize(output.script));
  }
  Uint8List toBuffer([Uint8List buffer, int initialOffset]) {
    return this._toBuffer(buffer, initialOffset);
  }
  String toHex() {
    return HEX.encode(this.toBuffer());
  }
  _toBuffer([Uint8List buffer, initialOffset]) {
    if (buffer == null) buffer = new Uint8List(virtualSize());
    var bytes = buffer.buffer.asByteData();
    var offset = initialOffset ?? 0;
    bytes.setInt32(offset, version, Endian.little);
    offset += 4;
    varuint.encode(this.ins.length, buffer, offset);
    offset += varuint.encodingLength(this.ins.length);
    ins.forEach((txIn) {
      buffer.setRange(offset, offset + txIn.hash.length, txIn.hash);
      offset += txIn.hash.length;
      bytes.setUint32(offset, txIn.index, Endian.little);
      offset += 4;
      varuint.encode(txIn.script.length, buffer, offset);
      offset += varuint.encodingLength(txIn.script.length);
      buffer.setRange(offset, offset + txIn.script.length, txIn.script);
      offset += txIn.script.length;
      bytes.setUint32(offset, txIn.sequence, Endian.little);
      offset += 4;
    });
    varuint.encode(outs.length, buffer, offset);
    offset += varuint.encodingLength(outs.length);
    outs.forEach((txOut) {
      if (txOut.valueBuffer == null) {
        bytes.setUint64(offset, txOut.value, Endian.little);
        offset += 8;
      } else {
        buffer.setRange(offset, offset + txOut.valueBuffer.length, txOut.valueBuffer);
        offset += txOut.valueBuffer.length;
      }
      varuint.encode(txOut.script.length, buffer, offset);
      offset += varuint.encodingLength(txOut.script.length);
      buffer.setRange(offset, offset + txOut.script.length, txOut.script);
      offset += txOut.script.length;
    });

    // avoid slicing unless necessary
    if (initialOffset != null) return buffer.sublist(initialOffset, offset);
    return buffer;
  }
  factory Transaction.clone(Transaction _tx) {
    Transaction tx = new Transaction();
    tx.version = _tx.version;
    tx.ins = _tx.ins.map((input) {
      return Input.clone(input);
    }).toList();
    tx.outs = _tx.outs.map((output) {
      return Output.clone(output);
    }).toList();
    return tx;
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
  Input({this.hash, this.index, this.script, this.sequence, this.value, this.prevOutScript, this.pubkeys, this.signatures}) {
    if (this.hash != null && !isHash256bit(this.hash)) throw new ArgumentError("Invalid input hash");
    if (this.index != null && !isUint(this.index, 32)) throw new ArgumentError("Invalid input index");
    if (this.sequence != null && !isUint(this.sequence, 32)) throw new ArgumentError("Invalid input sequence");
    if (this.value != null && !isShatoshi(this.value)) throw ArgumentError("Invalid ouput value");
  }
  factory Input.expandInput(Uint8List scriptSig) {
    if (_isP2PKHInput(scriptSig) == false) {
      throw ArgumentError("Unsupport scriptSig!");
    }
    P2PKH p2pkh = new P2PKH(data: new P2PKHData(input: scriptSig));
    return new Input(prevOutScript: p2pkh.data.output, pubkeys: [p2pkh.data.pubkey], signatures: [p2pkh.data.signature]);
  }
  factory Input.clone(Input input) {
    return new Input(
      hash: input.hash != null ? Uint8List.fromList(input.hash) : null,
      index: input.index,
      script: input.script != null ? Uint8List.fromList(input.script) : null,
      sequence: input.sequence,
      value: input.value,
      prevOutScript: input.prevOutScript != null ? Uint8List.fromList(input.prevOutScript) : null,
      pubkeys: input.pubkeys != null ? input.pubkeys.map((pubkey) => pubkey != null ? Uint8List.fromList(pubkey) : null) : null,
      signatures: input.signatures != null ? input.signatures.map((signature) => signature != null ? Uint8List.fromList(signature) : null) : null,
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
  Output({this.script, this.value, this.pubkeys, this.signatures, this.valueBuffer}) {
    if (value != null && !isShatoshi(value)) throw ArgumentError("Invalid ouput value");
  }
  factory Output.expandOutput(Uint8List script, Uint8List ourPubKey) {
    if (_isP2PKHOutput(script) == false) {
      throw ArgumentError("Unsupport script!");
    }
    // does our hash160(pubKey) match the output scripts?
    Uint8List pkh1 = new P2PKH(data: new P2PKHData(output: script)).data.hash;
    Uint8List pkh2 = hash160(ourPubKey);
    if (pkh1 != pkh2) throw ArgumentError("Hash mismatch!");
    return new Output(
      pubkeys: [ourPubKey],
      signatures: [null]
    );
  }
  factory Output.clone(Output output) {
    return new Output(
      script: output.script != null ? Uint8List.fromList(output.script) : null,
      value: output.value,
      valueBuffer: output.valueBuffer != null ? Uint8List.fromList(output.valueBuffer) : null,
      pubkeys: output.pubkeys != null ? output.pubkeys.map((pubkey) => pubkey != null ? Uint8List.fromList(pubkey) : null) : null,
      signatures: output.signatures != null ? output.signatures.map((signature) => signature != null ? Uint8List.fromList(signature) : null) : null,
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
  return chunks.length == 2 &&
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

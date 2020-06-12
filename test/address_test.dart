import 'package:test/test.dart';
import '../lib/src/address.dart' show Address;
import '../lib/src/models/networks.dart' as NETWORKS;

main() {
  group('Address', () {
    group('validateAddress', () {
      test('base58 addresses and valid network', () {
        expect(
            Address.validateAddress(
                'mhv6wtF2xzEqMNd3TbXx9TjLLo6mp2MUuT', NETWORKS.testnet),
            true);
        expect(Address.validateAddress('1K6kARGhcX9nJpJeirgcYdGAgUsXD59nHZ'),
            true);
      });
      test('base58 addresses and invalid network', () {
        expect(
            Address.validateAddress(
                'mhv6wtF2xzEqMNd3TbXx9TjLLo6mp2MUuT', NETWORKS.bitcoin),
            false);
        expect(
            Address.validateAddress(
                '1K6kARGhcX9nJpJeirgcYdGAgUsXD59nHZ', NETWORKS.testnet),
            false);
      });
      test('bech32 addresses and valid network', () {
        expect(
            Address.validateAddress(
                'tb1qgmp0h7lvexdxx9y05pmdukx09xcteu9sx2h4ya', NETWORKS.testnet),
            true);
        expect(
            Address.validateAddress(
                'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'),
            true);
        // expect(Address.validateAddress('tb1qqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesrxh6hy'), true); TODO
      });
      test('bech32 addresses and invalid network', () {
        expect(
            Address.validateAddress(
                'tb1qgmp0h7lvexdxx9y05pmdukx09xcteu9sx2h4ya'),
            false);
        expect(
            Address.validateAddress(
                'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4', NETWORKS.testnet),
            false);
      });
      test('invalid addresses', () {
        expect(Address.validateAddress('3333333casca'), false);
      });
    });
  });
}

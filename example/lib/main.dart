import 'package:flutter/material.dart';

import 'package:bitcoin_flutter/bitcoin_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  String signTransaction() {
    String txHex =
        "0100000001f36fffeee4f706207893b0457bc44e8f6a8ebbe1cb573fcd13ae267cc022b7ea010000001976a9147270d900ee04685284d59ab8a6a5e4796b1cc5ba88acffffffff020000000000000000356a33ddd0a38bcb8d8704d8d5229767aba865e33246bd75d4ba1db77e29657de60d71a79f2c6f6424a187f64ff57c9c2d01eb4ca63a13e6f600000000001976a9147270d900ee04685284d59ab8a6a5e4796b1cc5ba88ac00000000";
    try {
      final NetworkType testnet = NetworkType(
          messagePrefix: '\x18Bitcoin Signed Message:\n',
          bech32: 'tb',
          bip32: new Bip32Type(public: 0x043587cf, private: 0x04358394),
          pubKeyHash: 0x6f,
          scriptHash: 0xc4,
          wif: 0xef);
      Transaction transaction = Transaction.clone(Transaction.fromHex(txHex));
      TransactionBuilder txBuilder =
          TransactionBuilder.fromTransaction(transaction, testnet);
      String incompleteHex = txBuilder.buildIncomplete().toHex();
      TransactionBuilder txBuilderIncomplete =
          TransactionBuilder.fromTransaction(
              Transaction.fromHex(incompleteHex), testnet);
      ECPair keyPair = ECPair.fromWIF(
          "cUfTkpBBpNqzgHyXiqcGeQqe4QkGWUcQEECi4waMvDtKf6MNtoM1",
          network: testnet);
      for (int i = 0; i < txBuilderIncomplete.inputs.length; i++) {
        txBuilderIncomplete.sign(vin: i, keyPair: keyPair);
      }
      // expect result: 0100000001f36fffeee4f706207893b0457bc44e8f6a8ebbe1cb573fcd13ae267cc022b7ea010000006a473044022002537059ff2a7563ad42bb9d3654edecc80b1da8783273d62f68cfe0e8177abb022028cf1c01a3adbfe89aa480c202b6b0a931188f1f0071617ec00a238d86ad39730121020291ee38405c21df697ad8ad6308a758288a180be71b62b05edaf3bcde1d8e40ffffffff020000000000000000356a33ddd0a38bcb8d8704d8d5229767aba865e33246bd75d4ba1db77e29657de60d71a79f2c6f6424a187f64ff57c9c2d01eb4ca63a13e6f600000000001976a9147270d900ee04685284d59ab8a6a5e4796b1cc5ba88ac00000000
      String result = txBuilderIncomplete.build().toHex();
      return result;
    } catch (e, s) {
      debugPrint('---------> s $e ${s}');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          signTransaction();
        },
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}

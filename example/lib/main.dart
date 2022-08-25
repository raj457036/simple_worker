import 'dart:io';

import 'package:easy_worker/easy_worker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Calculate Factorial'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  /// declare worker
  late final EasyWorker worker;

  @override
  void initState() {
    super.initState();

    /// initialize worker with first payload
    worker = EasyWorker(
      Entrypoint(calculateFactorial),
      workerName: "Factorial Calculator",
      initialMessage: _counter,
    );
  }

  static void calculateFactorial(int number, Sender send) {
    /// just to let stream builder know the processing has been started.
    send('loading');

    int temp = number;
    number--;
    while (number > 0) {
      temp *= number;
      number--;
      // just to simulate long running task with blocking operation
      // (operation that can freeze the ui thread)
      sleep(const Duration(milliseconds: 100));
    }

    /// once done send the calculated result
    send(temp);
  }

  @override
  void dispose() {
    /// disposing the worker process
    worker.dispose();
    super.dispose();
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
      worker.send(_counter);
    });
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
              'Factorial of $_counter is',
              style: Theme.of(context).textTheme.headline2,
            ),

            /// showing the messages/result received from the worker.
            StreamBuilder(
              stream: worker.stream,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.data == 'loading') {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return Text(
                  snapshot.data.toString(),
                  style: Theme.of(context).textTheme.headline1,
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment and Calculate Factorial',
        child: const Icon(Icons.add),
      ),
    );
  }
}

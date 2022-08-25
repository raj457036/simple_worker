import 'package:flutter_test/flutter_test.dart';
import 'package:simple_worker/simple_worker.dart';

void main() {
  test('test long running worker', () async {
    final worker = SimpleWorker(
      Entrypoint((message, send) async {
        // return series of number upto 4 at an interval of 1 sec
        int count = 4;
        if (message == "start") {
          while (count > 0) {
            send(count);
            count--;
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }),
      workerName: "Counter",
      initialMessage: "start",
    );

    await worker.waitUntilReady();

    await expectLater(
      worker.stream,
      emitsInOrder([4, 3, 2, 1]),
    );

    worker.dispose();
  });

  test('test short running worker', () async {
    /// returns factorial of a number
    final result = await SimpleWorker.compute<int, int>(
      (message, send) {
        int temp = message;
        message--;
        while (message > 0) {
          temp *= message;
          message--;
        }

        send(temp);
      },
      5, // message
      name: "Factorial",
    );

    expect(result, 120);
  });
}

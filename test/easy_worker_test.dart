import 'package:easy_worker/easy_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test long running worker', () async {
    final worker = EasyWorker<int, String>(
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

  test('Test long running worker with no initial message', () async {
    final worker = EasyWorker<int, String>(
      Entrypoint<String>((message, send) async {
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
    );

    await worker.waitUntilReady();

    worker.send("start");

    await expectLater(
      worker.stream,
      emitsInOrder([4, 3, 2, 1]),
    );

    worker.dispose();
  });

  test('Test short running worker', () async {
    /// returns factorial of a number
    final result = await EasyWorker.compute<int, int>(
      (int value, send) {
        int temp = value;
        value--;
        while (value > 0) {
          temp *= value;
          value--;
        }

        send(temp);
      },
      5, // message
      name: "Factorial",
    );

    expect(result, 120);
  });
}

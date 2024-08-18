import 'dart:io';

import 'package:easy_worker/easy_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void calculateFactorial(int number, Sender send) {
  int temp = number;
  number--;
  while (number > 0) {
    temp *= number;
    number--;
    // just to simulate long running task with blocking operation
    // (operation that can freeze the ui thread)
    sleep(const Duration(milliseconds: 200));
  }

  /// once done send the calculated result to the parent process
  send(temp);
}

void main() {
  test("Sync Long Running Tasks", () async {
    final worker = EasyCompute<int, int>(
      ComputeEntrypoint(calculateFactorial),
      workerName: "Factorial Calculator",
    );

    await worker.waitUntilReady();

    final testCases = {
      5: 120,
      3: 6,
      7: 5040,
      10: 3628800,
    };

    // Run tests in parallel
    final results = await Future.wait(testCases.entries.map((entry) async {
      final result = await worker.compute(entry.key);
      return result == entry.value;
    }));

    // Assert that all results are true
    expect(results.every((result) => result), isTrue);

    worker.dispose();
  });

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

  test('Test long running worker with easy compute', () async {
    final worker = EasyCompute<int, int>(
      ComputeEntrypoint((message, send) async {
        // return series of number upto 4 at an interval of 1 sec

        int sum = 0;
        for (var i = 1; i <= message; i++) {
          sum += i;
          await Future.delayed(const Duration(seconds: 1));
        }

        send(sum);
      }),
      workerName: "Summer",
    );

    await worker.waitUntilReady();

    // List of test cases
    final testCases = {
      5: 15,
      3: 6,
      7: 28,
      10: 55,
    };

    // Run tests in parallel
    final results = await Future.wait(testCases.entries.map((entry) async {
      final result = await worker.compute(entry.key);
      return result == entry.value;
    }));

    // Assert that all results are true
    expect(results.every((result) => result), isTrue);

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

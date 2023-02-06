# Easy Worker

Working with Dart Isolate is not very easy for beginners and tedious to write
big boilerplate code for veteran and even though there are lot of packages to
solve this issue none were exactly as straight forward as they try to be.

Well then **EasyWorker** might be the simplest way to work with dart isolate so far.

## Features

1. Easy to learn and use
2. Simple to start a long running process or a short computation.
3. easiest bidirectional communication

## Getting started

### Add `simple_worker` to `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  easy_worker:
  ...
```

## Usage

1. ### For long running task and bidirectional communication between your main isolate and the worker isolate, You will need two things:

- **A static or top level function for example this factorial calculator**

```dart
/// This takes number (message/payload or whatever you wanna say) and a sender
void calculateFactorial(int number, Sender send) {
    int temp = number;
    number--;
    while (number > 0) {
      temp *= number;
      number--;
      // just to simulate long running task with blocking operation
      // (operation that can freeze the ui thread)
      sleep(const Duration(seconds: 1));
    }

    /// once done send the calculated result to the parent process
    send(temp);
  }
```

- **A simple worker instance**

```dart
final worker = EasyWorker(
      Entrypoint(calculateFactorial),
      workerName: "Factorial Calculator",
      initialMessage: 0, // the initial payload for this worker will be 0
    );
```

2. ### Now how to send and receive to and from this worker?

- get the first result only

```dart
final result = await worker.stream.first;
```

- Listen to all the results coming from isolate

```dart
worker.onMessage((message) {
    print("Message From Worker: $message");
});
```

- Send Message to the worker

```dart
/// send 6 as payload to the worker to get the factorial of
/// 6.
worker.send(6);

```

3. ### Dispose when not needed anymore

```dart
worker.dispose()
```

4. ### What about simple one time tasks?

```dart
/// just call compute and pass your entrypoint and payload
final result = await EasyWorker.compute(calculateFactorial, 5);

print(result); // 120

```

## Additional information

FAQ:

1. Why this package if there are already other who are doing the same?

- Basically all of them just have a learning curve and there technicalities, this package doesn't.

2. I want to implement something. how to do it?

- You can create a feature request on github.

## License

- MIT

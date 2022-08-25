library isolate_helper;

import 'dart:async';
import 'dart:isolate';

typedef Sender = void Function(Object? message);
typedef WorkerEntrypoint<T> = Function(T message, Sender send);

class _WorkerExit {}

/// {@template entrypoint}
/// A wrapper that creates two way communication possible.
///
/// The [entry] function must be a top-level function or a static method
/// that can be called with a single argument, that is, a compile-time
/// constant function value which accepts at least one positional
/// parameter and has at most one required positional parameter.
/// The function may accept any number of optional parameters,
/// as long as it can be called with just a single argument.
/// The function must not be the value of a function expression or
/// an instance method tear-off.
/// {@endtemplate}
class Entrypoint<T> {
  /// The [entry] function must be a top-level function or a static method
  /// that can be called with a single argument, that is, a compile-time
  /// constant function value which accepts at least one positional
  /// parameter and has at most one required positional parameter.
  /// The function may accept any number of optional parameters,
  /// as long as it can be called with just a single argument.
  /// The function must not be the value of a function expression or
  /// an instance method tear-off.
  final WorkerEntrypoint<T> entry;

  /// {@macro entrypoint}
  Entrypoint(this.entry);

  void call(SendPort sendport) {
    final ReceivePort receivePort = ReceivePort();
    sendport.send(receivePort.sendPort);
    receivePort.listen((message) {
      if (message is _WorkerExit) {
        receivePort.close();
        return;
      }

      entry(message, sendport.send);
    });
  }
}

/// {@template worker}
/// Creates and spawns an isolate that shares the same code as the current
/// isolate.
///
/// The argument [entryPoint] specifies the initial function to call in the
/// spawned isolate. The entry-point function is invoked in the new isolate
/// with [message] as the only argument.
/// {@endtemplate}
class EasyWorker {
  EasyWorker(
    void Function(SendPort from) entrypoint, {
    required String workerName,
    dynamic initialMessage,
    bool paused = false,
    bool errorsAreFatal = true,
    SendPort? onExit,
    SendPort? onError,
  }) : _fromIsolate = ReceivePort(workerName) {
    _fromIsolate.listen((message) {
      if (message is SendPort) {
        _toIsolate = message;
        if (!_firstMessageDelivered) {
          send(initialMessage);
          _firstMessageDelivered = true;
        }
        return;
      }

      _controller.sink.add(message);
    });

    Isolate.spawn(
      entrypoint,
      _fromIsolate.sendPort,
      debugName: "Worker: $workerName",
      paused: paused,
      onExit: onExit,
      onError: onError,
      errorsAreFatal: errorsAreFatal,
    ).then((value) {
      isolate = value;
      Future.delayed(
          const Duration(milliseconds: 50), () => _ready.complete(true));
    });
  }

  bool _firstMessageDelivered = false;
  final _ready = Completer<bool>();
  final StreamController _controller = StreamController.broadcast();
  late final SendPort _toIsolate;
  final ReceivePort _fromIsolate;

  /// The isolate instance attached to this worker.
  late final Isolate isolate;

  /// check if this isolate is ready to accept message.
  bool get isReady => _ready.isCompleted;

  /// listen for any message from this worker
  Stream get stream => _controller.stream;

  /// listen for any message from this worker
  StreamSubscription<dynamic> onMessage(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _controller.stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  /// send message to this worker
  Future<void> send(message) async {
    _toIsolate.send(message);
  }

  /// wait until this worker spawns
  Future<void> waitUntilReady() async {
    if (!_ready.isCompleted) {
      await _ready.future;
    }
  }

  /// Requests the isolate to pause.
  ///
  /// When the isolate receives the pause command, it stops processing events
  /// from the event loop queue. It may still add new events to the queue in
  /// response to, e.g., timers or receive-port messages. When the isolate is
  /// resumed, it starts handling the already enqueued events.
  ///
  /// The pause request is sent through the isolate's command port,
  ///  which bypasses the receiving isolate's event loop. The pause
  /// takes effect when it is received, pausing the event loop as it
  /// is at that time.
  ///
  /// To resume this worker call [resume] method
  void pause() => isolate.pause(isolate.pauseCapability);

  /// Requests the isolate to resume again.
  void resume() => isolate.resume(isolate.pauseCapability!);

  /// Spin up a short lived worker, execute the [entrypoint] and get the result
  static Future<R> compute<R, T>(
    WorkerEntrypoint<T> entrypoint,
    T payload, {
    String name = "",
  }) async {
    final onError = ReceivePort();
    final worker = EasyWorker(
      Entrypoint(entrypoint),
      workerName: "compute${name.trim().isEmpty ? "" : ":$name"}",
      initialMessage: payload,
      onError: onError.sendPort,
      // onError: onError.sendPort,
    );
    final Completer<R> completer = Completer<R>();
    try {
      worker.stream.take(1).listen((event) => completer.complete(event));
      onError.take(1).listen((event) => completer.completeError(event));

      final result = await completer.future;

      return result;
    } catch (e) {
      rethrow;
    } finally {
      onError.close();
      worker.dispose();
    }
  }

  /// dispose all the resources and close the worker
  void dispose() {
    _controller.close();
    _toIsolate.send(_WorkerExit());
    _fromIsolate.close();
  }
}

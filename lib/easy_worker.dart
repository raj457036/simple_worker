library isolate_helper;

import 'dart:async';
import 'dart:isolate';

import 'package:easy_worker/utils.dart';

typedef Sender = void Function(Object? message);
typedef WorkerEntrypoint<I> = void Function(I message, Sender send);
typedef VoidCallback = Future<void> Function();

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
///
/// [I] : Input Type
/// {@endtemplate}
class Entrypoint<I> {
  /// The [entry] function must be a top-level function or a static method
  /// that can be called with a single argument, that is, a compile-time
  /// constant function value which accepts at least one positional
  /// parameter and has at most one required positional parameter.
  /// The function may accept any number of optional parameters,
  /// as long as it can be called with just a single argument.
  /// The function must not be the value of a function expression or
  /// an instance method tear-off.
  final WorkerEntrypoint<I> entry;
  final VoidCallback? onInit;

  /// {@macro entrypoint}
  Entrypoint(this.entry, {this.onInit});

  Future<void> call(SendPort sendport) async {
    await onInit?.call();
    final receivePort = ReceivePort();
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
class EasyWorker<R, I> {
  /// {@macro worker}
  EasyWorker(
    Entrypoint<I> entrypoint, {
    required String workerName,
    I? initialMessage,
    bool paused = false,
    bool errorsAreFatal = true,
    SendPort? onExit,
    SendPort? onError,
  }) : _fromIsolate = ReceivePort(workerName) {
    _fromIsolate.listen((message) {
      if (message is SendPort) {
        _toIsolate = message;
        _ready.complete(true);
        if (!_firstMessageDelivered && initialMessage != null) {
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
    });
  }

  bool _firstMessageDelivered = false;
  final _ready = Completer<bool>();
  final _controller = StreamController<R>.broadcast();
  late final SendPort _toIsolate;
  final ReceivePort _fromIsolate;

  /// The isolate instance attached to this worker.
  late final Isolate isolate;

  /// check if this isolate is ready to accept message.
  bool get isReady => _ready.isCompleted;

  /// listen for any message from this worker
  Stream<R> get stream => _controller.stream;

  /// listen for any message from this worker
  StreamSubscription onMessage(
    void Function(R)? onData, {
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
  Future<void> send(I message) async {
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
  static Future<R> compute<R, I>(
    WorkerEntrypoint<I> entrypoint,
    I payload, {
    String name = "",
    VoidCallback? onInit,
  }) async {
    final onError = ReceivePort();
    final worker = EasyWorker<R, I>(
      Entrypoint<I>(entrypoint, onInit: onInit),
      workerName: "compute${name.trim().isEmpty ? "" : ":$name"}",
      initialMessage: payload,
      onError: onError.sendPort,
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

typedef MessageWithID<R> = (String, R);

class ComputeEntrypoint<I> extends Entrypoint<I> {
  ComputeEntrypoint(super.entry, {super.onInit});

  @override
  Future<void> call(SendPort sendport) async {
    await onInit?.call();
    final ReceivePort receivePort = ReceivePort();
    sendport.send(receivePort.sendPort);
    receivePort.listen((message) {
      if (message is _WorkerExit) {
        receivePort.close();
        return;
      }

      if (message is MessageWithID<I>) {
        final (id, payload) = message;
        entry(payload, (response) {
          sendport.send((id, response));
        });
        return;
      }

      entry(message, sendport.send);
    });
  }
}

class EasyCompute<R, I> extends EasyWorker<MessageWithID<R>, I> {
  StreamSubscription? _subscription;
  final Duration? timeoutDuration;
  final _tasks = <String, Completer<R>>{};

  EasyCompute(
    ComputeEntrypoint<I> entrypoint, {
    required String workerName,
    this.timeoutDuration,
  }) : super(entrypoint, workerName: workerName) {
    _subscription = onMessage(onData);
  }

  void onData(MessageWithID<R> data) {
    final (id, result) = data;

    final completer = _tasks.remove(id);
    if (completer == null) return;
    completer.complete(result);
  }

  Future<R> compute(I payload) async {
    final completer = Completer<R>();
    final id = getID();
    _tasks[id] = completer;
    _toIsolate.send((id, payload));

    try {
      final future = completer.future;

      if (timeoutDuration != null) {
        return await future.timeout(timeoutDuration!);
      }
      return await future;
    } catch (e) {
      _tasks.remove(id);
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

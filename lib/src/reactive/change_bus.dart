import 'dart:async';
import 'change_event.dart';

/// A simple event bus for broadcasting data change events.
class ChangeBus {
  final StreamController<ChangeEvent> _controller =
  StreamController.broadcast();

  /// Emits a [ChangeEvent] to all listeners.
  void emit(ChangeEvent event) {
    _controller.add(event);
  }

  /// Whether there are any active listeners.
  bool get hasListeners => _controller.hasListener;

  /// A broadcast stream of change events.
  Stream<ChangeEvent> get stream => _controller.stream;

  /// Closes the stream controller and releases resources.
  void close() {
    _controller.close();
  }
}

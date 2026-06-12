import 'dart:async';
import 'change_event.dart';

class ChangeBus {
  final StreamController<ChangeEvent> _controller =
  StreamController.broadcast();

  void emit(ChangeEvent event) {
    _controller.add(event);
  }

  bool get hasListeners => _controller.hasListener;

  Stream<ChangeEvent> get stream => _controller.stream;

  void close() {
    _controller.close();
  }
}

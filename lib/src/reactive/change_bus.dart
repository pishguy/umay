import 'dart:async';
import 'change_event.dart';

class ChangeBus {
  final StreamController<ChangeEvent> _controller =
  StreamController.broadcast();

  void emit(ChangeEvent event) {
    _controller.add(event);
  }

  Stream<ChangeEvent> get stream => _controller.stream;

  void close() {
    _controller.close();
  }
}

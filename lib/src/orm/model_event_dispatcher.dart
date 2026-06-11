import 'umay_model.dart';

class ModelEventDispatcher {

  final Map<String, List<Function>> _listeners = {};

  void listen(String event, Function callback) {

    _listeners.putIfAbsent(event, () => []);

    _listeners[event]!.add(callback);

  }

  void dispatch(String event, UmayModel model) {

    final listeners = _listeners[event];

    if (listeners == null) return;

    for (final fn in listeners) {
      fn(model);
    }

  }

}

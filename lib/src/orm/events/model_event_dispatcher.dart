import 'model_event.dart';

typedef ModelListener = Future<void> Function(ModelEvent event);

class ModelEventDispatcher {

  final Map<ModelEventType, List<ModelListener>> _listeners = {};

  void listen(
      ModelEventType type,
      ModelListener listener,
      ) {

    _listeners
        .putIfAbsent(type, () => [])
        .add(listener);
  }

  Future<void> dispatch(
      ModelEventType type,
      dynamic model,
      ) async {

    final list = _listeners[type];

    if (list == null) return;

    final event = ModelEvent(type, model);

    for (final l in list) {
      await l(event);
    }
  }

}

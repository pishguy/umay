import 'model.dart';

class ModelEvents {

  static final Map<String,List<Function>> _listeners = {};

  static void listen(String event,Function fn){

    _listeners.putIfAbsent(event,()=>[]);
    _listeners[event]!.add(fn);

  }

  static void dispatch(String event,Model model){

    final list = _listeners[event];

    if(list == null) return;

    for(final fn in list){
      fn(model);
    }

  }

}

import '../core/umay_box.dart';
import 'change_event.dart';

extension KeyWatch on UmayBox {
  Stream<ChangeEvent> watchKey(String key) {
    return watch().where((event) => event.key == key);
  }
}

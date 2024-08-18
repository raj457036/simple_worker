import 'package:uuid/uuid.dart' as uuid;

const _s = uuid.Uuid();
String getID() {
  return _s.v4();
}

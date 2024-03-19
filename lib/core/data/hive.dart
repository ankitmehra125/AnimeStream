import 'package:hive/hive.dart';

Future<dynamic> getVal(String itemKey) async {
  var box = await Hive.openBox('animestream');
  if (!box.isOpen) {
    box = await Hive.openBox('animestream');
  }
  final vals = await box.get(itemKey);
  await box.close();
  return vals;
}

Future<void> storeVal(String itemKey, dynamic val) async {
  try {
    var box = await Hive.openBox('animestream');
    if (!box.isOpen) {
      box = await Hive.openBox('animestream');
    }
    await box.put(itemKey, val);
    await box.close();
  } catch (err) {
    print(err);
  }
}

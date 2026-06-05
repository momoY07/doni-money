import 'package:hive_flutter/hive_flutter.dart';

class Storage {
  static const txBoxName = 'txBox';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(txBoxName);
  }

  static Box get txBox => Hive.box(txBoxName);
}
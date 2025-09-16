// 只保留一个实现：FlutterBlue
import 'ble_client.dart';
import 'ble_client_flutterblue.dart';

BleClient createBleClient() {
  return FlutterBlueBleClient(); // Windows 也用它
}

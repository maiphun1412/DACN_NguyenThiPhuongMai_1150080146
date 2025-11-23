import 'package:permission_handler/permission_handler.dart';

// Yêu cầu quyền truy cập camera và storage
Future<void> requestPermissions() async {
  var cameraStatus = await Permission.camera.request();
  var storageStatus = await Permission.storage.request();

  if (cameraStatus.isDenied || storageStatus.isDenied) {
    print("Quyền bị từ chối");
  } else {
    print("Quyền đã được cấp");
  }
}

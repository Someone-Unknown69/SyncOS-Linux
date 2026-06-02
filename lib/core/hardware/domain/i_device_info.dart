abstract class IDeviceInfo {
  Future<String> getDeviceName();
  Future<String> getOSVersion();
}
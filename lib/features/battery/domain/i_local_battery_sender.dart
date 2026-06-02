abstract class IBatteryMonitorService {
  Future<void> start();
  void stop();
  void dispose();
}
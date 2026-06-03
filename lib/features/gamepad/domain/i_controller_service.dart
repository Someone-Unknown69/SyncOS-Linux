abstract class IControllerService {
  void init();
  void dispose();

  // action (up / down) , keyname - self explanatory
  void keyPress(String action, String keyName);

  void updateLeftStick(double x, double y);
  void updateRightStick(double x, double y);
  void updateDpad(int x, int y);
  void updateTriggers(double l2, double r2);
}
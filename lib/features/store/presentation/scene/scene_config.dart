/// Tunable numbers of the 3D store. Units are metres.
class SceneConfig {
  SceneConfig._();

  // Player
  static const double eyeHeight = 1.6;
  static const double walkSpeed = 3.8;
  static const double playerRadius = 0.35;
  static const double turnSpeed = 4.0;
  static const double lookSensitivity = 0.0042;
  static const double dragWalkPerPixel = 0.012;
  static const double scrollWalkPerPixel = 0.01;
  static const double scrollLookPerPixel = 0.004;
  static const double minFov = 30;
  static const double maxFov = 85;
  static const double maxPitch = 0.65;
  static const double lookPitch = -0.08;
  static const double enterSpeed = 1.9;
  static const double doorOpenAngle = 1.75;
  static const double fov =
      62; // DIAGONAL field of view in degrees (zoom changes it)
  static const double turnSmoothing = 14;
  static const double accel = 9;
  static const double bobHeight = 0.025;
  static const double bobSpeed = 9;

  // Lighting (lower these if the scene looks washed out)
  static const double hemiIntensity = 0.75;
  static const double sunIntensity = 0.45;

  // Building (store interior spans x -10..10, z -12..6; gate is in the z = 6 wall)
  static const double halfWidth = 10;
  static const double backZ = -12;
  static const double frontZ = 6;
  static const double wallHeight = 4.6;
  static const double gateHalfWidth = 2;

  // Where the shopper starts outside and where they stop right inside the gate
  static const double startZ = 13.5;
  static const double insideStartZ = 2.6;

  // Walkable area inside
  static const double minX = -9.4;
  static const double maxX = 9.4;
  static const double minZ = -11.4;
  static const double maxZ = 5.4;

  // Shelves
  static const double wallShelfX = 9.7;
  static const double innerShelfX = 3.2;
  static const double shelfDepth = 0.6;
  static const double shelfHeight = 3.4;
  static const int slotsPerBoard = 6;
  static const double shelfZStart =
      -6.4; // clear lane in front of the service counter
  static const double shelfZEnd = -1;
  static const List<double> boardHeights = [0.45, 1.1, 1.75, 2.4];
  static const double slotSpacing = 1.0;

  /// A tap on a product farther than this makes the shopper walk to it first.
  static const double openDistance = 3.6;
  static const double standDistance = 1.9;
}

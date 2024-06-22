import 'dart:math' show atan2, cos, sin, tan;

import 'package:vector_math/vector_math.dart' show radians, degrees;

class Utils {
  Utils._();

  static final _kaabaLatitude = radians(21.422487);
  static final _kaabaLongitude = radians(39.826206);

  /// Returns the Qiblah offset for the current location
  static double getOffsetFromNorth(
      double currentLatitude, double currentLongitude) {
    var latRad = radians(currentLatitude);
    var lonRad = radians(currentLongitude);

    var deltaLongitude = _kaabaLongitude - lonRad;

    var y = sin(deltaLongitude);
    var x =
        cos(latRad) * tan(_kaabaLatitude) - sin(latRad) * cos(deltaLongitude);

    var bearing = atan2(y, x);
    return (degrees(bearing) + 360) % 360;
  }
}

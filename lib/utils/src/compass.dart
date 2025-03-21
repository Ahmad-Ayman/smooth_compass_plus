part of '../smooth_compass_plus.dart';

class _Compass {
  final List<double> _rotationMatrix = List.filled(9, 0.0);
  double _azimuth = 0.0;
  double azimuthFix = 0.0;
  double qiblah = 0.0;
  double x = 0, y = 0;
  final List<_CompassStreamSubscription> _updatesSubscriptions = [];
  final Location location = Location(); // Initialize Location instance
  final Logger logger = Logger(); // Initialize Logger instance

  // ignore: cancel_subscriptions
  StreamSubscription<SensorEvent>? _rotationSensorStream;
  StreamSubscription<senPls.AccelerometerEvent>? _accelerometerSensorStream;
  final StreamController<CompassModel> _internalUpdateController =
      StreamController.broadcast();

  /// Starts the compass updates.
  Stream<CompassModel> compassUpdates(Duration? interval, double azimuthFix,
      {MyLoc? myLoc, bool forceGPS = false}) {
    this.azimuthFix = azimuthFix;
    // ignore: close_sinks
    StreamController<CompassModel>? compassStreamController;
    _CompassStreamSubscription? compassStreamSubscription;
    // ignore: cancel_subscriptions
    Future<void> _handleGPS() async {
      // Original code for handling GPS with myLoc
      if (myLoc != null) {
        double qiblahOffset =
            getQiblaDirection(myLoc.latitude, myLoc.longitude, 0);
        compassStreamController?.add(CompassModel(
            turns: 0, angle: 0, qiblahOffset: qiblahOffset, source: 'GPS'));
      }
      // New code to handle GPS without myLoc
      else {
        LocationData? locationData = await _getLocation();
        if (locationData != null) {
          double qiblahOffset = getQiblaDirection(
              locationData.latitude!, locationData.longitude!, 0);
          compassStreamController?.add(CompassModel(
              turns: 0, angle: 0, qiblahOffset: qiblahOffset, source: 'GPS'));
          _startAccelerometerSensor(); // Start accelerometer to update heading
        }
      }
      logger.i("Using GPS for Qiblah direction"); // Use logger instead of print
    }

    StreamSubscription<CompassModel> compassSubscription =
        _internalUpdateController.stream.listen((value) {
      if (interval != null) {
        DateTime instant = DateTime.now();
        compassStreamSubscription?.lastUpdated = instant;
      }

      compassStreamController!.add(getCompassValues(value.angle,
          myLoc?.latitude ?? 0, myLoc?.longitude ?? 0, value.source));
    });
    compassSubscription.onDone(() {
      _updatesSubscriptions.remove(compassStreamSubscription);
    });
    compassStreamSubscription = _CompassStreamSubscription(compassSubscription);
    _updatesSubscriptions.add(compassStreamSubscription);
    compassStreamController = StreamController<CompassModel>.broadcast(
      onListen: () async {
        if (forceGPS) {
          // Check if forceGPS is true
          await _handleGPS();
        } else {
          if (await isCompassAvailable) {
            if (_sensorStarted()) return;
            _startSensor();
          } else {
            await _handleGPS();
          }
        }
      },
      onCancel: () {
        compassStreamSubscription!.subscription.cancel();
        _updatesSubscriptions.remove(compassStreamSubscription);
        if (_updatesSubscriptions.isEmpty) _stopSensor();
      },
    );
    return compassStreamController.stream;
  }

  /// Checks if the rotation sensor is available in the system.
  static Future<bool> get isCompassAvailable async {
    bool isRotationAvailable =
        await SensorManager().isSensorAvailable(Sensors.ROTATION);
    bool isGyroscopeAvailable =
        await SensorManager().isSensorAvailable(Sensors.GYROSCOPE);

    return isRotationAvailable || isGyroscopeAvailable;
  }

  /// Determines which sensor is available and starts the updates if possible.
  void _startSensor() async {
    bool isAvailable = await isCompassAvailable;
    if (isAvailable) {
      _startRotationSensor();
      logger.i("Using Rotation/gyroscope Sensor for Qiblah direction");
    } else {
      // Fallback to GPS
      await _handleGPS();
    }
  }

  /// Starts the rotation sensor for each platform.
  void _startRotationSensor() async {
    final stream = await SensorManager().sensorUpdates(
      sensorId: Sensors.ROTATION,
      interval: Sensors.SENSOR_DELAY_NORMAL,
    );
    _rotationSensorStream = stream.listen((event) {
      if (Platform.isAndroid) {
        _computeRotationMatrixFromVector(event.data);
        List<double> orientation = _computeOrientation();
        _azimuth = degrees(orientation[0]);
        _azimuth = (_azimuth + azimuthFix + 360) % 360;
      } else if (Platform.isIOS) {
        _azimuth = event.data[0];
      }
      _internalUpdateController.add(CompassModel(
          turns: _azimuth / 360,
          angle: _azimuth,
          qiblahOffset: 0,
          source: 'Rotation'));
    });
  }

  void _startAccelerometerSensor() {
    _accelerometerSensorStream = senPls.accelerometerEvents.listen((event) {
      double newHeading = atan2(event.y, event.x) * (180 / pi);
      if (newHeading < 0) newHeading += 360;
      _internalUpdateController.add(CompassModel(
          turns: newHeading / 360,
          angle: newHeading,
          qiblahOffset: 0,
          source: 'GPS'));
    });
  }

  /// Checks if the sensors has been started.
  bool _sensorStarted() {
    return _rotationSensorStream != null;
  }

  /// Stops the sensors updates subscribed.
  void _stopSensor() {
    if (_sensorStarted()) {
      _rotationSensorStream?.cancel();
      _accelerometerSensorStream?.cancel();

      _rotationSensorStream = null;
      _accelerometerSensorStream = null;
    }
  }

  /// Updates the current rotation matrix using the values gathered by the
  /// rotation vector sensor.
  ///
  /// Returns true if the computation was successful and false otherwise.
  void _computeRotationMatrixFromVector(List<double> rotationVector) {
    double q0;
    double q1 = rotationVector[0];
    double q2 = rotationVector[1];
    double q3 = rotationVector[2];
    x = q1;
    y = q2;
    if (rotationVector.length == 4) {
      q0 = rotationVector[3];
    } else {
      q0 = 1 - q1 * q1 - q2 * q2 - q3 * q3;
      q0 = (q0 > 0) ? sqrt(q0) : 0;
    }
    double sqQ1 = 2 * q1 * q1;
    double sqQ2 = 2 * q2 * q2;
    double sqQ3 = 2 * q3 * q3;
    double q1Q2 = 2 * q1 * q2;
    double q3Q0 = 2 * q3 * q0;
    double q1Q3 = 2 * q1 * q3;
    double q2Q0 = 2 * q2 * q0;
    double q2Q3 = 2 * q2 * q3;
    double q1Q0 = 2 * q1 * q0;
    _rotationMatrix[0] = 1 - sqQ2 - sqQ3;
    _rotationMatrix[1] = q1Q2 - q3Q0;
    _rotationMatrix[2] = q1Q3 + q2Q0;
    _rotationMatrix[3] = q1Q2 + q3Q0;
    _rotationMatrix[4] = 1 - sqQ1 - sqQ3;
    _rotationMatrix[5] = q2Q3 - q1Q0;
    _rotationMatrix[6] = q1Q3 - q2Q0;
    _rotationMatrix[7] = q2Q3 + q1Q0;
    _rotationMatrix[8] = 1 - sqQ1 - sqQ2;
  }

  /// Compute the orientation utilizing the data realized by the
  /// [_computeRotationMatrix] method.
  ///
  /// * [rotationMatrix] the rotation matrix to calculate the orientation.
  ///
  /// Returns a list with the result of the orientation.
  List<double> _computeOrientation() {
    var orientation = <double>[];
    orientation.add(atan2(_rotationMatrix[1], _rotationMatrix[4]));
    orientation.add(asin(-_rotationMatrix[7]));
    orientation.add(atan2(-_rotationMatrix[6], _rotationMatrix[8]));
    return orientation;
  }

  Future<void> _handleGPS() async {
    // Original code for handling GPS with myLoc
    // New code to handle GPS without myLoc
    LocationData? locationData = await _getLocation();
    if (locationData != null) {
      double qiblahOffset =
          getQiblaDirection(locationData.latitude!, locationData.longitude!, 0);
      _internalUpdateController.add(CompassModel(
          turns: 0, angle: 0, qiblahOffset: qiblahOffset, source: 'GPS'));
      _startAccelerometerSensor(); // Start accelerometer to update heading
    }
    logger.i("Using GPS for Qiblah direction"); // Use logger instead of print
  }

  Future<LocationData?> _getLocation() async {
    bool hasPermission = await _checkLocationServiceAndPermissions();
    if (!hasPermission) {
      return null;
    }

    LocationData locationData;
    try {
      locationData = await location.getLocation();
    } catch (e) {
      return null;
    }
    return locationData;
  }

  Future<bool> _checkLocationServiceAndPermissions() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }
}

/// Class that represents a subscription to the stream of compass updates.
class _CompassStreamSubscription {
  /// Subscription to the stream of the compass.
  StreamSubscription subscription;

  /// Date of the last update.
  DateTime? lastUpdated;

  _CompassStreamSubscription(this.subscription) {
    lastUpdated = DateTime.now();
  }
}

///to get Qibla direction
double getQiblaDirection(
    double latitude, double longitude, double headingValue) {
  if (latitude != 0 && longitude != 0) {
    final offSet = Utils.getOffsetFromNorth(latitude, longitude);

    // Adjust Qiblah direction based on North direction
    return offSet;
  } else {
    return 0;
  }
}

// location model
class MyLoc {
  double latitude;
  double longitude;

  MyLoc({required this.latitude, required this.longitude});
}

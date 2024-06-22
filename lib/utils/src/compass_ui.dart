import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:smooth_compass_plus/utils/src/qibla_utils.dart';

import '../smooth_compass_plus.dart';
import 'widgets/error_widget.dart';

double preValue = 0;
double turns = 0;

/// Custom callback for building the widget
typedef WidgetBuilder = Widget Function(BuildContext context,
    AsyncSnapshot<CompassModel>? compassData, Widget compassAsset);

class SmoothCompassWidget extends StatefulWidget {
  final WidgetBuilder? compassBuilder;
  final Widget? compassAsset;
  final Widget? loadingAnimation;
  final int? rotationSpeed;
  final double? height;
  final double? width;
  final bool? isQiblahCompass;
  final Widget? errorLocationServiceWidget;
  final Widget? errorLocationPermissionWidget;
  final bool forceGPS; // New property to force GPS usage

  const SmoothCompassWidget({
    Key? key,
    this.compassBuilder,
    this.compassAsset,
    this.rotationSpeed = 400,
    this.height = 200,
    this.width = 200,
    this.isQiblahCompass = false,
    this.errorLocationServiceWidget,
    this.errorLocationPermissionWidget,
    this.loadingAnimation,
    this.forceGPS = false,
  }) : super(key: key);

  @override
  State<SmoothCompassWidget> createState() => _SmoothCompassWidgetState();
}

class _SmoothCompassWidgetState extends State<SmoothCompassWidget> {
  var location = Location();
  Stream<CompassModel>? _compassStream;
  double currentHeading = 0.0;
  double qiblahOffset = 0.0;
  double previousHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeCompassStream();
  }

  void _initializeCompassStream() {
    if (widget.forceGPS) {
      _getLocation().then((locationData) {
        if (locationData != null) {
          qiblahOffset = _calculateQiblahOffset(
            locationData.latitude ?? 0,
            locationData.longitude ?? 0,
          );
          setState(() {
            _compassStream = Stream.periodic(
              const Duration(milliseconds: 200),
              (_) {
                return CompassModel(
                  turns: currentHeading / 360,
                  angle: currentHeading,
                  qiblahOffset: qiblahOffset,
                  source: 'GPS',
                );
              },
            );
          });
          accelerometerEvents.listen((AccelerometerEvent event) {
            double newHeading = atan2(event.y, event.x) * (180 / pi);
            if (newHeading < 0) newHeading += 360;
            setState(() {
              currentHeading =
                  previousHeading + 0.1 * (newHeading - previousHeading);
              previousHeading = currentHeading;
            });
          });
        }
      });
    } else {
      Compass().isCompassAvailable().then((isAvailable) {
        if (isAvailable) {
          setState(() {
            _compassStream = Compass().compassUpdates(
              interval: const Duration(milliseconds: 200),
              azimuthFix: 0.0,
            );
          });
        } else {
          _getLocation().then((locationData) {
            if (locationData != null) {
              qiblahOffset = _calculateQiblahOffset(
                locationData.latitude ?? 0,
                locationData.longitude ?? 0,
              );
              setState(() {
                _compassStream = Stream.periodic(
                  const Duration(milliseconds: 200),
                  (_) {
                    return CompassModel(
                      turns: currentHeading / 360,
                      angle: currentHeading,
                      qiblahOffset: qiblahOffset,
                      source: 'GPS',
                    );
                  },
                );
              });
              accelerometerEvents.listen((AccelerometerEvent event) {
                double newHeading = atan2(event.y, event.x) * (180 / pi);
                if (newHeading < 0) newHeading += 360;
                setState(() {
                  currentHeading =
                      previousHeading + 0.1 * (newHeading - previousHeading);
                  previousHeading = currentHeading;
                });
              });
            }
          });
        }
      });
    }
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

  double _calculateQiblahOffset(double latitude, double longitude) {
    return Utils.getOffsetFromNorth(latitude, longitude);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompassModel>(
      stream: _compassStream,
      builder: (context, AsyncSnapshot<CompassModel> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return widget.loadingAnimation != null
              ? widget.loadingAnimation!
              : const Center(
                  child: CircularProgressIndicator(),
                );
        }
        if (snapshot.hasError) {
          return widget.loadingAnimation != null
              ? widget.loadingAnimation!
              : const Center(
                  child: CircularProgressIndicator(),
                );
        }
        return Column(
          children: [
            Text(
                'Using ${snapshot.data?.source ?? 'Sensor'}'), // Display the source
            widget.compassBuilder == null
                ? _defaultWidget(snapshot, context)
                : widget.compassBuilder!(
                    context,
                    snapshot,
                    widget.compassAsset ??
                        Container()), // Replace with your default asset
          ],
        );
      },
    );
  }

  /// Default widget if custom widget isn't provided
  Widget _defaultWidget(
      AsyncSnapshot<CompassModel> snapshot, BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Qiblah direction image fixed at the top
        Positioned(
          top: 0,
          child: Image.asset('assets/images/kaabafixed.png', height: 100),
        ),
        // Rotating needle
        AnimatedRotation(
          turns: (snapshot.data!.angle - snapshot.data!.qiblahOffset) / 360,
          duration: Duration(milliseconds: widget.rotationSpeed!),
          child: Container(
            height:
                widget.height ?? MediaQuery.of(context).size.shortestSide * 0.8,
            width:
                widget.width ?? MediaQuery.of(context).size.shortestSide * 0.8,
            decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage('assets/images/compass.png'),
                    fit: BoxFit.cover)),
          ),
        ),
      ],
    );
  }
}

/// Calculating compass Model
CompassModel getCompassValues(
    double heading, double latitude, double longitude, String source) {
  double direction = heading;
  direction = direction < 0 ? (360 + direction) : direction;

  double qiblahOffset = getQiblaDirection(latitude, longitude, direction);

  return CompassModel(
      turns: direction / 360,
      angle: direction,
      qiblahOffset: qiblahOffset,
      source: source);
}

/// Model to store the sensor value
class CompassModel {
  double turns;
  double angle;
  double qiblahOffset;
  String source;

  CompassModel(
      {required this.turns,
      required this.angle,
      required this.qiblahOffset,
      required this.source});
}

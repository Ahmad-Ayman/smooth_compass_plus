import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smooth_compass_plus/utils/src/compass_ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SmoothCompassWidget(
          forceGPS: true,
          // forceGPS: false,
          loadingAnimation: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              image: DecorationImage(
                  image: AssetImage('assets/images/fullbackground.png'),
                  fit: BoxFit.cover),
            ),
            child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Center(
                  child: CircularProgressIndicator(),
                )),
          ),
          errorLocationServiceWidget: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'خدمة تحديد المواقع غير مفعلة',
              ),
              SizedBox(
                height: 16,
              ),
            ],
          ),
          errorLocationPermissionWidget: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  Platform.isAndroid
                      ? 'من فضلك قم بقبول طلب الوصول لموقعك الحالي لتستطيع '
                          'الوصول لاتجاه القبلة'
                      : 'من فضلك اسمح '
                          'للتطبيق بالوصول لخدمة تحديد الموقع من '
                          'الاعدادات الخاصة بجهازك',
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: 16,
                ),
              ],
            ),
          ),
          rotationSpeed: 200,
          height: 500,
          isQiblahCompass: true,
          width: 500,
          compassBuilder: (BuildContext context,
              AsyncSnapshot<CompassModel>? compassData, Widget compassAsset) {
            if (compassData?.data == null) {
              return Center(
                child: Text('Error: Unable to get compass data'),
              );
            }
            return SizedBox(
              height: 450,
              width: 450,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: compassData!.data!.qiblahOffset.toInt() ==
                                  compassData.data!.angle.toInt()
                              ? Image.asset('assets/images/kaabafixed.png')
                              : Image.asset('assets/images/qiblahright.png'),
                        ),
                        //put your qiblah needle here
                        Positioned(
                          top: 20,
                          left: 0,
                          right: 0,
                          bottom: 20,
                          child: AnimatedRotation(
                            turns: compassData.data?.turns ?? 0,
                            duration: const Duration(milliseconds: 400),
                            child: Stack(
                              children: <Widget>[
                                Positioned(
                                  top: 20,
                                  bottom: 20,
                                  left: 0,
                                  right: 0,
                                  child: AnimatedRotation(
                                      turns: (compassData.data!.qiblahOffset ??
                                              0) /
                                          360,
                                      duration:
                                          const Duration(milliseconds: 400),
                                      child: Image.asset(
                                          'assets/images/neeedle.png')),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 80),
                    child: Text(
                      compassData.data!.qiblahOffset.toInt() ==
                              compassData.data!.angle.toInt()
                          ? '''أنت الآن في إتجاه القِبلة..
ليتقبل الله منك'''
                          : ''' قم بتدوير الهاتف حتى تصبح الكعبة في المنتصف''',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

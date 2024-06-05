import 'package:flutter/material.dart';

class CustomErrorWidget extends StatelessWidget {
  final Function() onTap;
  final String errMsg;
  final String title;

  const CustomErrorWidget(
      {Key? key,
        required this.onTap,
        required this.title,
        required this.errMsg})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.20,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  textAlign: TextAlign.center,
                  errMsg,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Expanded(
              child: Center(
                child: MaterialButton(
                  color: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  onPressed: onTap,
                  child: Text(title),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

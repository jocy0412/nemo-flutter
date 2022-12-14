import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../secrets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:blinking_text/blinking_text.dart';

class InitPage extends StatefulWidget {
  const InitPage({Key? key}) : super(key: key);

  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  static final storage = FlutterSecureStorage();
  dynamic userInfo = '';

  checkUserState() async {
    if (await isLogined() == false) {
      Navigator.pushNamed(context, '/login');
    } else if (await findCard(userInfo['user_id']) == false) {
      Navigator.pushNamed(context, '/namecard');
    } else {
      Navigator.pushNamed(context, '/sharing');
    }
  }

  emergency() async {
    Navigator.pushNamed(context, '/login');
  }

  isLogined() async {
    print('isLogined start');
    userInfo = await storage.read(key: 'login');
    if (userInfo == null) {
      return false;
    } else {
      userInfo = jsonDecode(userInfo);
      print(userInfo['user_id']);
      return true;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   checkUserState();
    // });
  }

  findCard(id) async {
    print('findCard start');

    try {
      var dio = Dio();
      Response response = await dio.get('${API_URL}card/$id');
      if (response.data.runtimeType != bool) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: GestureDetector(
        onTap: () {
          checkUserState();
        },
        onDoubleTap: () {
          emergency();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/common/logo.png',
              alignment: Alignment.center,
              height: 400,
            ),
            BlinkText(
              'NeMo ??? ???????????????! ',
              // beginColor: Colors.black,
              // endColor: Color(0xff8338EC),
              duration: Duration(milliseconds: 800),
              times: 20,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                  color: Color(0xff8338EC)),
            ),
          ],
        ),
      ),
    ));
  }
}

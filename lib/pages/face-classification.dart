import 'dart:async';
import 'package:face_net_authentication/locator.dart';
import 'package:face_net_authentication/pages/models/user.model.dart';
import 'package:face_net_authentication/pages/widgets/auth_button.dart';
import 'package:face_net_authentication/pages/widgets/camera_detection_preview.dart';
import 'package:face_net_authentication/pages/widgets/camera_header.dart';
import 'package:face_net_authentication/pages/widgets/signin_form.dart';
import 'package:face_net_authentication/pages/widgets/single_picture.dart';
import 'package:face_net_authentication/services/camera.service.dart';
import 'package:face_net_authentication/services/ml_service.dart';
import 'package:face_net_authentication/services/face_detector_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class FaceClassification extends StatefulWidget {
  const FaceClassification({Key key}) : super(key: key);

  @override
  FaceClassificationState createState() => FaceClassificationState();
}

class FaceClassificationState extends State<FaceClassification> {
  CameraService _cameraService = locator<CameraService>();
  FaceDetectorService _faceDetectorService = locator<FaceDetectorService>();

  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isInitializing = false;
  bool _isPictureTaken = false;
  String smileyProb = "";
  String eulerY = "";
  String eulerZ = "";

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _faceDetectorService.dispose();
    super.dispose();
  }

  Future _start() async {
    setState(() => _isInitializing = true);
    await _cameraService.initialize();
    setState(() => _isInitializing = false);
    _frameFaces();
  }

  _frameFaces() async {
    bool processing = false;
    _cameraService.cameraController.startImageStream((CameraImage image) async {
      if (processing) return; // prevents unnecessary overprocessing.
      processing = true;
      await _predictFacesFromImage(image: image);
      processing = false;
    });
  }

  Future<void> _predictFacesFromImage({@required CameraImage image}) async {
    List<Face> faces = await _faceDetectorService.getFacesFromImage(image, context);
    if (faces != null && faces.length > 0) {
      Face face = faces[0];
      if (faces[0].smilingProbability != null) {
        final double smileProb = face.smilingProbability;
        setState(() {
          smileyProb = smileProb.toString();
          eulerY = face.headEulerAngleY.toString();
          eulerZ = face.headEulerAngleZ.toString();
        });
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> takePicture() async {
    if (_faceDetectorService.faceDetected) {
      await _cameraService.takePicture();
      setState(() => _isPictureTaken = true);
    } else {
      showDialog(context: context, builder: (context) => AlertDialog(content: Text('No face detected!')));
    }
  }

  _onBackPressed() {
    Navigator.of(context).pop();
  }

  _reload() {
    if (mounted) setState(() => _isPictureTaken = false);
    _start();
  }

  Future<void> onTap() async {
    // await takePicture();
    // if (_faceDetectorService.faceDetected) {
    //   User user = await _mlService.predict(context);
    //   var bottomSheetController = scaffoldKey.currentState.showBottomSheet((context) => signInSheet(user: user));
    //   bottomSheetController.closed.whenComplete(_reload);
    // }
  }

  Widget getBodyWidget() {
    if (_isInitializing) return Center(child: CircularProgressIndicator());
    if (_isPictureTaken) return SinglePicture(imagePath: _cameraService.imagePath);
    return CameraDetectionPreview();
  }

  @override
  Widget build(BuildContext context) {
    Widget header = CameraHeader("LOGIN", onBackPressed: _onBackPressed);
    Widget body = getBodyWidget();
    Widget fab;
    if (!_isPictureTaken) fab = AuthButton(onTap: onTap);

    return Scaffold(
      key: scaffoldKey,
      body: Stack(
        children: [
          body,
          header,
          Column(
            children: [
              Expanded(child: Container()),
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(20.0),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(smileyProb), Text(eulerY), Text(eulerZ)]),
              )
            ],
          )
          // Align(
          //     alignment: Alignment.bottomCenter,
          //     child: Container(
          //       color: Colors.white,
          //       padding: EdgeInsets.all(20.0),
          //       child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(smileyProb)]),
          //     ))
        ],
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // floatingActionButton: fab,
    );
  }

  signInSheet({@required User user}) => user == null
      ? Container(
          width: MediaQuery.of(context).size.width,
          padding: EdgeInsets.all(20),
          child: Text(
            'User not found 😞',
            style: TextStyle(fontSize: 20),
          ),
        )
      : SignInSheet(user: user);
}

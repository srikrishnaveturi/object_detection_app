import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: TfLiteHome(),
      )
  );
}

const String ssd = 'SSD MobileNet';
const String yolo = 'Tiny YOLOv2';

class TfLiteHome extends StatefulWidget {
  @override
  _TfLiteHomeState createState() => _TfLiteHomeState();
}

class _TfLiteHomeState extends State<TfLiteHome> {
  String model = yolo;
  File _image;

  double imageWidth;
  double imageHeight;

  bool busy = false;

  List _recognitions;

  @override
  void initState() {
    super.initState();
    busy = true;
    loadModel().then((val) {
      setState(() {
        busy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      if (model == yolo) {
        res = await Tflite.loadModel(
            model: 'assets/tflite/yolov2_tiny.tflite',
            labels: 'assets/tflite/yolov2_tiny.txt'
        );
      }
      else {
        String res;
        if (model == ssd) {
          res = await Tflite.loadModel(
              model: 'assets/tflite/ssd_mobilenet.tflite',
              labels: 'assets/tflite/ssd_mobilenet.txt'
          );
        }
      }
    }on PlatformException {
      print('Failed to load model');
    }
  }

  predictImage(image) async{
    if(image==null)return;

    if(model == yolo){
      await yolov2Tiny(image);
    }
    else{
      await ssdMobileNet(image);
    }

    FileImage(image)
        .resolve(ImageConfiguration())
        .addListener((ImageStreamListener((ImageInfo info, bool _) {
      setState(() {
        imageWidth = info.image.width.toDouble();
        imageHeight = info.image.height.toDouble();
      });
    })));

    setState(() {
      _image = image;
      busy = false;
    });
  }

  selectFromImagePicker() async{
    final picker = ImagePicker();
    var image = await picker.getImage(source: ImageSource.camera);
    if(image == null)return;
    setState(() {
      busy = true;
    });
    //using "image" which is "picked file" and making it into "file" in "_image"
    File _image = File(image.path);
    predictImage(_image);
  }



  yolov2Tiny(image) async{
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      model: 'YOLO',
      threshold: 0.3,
      imageMean: 0.0,
      imageStd: 255.0,
      numResultsPerClass: 1,
    );
    setState(() {
      _recognitions = recognitions;
    });
  }

  ssdMobileNet(image) async{
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1,
    );
    setState(() {
      _recognitions = recognitions;
    });
  }

  List<Widget> renderBoxes(Size screen){
    if(_recognitions == null)return [];
    if(imageHeight == null || imageWidth == null)return [];

    double factorX = screen.width;
    double factorY = imageHeight/imageWidth*screen.width;
    
    Color blue = Colors.blue;

    return _recognitions.map((re) {
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
                color: blue,
                width: 3,
              )),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = blue,
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    
    Size size = MediaQuery.of(context).size;

    List<Widget> stackChildren = [];
    
    stackChildren.add(Positioned(
      top: 10.0,
      left: 0.0,
      width: size.width,
      child: _image==null ? Center(child: Text('No Image Selected')) : Image.file(_image),
    ));

    stackChildren.addAll(renderBoxes(size));

    if(busy == true){
      stackChildren.add(Center(
        child: CircularProgressIndicator(),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('TfLite demo'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.image),
        tooltip: 'pick image from gallery',
        onPressed: selectFromImagePicker,
      ),
      body: Stack(
        children: stackChildren,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

// Add Firebase core
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
   WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FloodReporterApp());
}

class FloodReporterApp extends StatelessWidget {
  const FloodReporterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flood Reporter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  Position? _currentPosition;

  final picker = ImagePicker();

  Future getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      getCurrentLocation();
    } else {
      print('No image selected.');
    }
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return;
    }

    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
    });

    print('Location: ${position.latitude}, ${position.longitude}');
  }

  Future<void> uploadReport() async {
  if (_image == null || _currentPosition == null) {
    print('No image or location.');
    return;
  }

  String fileName = DateTime.now().millisecondsSinceEpoch.toString();
  Reference storageRef = FirebaseStorage.instance.ref().child('reports/$fileName.jpg');

  UploadTask uploadTask = storageRef.putFile(_image!);
  TaskSnapshot taskSnapshot = await uploadTask;

  String downloadUrl = await taskSnapshot.ref.getDownloadURL();

  await FirebaseFirestore.instance.collection('reports').add({
    'image_url': downloadUrl,
    'latitude': _currentPosition!.latitude,
    'longitude': _currentPosition!.longitude,
    'timestamp': FieldValue.serverTimestamp(),
  });

  print('Upload complete.');
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Flood Reporter'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _image == null
                  ? const Text('No image selected.')
                  : Image.file(_image!),
              const SizedBox(height: 20),
              _currentPosition == null
                  ? const Text('Location not available.')
                  : Text(
                      'Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: getImage,
                child: const Text('Take Photo & Get Location'),
              ),
              ElevatedButton(
                onPressed: uploadReport,
                child: const Text('Upload Report'),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

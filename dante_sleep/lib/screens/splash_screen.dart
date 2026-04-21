import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder for logo: baby on moon with stars
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.nightlight_round,
                  size: 100,
                  color: Colors.black,
                ),
                const Positioned(
                  top: 10,
                  child: Icon(Icons.star, size: 20, color: Colors.black),
                ),
                const Positioned(
                  bottom: 10,
                  left: 20,
                  child: Icon(Icons.star, size: 15, color: Colors.black),
                ),
                const Positioned(
                  bottom: 10,
                  right: 20,
                  child: Icon(Icons.star, size: 15, color: Colors.black),
                ),
                const Positioned(
                  top: 30,
                  right: 10,
                  child: Icon(Icons.child_care, size: 30, color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Dante Sleep',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

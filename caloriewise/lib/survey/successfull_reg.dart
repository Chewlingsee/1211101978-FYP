import 'package:caloriewise/main_component/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caloriewise/login_register/login_screen.dart';
import 'package:caloriewise/survey/diet/component/bg_color.dart';

class SuccessfullReg extends StatelessWidget {
  const SuccessfullReg({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SurveyBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/successful.png', width: 400),
                SizedBox(height: 10),
                Text(
                  'Congratulations! \nYour account has been successfully registered.',
                  style: GoogleFonts.lato(
                    color: kPrimaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 88, 83, 193),
                      foregroundColor: const Color.fromARGB(255, 208, 251, 254),
                      textStyle: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: const Text("Back to Login Page"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

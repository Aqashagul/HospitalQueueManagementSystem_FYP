import 'package:flutter/material.dart';

class BgBoxes extends StatelessWidget {
  const BgBoxes({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xffC8B2FF).withValues(alpha: .45),
             // color: const Color(0xFF5FA6A8).withValues(alpha: .45),

            ),
          ),
        ),

        

       
        Positioned(
            top: 270,
            left: -130,
            child: Container(
              width: 250,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xffE8DDFF).withValues(alpha: .80),
                //color: const Color(0xFF5FA6A8).withValues(alpha: .49),
              ),
            ),),



      ],
    );
  }
}
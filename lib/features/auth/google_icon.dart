import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The real, official multicolor Google "G" mark - fixed brand colors
/// that never change with theme/dark-mode, per Google's own branding
/// guidelines. Previously this was a generic Material icon rendered
/// in the school's theme color, which is not the Google mark at all.
class GoogleIcon extends StatelessWidget {
  final double size;
  const GoogleIcon({super.key, this.size = 20});

  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18">
<path fill="#4285F4" d="M17.64 9.2045c0-.6381-.0573-1.2518-.1636-1.8409H9v3.4814h4.8436c-.2086 1.125-.8427 2.0782-1.7959 2.7164v2.2582h2.9087c1.7018-1.5668 2.6836-3.8741 2.6836-6.6151z"/>
<path fill="#34A853" d="M9 18c2.43 0 4.4673-.8059 5.9564-2.1805l-2.9087-2.2582c-.8059.54-1.8368.8591-3.0477.8591-2.344 0-4.3282-1.5831-5.0359-3.7104H.9573v2.3318C2.4382 15.9832 5.4818 18 9 18z"/>
<path fill="#FBBC05" d="M3.9641 10.71c-.18-.54-.2822-1.1168-.2822-1.71s.1023-1.17.2822-1.71V4.9582H.9573C.3477 6.1732 0 7.5477 0 9s.3477 2.8268.9573 4.0418L3.9641 10.71z"/>
<path fill="#EA4335" d="M9 3.5795c1.3214 0 2.5077.4541 3.4405 1.346l2.5814-2.5814C13.4632.8918 11.4259 0 9 0 5.4818 0 2.4382 2.0168.9573 4.9582L3.9641 7.29C4.6718 5.1627 6.656 3.5795 9 3.5795z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_svg, width: size, height: size);
  }
}

/// Google's own button guidelines: white background, grey border,
/// grey/black text, the real logo - deliberately NOT themed with the
/// school's colors, since Google's brand mark is fixed regardless of
/// context.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const GoogleSignInButton({super.key, required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          side: const BorderSide(color: Color(0xFFDADCE0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GoogleIcon(size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
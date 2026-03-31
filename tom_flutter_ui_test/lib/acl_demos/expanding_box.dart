part of 'acl_demos.dart';

class ExpandingBox extends StatelessWidget {
  final String label;
  final Color color;
  final double? width;

  const ExpandingBox(this.label, this.color, {super.key, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        border: Border.all(color: color),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: color.shade900),
        ),
      ),
    );
  }
}


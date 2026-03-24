/// Comprehensive Visual Effects Demo
///
/// This demo showcases BackdropFilter, ShaderMask, ClipPath,
/// opacity effects, shadows, gradients, and decorations.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'dart:ui';
import 'dart:math' as math;

/// Main effects demo screen.
class EffectsDemo extends StatelessWidget {
  const EffectsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'BackdropFilter',
          subtitle: 'Blur and filter effects',
        ),
        _BackdropFilterSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'ShaderMask',
          subtitle: 'Gradient masking effects',
        ),
        _ShaderMaskSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'ClipPath',
          subtitle: 'Custom clipping shapes',
        ),
        _ClipPathSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Opacity & Blend',
          subtitle: 'Opacity and color blend modes',
        ),
        _OpacitySection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Shadows & Elevation',
          subtitle: 'Shadow effects',
        ),
        _ShadowSection(),
        SizedBox(height: 48),
      ],
    );
  }
}

// =============================================================================
// Section Header
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// BackdropFilter Section
// =============================================================================

class _BackdropFilterSection extends StatelessWidget {
  const _BackdropFilterSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Blur Effect',
          'Gaussian blur over background.',
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.blue, Colors.teal],
                  ),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                  ),
                  itemCount: 25,
                  itemBuilder: (context, index) => Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'Frosted Glass',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Blur Levels',
          'Different blur intensities.',
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://picsum.photos/400/200',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Row(
              children: [
                _blurSection('None', 0),
                _blurSection('Light', 3),
                _blurSection('Medium', 6),
                _blurSection('Heavy', 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _blurSection(String label, double sigma) {
    return Expanded(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            color: Colors.black.withValues(alpha: 0.1),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ShaderMask Section
// =============================================================================

class _ShaderMaskSection extends StatelessWidget {
  const _ShaderMaskSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Gradient Text',
          'Text with gradient fill.',
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.purple, Colors.blue, Colors.cyan],
            ).createShader(bounds),
            child: const Text(
              'Gradient Text',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Gradient Icon',
          'Icon with gradient fill.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.red, Colors.orange],
                ).createShader(bounds),
                child: const Icon(Icons.favorite, size: 48, color: Colors.white),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.green, Colors.teal],
                ).createShader(bounds),
                child: const Icon(Icons.eco, size: 48, color: Colors.white),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                ).createShader(bounds),
                child: const Icon(Icons.water_drop, size: 48, color: Colors.white),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Fade Effect',
          'Gradient fade at edges.',
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: const [0.0, 0.1, 0.9, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                ),
              ),
              child: const Center(
                child: Text(
                  'Faded Edges',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ClipPath Section
// =============================================================================

class _ClipPathSection extends StatelessWidget {
  const _ClipPathSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Wave Clip',
          'Wavy bottom edge.',
          ClipPath(
            clipper: _WaveClipper(),
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                ),
              ),
              child: const Center(
                child: Text(
                  'Wave',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Triangle Clip',
          'Triangular corners.',
          ClipPath(
            clipper: _TriangleClipper(),
            child: Container(
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.red],
                ),
              ),
              child: const Center(
                child: Text(
                  'Triangle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Shapes',
          'Various clipping shapes.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ClipOval(
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.teal,
                  child: const Center(
                    child: Text('Oval', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.purple,
                  child: const Center(
                    child: Text('Round', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
              ClipPath(
                clipper: _HexagonClipper(),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.indigo,
                  child: const Center(
                    child: Text('Hex', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 20);
    for (var i = 0.0; i < size.width; i++) {
      path.lineTo(i, size.height - 20 + math.sin(i / 20) * 10);
    }
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 20)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height - 20)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.25, 0);
    path.lineTo(w * 0.75, 0);
    path.lineTo(w, h * 0.5);
    path.lineTo(w * 0.75, h);
    path.lineTo(w * 0.25, h);
    path.lineTo(0, h * 0.5);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// =============================================================================
// Opacity Section
// =============================================================================

class _OpacitySection extends StatelessWidget {
  const _OpacitySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Opacity Levels',
          'Different opacity values.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _opacityBox(1.0),
              _opacityBox(0.75),
              _opacityBox(0.5),
              _opacityBox(0.25),
            ],
          ),
        ),
        _buildDemoCard(
          'Color Blend Modes',
          'Different blend effects.',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _blendBox('Normal', BlendMode.srcOver),
              _blendBox('Multiply', BlendMode.multiply),
              _blendBox('Screen', BlendMode.screen),
              _blendBox('Overlay', BlendMode.overlay),
              _blendBox('Darken', BlendMode.darken),
              _blendBox('Lighten', BlendMode.lighten),
            ],
          ),
        ),
      ],
    );
  }

  Widget _opacityBox(double opacity) {
    return Column(
      children: [
        Opacity(
          opacity: opacity,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('${(opacity * 100).toInt()}%'),
      ],
    );
  }

  Widget _blendBox(String label, BlendMode mode) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.red, Colors.blue],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.yellow, mode),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shadow Section
// =============================================================================

class _ShadowSection extends StatelessWidget {
  const _ShadowSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Elevation Levels',
          'Material elevation shadows.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _elevationCard(0),
              _elevationCard(2),
              _elevationCard(4),
              _elevationCard(8),
            ],
          ),
        ),
        _buildDemoCard(
          'Box Shadows',
          'Custom shadow decorations.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _shadowBox(
                'Soft',
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              _shadowBox(
                'Hard',
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              _shadowBox(
                'Color',
                [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Multi Shadow',
          'Multiple layered shadows.',
          Container(
            width: 120,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(-10, 10),
                ),
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(10, 10),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Multi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _elevationCard(double elevation) {
    return Column(
      children: [
        Material(
          elevation: elevation,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${elevation.toInt()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('E${elevation.toInt()}'),
      ],
    );
  }

  Widget _shadowBox(String label, List<BoxShadow> shadows) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: shadows,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

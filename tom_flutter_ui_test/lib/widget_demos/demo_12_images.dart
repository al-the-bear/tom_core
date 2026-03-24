/// Comprehensive Images and Media Demo
///
/// This demo showcases Image, Icon, CircleAvatar, FadeInImage,
/// decorations, and various image loading patterns.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main images demo screen.
class ImagesDemo extends StatelessWidget {
  const ImagesDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Icons',
          subtitle: 'Material icons and icon buttons',
        ),
        _IconSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'CircleAvatar',
          subtitle: 'Circular profile images and initials',
        ),
        _AvatarSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Image Containers',
          subtitle: 'Decorated containers as image placeholders',
        ),
        _ImageContainerSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Image Decorations',
          subtitle: 'Gradients, borders, and effects',
        ),
        _ImageDecorationSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Image Gallery',
          subtitle: 'Grid and list layouts',
        ),
        _ImageGallerySection(),
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
// Icon Section
// =============================================================================

class _IconSection extends StatelessWidget {
  const _IconSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Icon Sizes',
          'Different icon sizes.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Icon(Icons.star, size: 16),
                  SizedBox(height: 4),
                  Text('16', style: TextStyle(fontSize: 10)),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.star, size: 24),
                  SizedBox(height: 4),
                  Text('24', style: TextStyle(fontSize: 10)),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.star, size: 32),
                  SizedBox(height: 4),
                  Text('32', style: TextStyle(fontSize: 10)),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.star, size: 48),
                  SizedBox(height: 4),
                  Text('48', style: TextStyle(fontSize: 10)),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.star, size: 64),
                  SizedBox(height: 4),
                  Text('64', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Icon Colors',
          'Icons with different colors.',
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              Icon(Icons.favorite, color: Colors.red),
              Icon(Icons.thumb_up, color: Colors.blue),
              Icon(Icons.check_circle, color: Colors.green),
              Icon(Icons.warning, color: Colors.orange),
              Icon(Icons.info, color: Colors.cyan),
              Icon(Icons.star, color: Colors.amber),
              Icon(Icons.mood, color: Colors.purple),
              Icon(Icons.eco, color: Colors.teal),
            ],
          ),
        ),
        _buildDemoCard(
          'Icon Styles',
          'Filled, outlined, rounded, sharp.',
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _iconWithLabel(Icons.home, 'filled'),
              _iconWithLabel(Icons.home_outlined, 'outlined'),
              _iconWithLabel(Icons.home_rounded, 'rounded'),
              _iconWithLabel(Icons.home_sharp, 'sharp'),
            ],
          ),
        ),
        _buildDemoCard(
          'Icon Buttons',
          'Different icon button styles.',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.favorite_border),
              ),
              IconButton.filled(
                onPressed: () {},
                icon: const Icon(Icons.add),
              ),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.edit),
              ),
              IconButton.outlined(
                onPressed: () {},
                icon: const Icon(Icons.share),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconWithLabel(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 32),
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Avatar Section
// =============================================================================

class _AvatarSection extends StatelessWidget {
  const _AvatarSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Avatar Sizes',
          'Different radius values.',
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircleAvatar(radius: 16, child: Text('S')),
              CircleAvatar(radius: 24, child: Text('M')),
              CircleAvatar(radius: 32, child: Text('L')),
              CircleAvatar(radius: 40, child: Text('XL')),
            ],
          ),
        ),
        _buildDemoCard(
          'Avatar with Initials',
          'Colored backgrounds with text.',
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              CircleAvatar(
                backgroundColor: Colors.red.shade200,
                child: const Text('JD', style: TextStyle(color: Colors.red)),
              ),
              CircleAvatar(
                backgroundColor: Colors.blue.shade200,
                child: const Text('AB', style: TextStyle(color: Colors.blue)),
              ),
              CircleAvatar(
                backgroundColor: Colors.green.shade200,
                child: const Text('XY', style: TextStyle(color: Colors.green)),
              ),
              CircleAvatar(
                backgroundColor: Colors.purple.shade200,
                child: const Text('MN', style: TextStyle(color: Colors.purple)),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Avatar with Icons',
          'Icons inside avatars.',
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
              CircleAvatar(
                backgroundColor: Colors.blue.shade700,
                child: const Icon(Icons.work, color: Colors.white),
              ),
              CircleAvatar(
                backgroundColor: Colors.green.shade700,
                child: const Icon(Icons.check, color: Colors.white),
              ),
              CircleAvatar(
                backgroundColor: Colors.orange.shade700,
                child: const Icon(Icons.star, color: Colors.white),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Avatar Groups',
          'Overlapping avatar stack.',
          SizedBox(
            height: 56,
            child: Stack(
              children: [
                for (int i = 0; i < 5; i++)
                  Positioned(
                    left: i * 36.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            Colors.primaries[i % Colors.primaries.length],
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 5 * 36.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade300,
                      child: const Text('+3'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Avatar with Badge',
          'Status indicators on avatars.',
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _avatarWithBadge(Colors.green, 'Online'),
              _avatarWithBadge(Colors.orange, 'Away'),
              _avatarWithBadge(Colors.red, 'Busy'),
              _avatarWithBadge(Colors.grey, 'Offline'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarWithBadge(Color badgeColor, String label) {
    return Column(
      children: [
        Stack(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Image Container Section
// =============================================================================

class _ImageContainerSection extends StatelessWidget {
  const _ImageContainerSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Placeholder Containers',
          'Colored containers representing images.',
          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.image, size: 32, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade300, Colors.purple.shade300],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.photo, size: 32, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.landscape,
                        size: 32,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Aspect Ratios',
          'Common image aspect ratios.',
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(child: Text('1:1')),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Square', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(child: Text('4:3')),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Photo', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(child: Text('16:9')),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Video', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'BoxFit Simulation',
          'How images would fit in containers.',
          Column(
            children: [
              Row(
                children: [
                  _boxFitDemo('fill', Colors.red),
                  const SizedBox(width: 8),
                  _boxFitDemo('contain', Colors.blue),
                  const SizedBox(width: 8),
                  _boxFitDemo('cover', Colors.green),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _boxFitDemo('fitWidth', Colors.orange),
                  const SizedBox(width: 8),
                  _boxFitDemo('fitHeight', Colors.purple),
                  const SizedBox(width: 8),
                  _boxFitDemo('scaleDown', Colors.teal),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _boxFitDemo(String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color),
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 30,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9)),
        ],
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Image Decoration Section
// =============================================================================

class _ImageDecorationSection extends StatelessWidget {
  const _ImageDecorationSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Border Radius',
          'Different corner radius values.',
          Row(
            children: [
              _radiusDemo(0, 'none'),
              const SizedBox(width: 8),
              _radiusDemo(8, '8'),
              const SizedBox(width: 8),
              _radiusDemo(16, '16'),
              const SizedBox(width: 8),
              _radiusDemo(999, 'circle'),
            ],
          ),
        ),
        _buildDemoCard(
          'Shadows',
          'Box shadows and elevation.',
          Row(
            children: [
              _shadowDemo(2, 'sm'),
              const SizedBox(width: 16),
              _shadowDemo(4, 'md'),
              const SizedBox(width: 16),
              _shadowDemo(8, 'lg'),
              const SizedBox(width: 16),
              _shadowDemo(16, 'xl'),
            ],
          ),
        ),
        _buildDemoCard(
          'Borders',
          'Different border styles.',
          Row(
            children: [
              _borderDemo(BorderSide(color: Colors.grey.shade400, width: 1), 'thin'),
              const SizedBox(width: 8),
              _borderDemo(const BorderSide(color: Colors.blue, width: 2), 'medium'),
              const SizedBox(width: 8),
              _borderDemo(const BorderSide(color: Colors.green, width: 4), 'thick'),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple, width: 2),
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.withValues(alpha: 0.1),
                            Colors.blue.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('gradient', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Gradient Overlays',
          'Text overlay gradients.',
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 8,
                        left: 8,
                        child: Text(
                          'Bottom gradient',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.black54,
                              Colors.transparent,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: Text(
                          'Left gradient',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _radiusDemo(double radius, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.shade300,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _shadowDemo(double blur, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: blur,
                  offset: Offset(0, blur / 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _borderDemo(BorderSide side, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.fromBorderSide(side),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Image Gallery Section
// =============================================================================

class _ImageGallerySection extends StatelessWidget {
  const _ImageGallerySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Grid Gallery',
          'Image grid with 3 columns.',
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.primaries[index % Colors.primaries.length].shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Icon(
                    Icons.image,
                    color: Colors.primaries[index % Colors.primaries.length],
                  ),
                ),
              );
            },
          ),
        ),
        _buildDemoCard(
          'Masonry Layout',
          'Variable height items.',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _masonryItem(100, Colors.red),
                    const SizedBox(height: 4),
                    _masonryItem(140, Colors.orange),
                    const SizedBox(height: 4),
                    _masonryItem(80, Colors.yellow),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  children: [
                    _masonryItem(140, Colors.green),
                    const SizedBox(height: 4),
                    _masonryItem(100, Colors.blue),
                    const SizedBox(height: 4),
                    _masonryItem(80, Colors.purple),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  children: [
                    _masonryItem(80, Colors.pink),
                    const SizedBox(height: 4),
                    _masonryItem(120, Colors.teal),
                    const SizedBox(height: 4),
                    _masonryItem(120, Colors.indigo),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Card Gallery',
          'Image cards with captions.',
          Column(
            children: List.generate(3, (index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.primaries[index * 3],
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.photo, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Photo ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Description text here',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _masonryItem(double height, Color color) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(Icons.photo, color: color),
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

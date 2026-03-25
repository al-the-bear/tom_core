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
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Icons',
          subtitle: 'Material icons and icon buttons',
        ),
        _IconSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'CircleAvatar',
          subtitle: 'Circular profile images and initials',
        ),
        _AvatarSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Image Containers',
          subtitle: 'Decorated containers as image placeholders',
        ),
        _ImageContainerSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Image Decorations',
          subtitle: 'Gradients, borders, and effects',
        ),
        _ImageDecorationSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Image Gallery',
          subtitle: 'Grid and list layouts',
        ),
        _ImageGallerySection(),
        TomSizedBox(height: 48),
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
    return TomPadding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const TomSizedBox(height: 4),
          TomText(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const TomSizedBox(height: 8),
          TomContainer(
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Icon Sizes',
          'Different icon sizes.',
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TomColumn(
                children: [
                  TomIcon(Icons.star, size: 16),
                  TomSizedBox(height: 4),
                  TomText(null, tomId: 'demo.12.auto.text.1', style: TextStyle(fontSize: 10)),
                ],
              ),
              TomColumn(
                children: [
                  TomIcon(Icons.star, size: 24),
                  TomSizedBox(height: 4),
                  TomText(null, tomId: 'demo.12.auto.text.2', style: TextStyle(fontSize: 10)),
                ],
              ),
              TomColumn(
                children: [
                  TomIcon(Icons.star, size: 32),
                  TomSizedBox(height: 4),
                  TomText(null, tomId: 'demo.12.auto.text.3', style: TextStyle(fontSize: 10)),
                ],
              ),
              TomColumn(
                children: [
                  TomIcon(Icons.star, size: 48),
                  TomSizedBox(height: 4),
                  TomText(null, tomId: 'demo.12.auto.text.4', style: TextStyle(fontSize: 10)),
                ],
              ),
              TomColumn(
                children: [
                  TomIcon(Icons.star, size: 64),
                  TomSizedBox(height: 4),
                  TomText(null, tomId: 'demo.12.auto.text.5', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Icon Colors',
          'Icons with different colors.',
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              TomIcon(Icons.favorite, color: Colors.red),
              TomIcon(Icons.thumb_up, color: Colors.blue),
              TomIcon(Icons.check_circle, color: Colors.green),
              TomIcon(Icons.warning, color: Colors.orange),
              TomIcon(Icons.info, color: Colors.cyan),
              TomIcon(Icons.star, color: Colors.amber),
              TomIcon(Icons.mood, color: Colors.purple),
              TomIcon(Icons.eco, color: Colors.teal),
            ],
          ),
        ),
        _buildDemoCard(
          'Icon Styles',
          'Filled, outlined, rounded, sharp.',
          TomWrap(
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
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomIconButton(
                onPressed: () {},
                icon: const TomIcon(Icons.favorite_border),
              ),
              IconButton.filled(
                onPressed: () {},
                icon: const TomIcon(Icons.add),
              ),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const TomIcon(Icons.edit),
              ),
              IconButton.outlined(
                onPressed: () {},
                icon: const TomIcon(Icons.share),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconWithLabel(IconData icon, String label) {
    return TomColumn(
      children: [
        TomIcon(icon, size: 32),
        const TomSizedBox(height: 4),
        TomText(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Avatar Sizes',
          'Different radius values.',
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TomCircleAvatar(radius: 16, child: TomText(null, tomId: 'demo.12.auto.text.1')),
              TomCircleAvatar(radius: 24, child: TomText(null, tomId: 'demo.12.auto.text.2')),
              TomCircleAvatar(radius: 32, child: TomText(null, tomId: 'demo.12.auto.text.3')),
              TomCircleAvatar(radius: 40, child: TomText(null, tomId: 'demo.12.auto.text.4')),
            ],
          ),
        ),
        _buildDemoCard(
          'Avatar with Initials',
          'Colored backgrounds with text.',
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomCircleAvatar(
                backgroundColor: Colors.red.shade200,
                child: const TomText(null, tomId: 'demo.12.auto.text.6', style: TextStyle(color: Colors.red)),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.blue.shade200,
                child: const TomText(null, tomId: 'demo.12.auto.text.7', style: TextStyle(color: Colors.blue)),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.green.shade200,
                child: const TomText(null, tomId: 'demo.12.auto.text.8', style: TextStyle(color: Colors.green)),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.purple.shade200,
                child: const TomText(null, tomId: 'demo.12.auto.text.9', style: TextStyle(color: Colors.purple)),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Avatar with Icons',
          'Icons inside avatars.',
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              const TomCircleAvatar(
                backgroundColor: Colors.grey,
                child: TomIcon(Icons.person, color: Colors.white),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.blue.shade700,
                child: const TomIcon(Icons.work, color: Colors.white),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.green.shade700,
                child: const TomIcon(Icons.check, color: Colors.white),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.orange.shade700,
                child: const TomIcon(Icons.star, color: Colors.white),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Avatar Groups',
          'Overlapping avatar stack.',
          TomSizedBox(
            height: 56,
            child: TomStack(
              children: [
                for (int i = 0; i < 5; i++)
                  TomPositioned(
                    left: i * 36.0,
                    child: TomContainer(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: TomCircleAvatar(
                        radius: 24,
                        backgroundColor:
                            Colors.primaries[i % Colors.primaries.length],
                        child: TomText(null, tomId: 'demo.12.auto.text.10',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                TomPositioned(
                  left: 5 * 36.0,
                  child: TomContainer(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: TomCircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade300,
                      child: const TomText(null, tomId: 'demo.12.auto.text.5'),
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
          TomWrap(
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
    return TomColumn(
      children: [
        TomStack(
          children: [
            const TomCircleAvatar(
              radius: 24,
              backgroundColor: Colors.blueGrey,
              child: TomIcon(Icons.person, color: Colors.white),
            ),
            TomPositioned(
              right: 0,
              bottom: 0,
              child: TomContainer(
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
        const TomSizedBox(height: 4),
        TomText(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Placeholder Containers',
          'Colored containers representing images.',
          TomRow(
            children: [
              TomExpanded(
                child: TomAspectRatio(
                  aspectRatio: 1,
                  child: TomContainer(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const TomCenter(
                      child: TomIcon(Icons.image, size: 32, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const TomSizedBox(width: 12),
              TomExpanded(
                child: TomAspectRatio(
                  aspectRatio: 1,
                  child: TomContainer(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade300, Colors.purple.shade300],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const TomCenter(
                      child: TomIcon(Icons.photo, size: 32, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const TomSizedBox(width: 12),
              TomExpanded(
                child: TomAspectRatio(
                  aspectRatio: 1,
                  child: TomContainer(
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: TomCenter(
                      child: TomIcon(
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
          TomColumn(
            children: [
              TomRow(
                children: [
                  TomExpanded(
                    child: TomColumn(
                      children: [
                        TomAspectRatio(
                          aspectRatio: 1,
                          child: TomContainer(
                            decoration: BoxDecoration(
                              color: Colors.red.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const TomCenter(child: TomText(null, tomId: 'demo.12.auto.text.6')),
                          ),
                        ),
                        const TomSizedBox(height: 4),
                        const TomText(null, tomId: 'demo.12.auto.text.11', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  const TomSizedBox(width: 8),
                  TomExpanded(
                    child: TomColumn(
                      children: [
                        TomAspectRatio(
                          aspectRatio: 4 / 3,
                          child: TomContainer(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const TomCenter(child: TomText(null, tomId: 'demo.12.auto.text.7')),
                          ),
                        ),
                        const TomSizedBox(height: 4),
                        const TomText(null, tomId: 'demo.12.auto.text.12', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  const TomSizedBox(width: 8),
                  TomExpanded(
                    child: TomColumn(
                      children: [
                        TomAspectRatio(
                          aspectRatio: 16 / 9,
                          child: TomContainer(
                            decoration: BoxDecoration(
                              color: Colors.green.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const TomCenter(child: TomText(null, tomId: 'demo.12.auto.text.8')),
                          ),
                        ),
                        const TomSizedBox(height: 4),
                        const TomText(null, tomId: 'demo.12.auto.text.13', style: TextStyle(fontSize: 10)),
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
          TomColumn(
            children: [
              TomRow(
                children: [
                  _boxFitDemo('fill', Colors.red),
                  const TomSizedBox(width: 8),
                  _boxFitDemo('contain', Colors.blue),
                  const TomSizedBox(width: 8),
                  _boxFitDemo('cover', Colors.green),
                ],
              ),
              const TomSizedBox(height: 8),
              TomRow(
                children: [
                  _boxFitDemo('fitWidth', Colors.orange),
                  const TomSizedBox(width: 8),
                  _boxFitDemo('fitHeight', Colors.purple),
                  const TomSizedBox(width: 8),
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
    return TomExpanded(
      child: TomColumn(
        children: [
          TomContainer(
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color),
            ),
            child: TomCenter(
              child: TomContainer(
                width: 40,
                height: 30,
                color: color,
              ),
            ),
          ),
          const TomSizedBox(height: 4),
          TomText(label, style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Border Radius',
          'Different corner radius values.',
          TomRow(
            children: [
              _radiusDemo(0, 'none'),
              const TomSizedBox(width: 8),
              _radiusDemo(8, '8'),
              const TomSizedBox(width: 8),
              _radiusDemo(16, '16'),
              const TomSizedBox(width: 8),
              _radiusDemo(999, 'circle'),
            ],
          ),
        ),
        _buildDemoCard(
          'Shadows',
          'Box shadows and elevation.',
          TomRow(
            children: [
              _shadowDemo(2, 'sm'),
              const TomSizedBox(width: 16),
              _shadowDemo(4, 'md'),
              const TomSizedBox(width: 16),
              _shadowDemo(8, 'lg'),
              const TomSizedBox(width: 16),
              _shadowDemo(16, 'xl'),
            ],
          ),
        ),
        _buildDemoCard(
          'Borders',
          'Different border styles.',
          TomRow(
            children: [
              _borderDemo(BorderSide(color: Colors.grey.shade400, width: 1), 'thin'),
              const TomSizedBox(width: 8),
              _borderDemo(const BorderSide(color: Colors.blue, width: 2), 'medium'),
              const TomSizedBox(width: 8),
              _borderDemo(const BorderSide(color: Colors.green, width: 4), 'thick'),
              const TomSizedBox(width: 8),
              TomExpanded(
                child: TomColumn(
                  children: [
                    TomContainer(
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
                    const TomSizedBox(height: 4),
                    const TomText(null, tomId: 'demo.12.auto.text.14', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Gradient Overlays',
          'Text overlay gradients.',
          TomRow(
            children: [
              TomExpanded(
                child: TomContainer(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomStack(
                    children: [
                      TomPositioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: TomContainer(
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
                      const TomPositioned(
                        bottom: 8,
                        left: 8,
                        child: TomText(null, tomId: 'demo.12.auto.text.15',
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
              const TomSizedBox(width: 12),
              TomExpanded(
                child: TomContainer(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomStack(
                    children: [
                      TomContainer(
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
                      const TomPositioned(
                        top: 8,
                        left: 8,
                        child: TomText(null, tomId: 'demo.12.auto.text.16',
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
    return TomExpanded(
      child: TomColumn(
        children: [
          TomContainer(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.shade300,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          const TomSizedBox(height: 4),
          TomText(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _shadowDemo(double blur, String label) {
    return TomExpanded(
      child: TomColumn(
        children: [
          TomContainer(
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
          const TomSizedBox(height: 8),
          TomText(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _borderDemo(BorderSide side, String label) {
    return TomExpanded(
      child: TomColumn(
        children: [
          TomContainer(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.fromBorderSide(side),
            ),
          ),
          const TomSizedBox(height: 4),
          TomText(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
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
    return TomColumn(
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
              return TomContainer(
                decoration: BoxDecoration(
                  color: Colors.primaries[index % Colors.primaries.length].shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TomCenter(
                  child: TomIcon(
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
          TomRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomExpanded(
                child: TomColumn(
                  children: [
                    _masonryItem(100, Colors.red),
                    const TomSizedBox(height: 4),
                    _masonryItem(140, Colors.orange),
                    const TomSizedBox(height: 4),
                    _masonryItem(80, Colors.yellow),
                  ],
                ),
              ),
              const TomSizedBox(width: 4),
              TomExpanded(
                child: TomColumn(
                  children: [
                    _masonryItem(140, Colors.green),
                    const TomSizedBox(height: 4),
                    _masonryItem(100, Colors.blue),
                    const TomSizedBox(height: 4),
                    _masonryItem(80, Colors.purple),
                  ],
                ),
              ),
              const TomSizedBox(width: 4),
              TomExpanded(
                child: TomColumn(
                  children: [
                    _masonryItem(80, Colors.pink),
                    const TomSizedBox(height: 4),
                    _masonryItem(120, Colors.teal),
                    const TomSizedBox(height: 4),
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
          TomColumn(
            children: List.generate(3, (index) {
              return TomCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: TomRow(
                  children: [
                    TomContainer(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.primaries[index * 3],
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                        ),
                      ),
                      child: const TomCenter(
                        child: TomIcon(Icons.photo, color: Colors.white),
                      ),
                    ),
                    const TomSizedBox(width: 12),
                    TomExpanded(
                      child: TomColumn(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TomText(
                            'Photo ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TomText(null, tomId: 'demo.12.auto.text.17',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    TomIconButton(
                      icon: const TomIcon(Icons.more_vert),
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
    return TomContainer(
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TomCenter(
        child: TomIcon(Icons.photo, color: color),
      ),
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

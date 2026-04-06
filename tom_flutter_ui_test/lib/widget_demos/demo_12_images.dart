/// Demo 12: Image & Icon Gallery
///
/// Comprehensive demonstration of all Tom image and icon widgets.
/// Widgets covered: TomIcon, TomImage, TomNetworkImage, TomCircleAvatar,
/// TomFadeInImage, TomAnimatedIcon, TomImageIcon, TomImageFiltered.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Images demo.
class ImagesDemo extends TomStatelessWidget {
  ImagesDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _ImagesDemoContent();

  }
}

class _ImagesDemoContent extends TomStatefulWidget {
  _ImagesDemoContent();

  @override
  State<_ImagesDemoContent> createState() => _ImagesDemoContentState();
}

class _ImagesDemoContentState extends TomState<_ImagesDemoContent>
    with TickerProviderStateMixin {
  // State for AnimatedIcon demos
  late AnimationController _animatedIconController;
  bool _isAnimatedIconPlaying = false;

  // State for image filter demos
  double _blurAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _animatedIconController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animatedIconController.dispose();
    super.dispose();
  }

  void _toggleAnimatedIcon() {
    setState(() {
      if (_isAnimatedIconPlaying) {
        _animatedIconController.reverse();
      } else {
        _animatedIconController.forward();
      }
      _isAnimatedIconPlaying = !_isAnimatedIconPlaying;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Icons
            _SectionHeader(
              tomId: 'section.icons',
            ),
            TomSizedBox(height: 16),
            _buildIconSection(),
            TomSizedBox(height: 32),

            // Section 2: Images
            _SectionHeader(
              tomId: 'section.images',
            ),
            TomSizedBox(height: 16),
            _buildNetworkImageSection(),
            TomSizedBox(height: 32),

            // Section 3: Circle Avatars
            _SectionHeader(
              tomId: 'section.avatars',
            ),
            TomSizedBox(height: 16),
            _buildCircleAvatarSection(),
            TomSizedBox(height: 32),

            // Section 4: FadeIn Images
            _SectionHeader(
              tomId: 'section.fadeIn',
            ),
            TomSizedBox(height: 16),
            _buildFadeInImageSection(),
            TomSizedBox(height: 32),

            // Section 5: Animated Icons & Image Effects
            _SectionHeader(
              tomId: 'section.animated',
            ),
            TomSizedBox(height: 16),
            _buildAnimatedIconSection(),
            TomSizedBox(height: 24),
            _buildImageFilterSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Icons
  // ===========================================================================

  Widget _buildIconSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'icon',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic icons with different sizes
          TomText(
            tomId: 'icon.sizeLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 8),
          TomWrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TomIcon(icon: Icons.home, size: 16),
              TomIcon(icon: Icons.home, size: 24),
              TomIcon(icon: Icons.home, size: 32),
              TomIcon(icon: Icons.home, size: 48),
              TomIcon(icon: Icons.home, size: 64),
            ],
          ),
          TomSizedBox(height: 20),

          // Colored icons
          TomText(
            tomId: 'icon.colorLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 8),
          TomWrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              TomIcon(icon: Icons.favorite, size: 32, color: Colors.red),
              TomIcon(
                icon: Icons.star,
                size: 32,
                color: Colors.amber,
              ),
              TomIcon(
                icon: Icons.eco,
                size: 32,
                color: Colors.green,
              ),
              TomIcon(
                icon: Icons.water_drop,
                size: 32,
                color: Colors.blue,
              ),
              TomIcon(
                icon: Icons.brightness_high,
                size: 32,
                color: Colors.orange,
              ),
            ],
          ),
          TomSizedBox(height: 20),

          // Icon categories
          TomText(
            tomId: 'icon.categoriesLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 8),
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildIconCategory('Navigation', [
                Icons.home_outlined,
                Icons.search,
                Icons.menu,
                Icons.arrow_back,
              ]),
              _buildIconCategory('Actions', [
                Icons.add,
                Icons.edit,
                Icons.delete,
                Icons.share,
              ]),
              _buildIconCategory('Content', [
                Icons.folder,
                Icons.file_copy,
                Icons.image,
                Icons.videocam,
              ]),
              _buildIconCategory('Communication', [
                Icons.mail,
                Icons.chat,
                Icons.phone,
                Icons.notifications,
              ]),
            ],
          ),
          TomSizedBox(height: 20),

          // TomId-resolved icons
          TomText(
            tomId: 'icon.resolvedLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 8),
          TomWrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              TomIcon(tomId: 'icon.resolved.save'),
              TomIcon(tomId: 'icon.resolved.edit'),
              TomIcon(tomId: 'icon.resolved.delete'),
              TomIcon(tomId: 'icon.resolved.settings'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconCategory(String label, List<IconData> icons) {
    final theme = Theme.of(context);
    return TomContainer(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TomColumn(
        children: [
          TomText(
            text: label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          TomSizedBox(height: 8),
          TomRow(
            mainAxisSize: MainAxisSize.min,
            children: icons
                .map((icon) => TomPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TomIcon(icon: icon, size: 20),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Images
  // ===========================================================================

  Widget _buildNetworkImageSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'networkImage',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Network image examples with placeholder
          TomText(
            tomId: 'networkImage.examplesLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildNetworkImageCard(
                'https://picsum.photos/200/150?random=1',
                'Random Image 1',
                200,
                150,
              ),
              _buildNetworkImageCard(
                'https://picsum.photos/200/150?random=2',
                'Random Image 2',
                200,
                150,
              ),
              _buildNetworkImageCard(
                'https://picsum.photos/200/150?random=3',
                'Random Image 3',
                200,
                150,
              ),
            ],
          ),
          TomSizedBox(height: 20),

          // Different fit modes
          TomText(
            tomId: 'networkImage.fitModesLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildFitModeExample('BoxFit.cover', BoxFit.cover),
              _buildFitModeExample('BoxFit.contain', BoxFit.contain),
              _buildFitModeExample('BoxFit.fill', BoxFit.fill),
              _buildFitModeExample('BoxFit.fitWidth', BoxFit.fitWidth),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkImageCard(
    String url,
    String label,
    double width,
    double height,
  ) {
    final theme = Theme.of(context);
    return TomColumn(
      children: [
        TomContainer(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.hardEdge,
          child: TomNetworkImage(
            src: url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return TomCenter(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return TomCenter(
                child: TomColumn(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TomIcon(
                      icon: Icons.broken_image,
                      size: 32,
                      color: theme.colorScheme.error,
                    ),
                    TomSizedBox(height: 4),
                    TomText(
                      text: 'Failed to load',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        TomSizedBox(height: 4),
        TomText(
          text: label,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }

  Widget _buildFitModeExample(String label, BoxFit fit) {
    final theme = Theme.of(context);
    return TomColumn(
      children: [
        TomContainer(
          width: 120,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.hardEdge,
          child: TomNetworkImage(
            src: 'https://picsum.photos/300/200?random=fit',
            width: 120,
            height: 80,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return TomCenter(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        ),
        TomSizedBox(height: 4),
        TomText(
          text: label,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 3: Circle Avatars
  // ===========================================================================

  Widget _buildCircleAvatarSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'avatar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Different sizes
          TomText(
            tomId: 'avatar.sizesLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TomCircleAvatar(
                radius: 16,
                child: TomText(
                  text: 'S',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              TomCircleAvatar(
                radius: 24,
                child: TomText(
                  text: 'M',
                  style: theme.textTheme.labelMedium,
                ),
              ),
              TomCircleAvatar(
                radius: 32,
                child: TomText(
                  text: 'L',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TomCircleAvatar(
                radius: 48,
                child: TomText(
                  text: 'XL',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          TomSizedBox(height: 20),

          // With initials
          TomText(
            tomId: 'avatar.initialsLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomCircleAvatar(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                child: TomText(text: 'JD'),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                child: TomText(text: 'AS'),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                child: TomText(text: 'MK'),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                child: TomText(text: 'RW'),
              ),
              TomCircleAvatar(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                child: TomText(text: 'LP'),
              ),
            ],
          ),
          TomSizedBox(height: 20),

          // With icons
          TomText(
            tomId: 'avatar.iconsLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomCircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: TomIcon(
                  icon: Icons.person,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              TomCircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: TomIcon(
                  icon: Icons.group,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              TomCircleAvatar(
                backgroundColor: theme.colorScheme.tertiaryContainer,
                child: TomIcon(
                  icon: Icons.business,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
              TomCircleAvatar(
                backgroundColor: theme.colorScheme.errorContainer,
                child: TomIcon(
                  icon: Icons.warning,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
          TomSizedBox(height: 20),

          // With network images
          TomText(
            tomId: 'avatar.imagesLabel',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomCircleAvatar(
                radius: 28,
                backgroundImage:
                    const NetworkImage('https://i.pravatar.cc/150?img=1'),
              ),
              TomCircleAvatar(
                radius: 28,
                backgroundImage:
                    const NetworkImage('https://i.pravatar.cc/150?img=2'),
              ),
              TomCircleAvatar(
                radius: 28,
                backgroundImage:
                    const NetworkImage('https://i.pravatar.cc/150?img=3'),
              ),
              TomCircleAvatar(
                radius: 28,
                backgroundImage:
                    const NetworkImage('https://i.pravatar.cc/150?img=4'),
              ),
              TomCircleAvatar(
                radius: 28,
                backgroundImage:
                    const NetworkImage('https://i.pravatar.cc/150?img=5'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: FadeIn Images
  // ===========================================================================

  Widget _buildFadeInImageSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'fadeInImage',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'fadeInImage.descriptionLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 16),
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildFadeInImageExample(
                'https://picsum.photos/200/150?random=fade1',
                'Gradient Placeholder',
              ),
              _buildFadeInImageExample(
                'https://picsum.photos/200/150?random=fade2',
                'Pattern Placeholder',
              ),
              _buildFadeInImageExample(
                'https://picsum.photos/200/150?random=fade3',
                'Color Placeholder',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFadeInImageExample(String url, String label) {
    final theme = Theme.of(context);
    return TomColumn(
      children: [
        TomContainer(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.hardEdge,
          child: TomFadeInImage(
            placeholder: MemoryImage(_createPlaceholderBytes()),
            image: NetworkImage(url),
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 500),
            fadeOutDuration: const Duration(milliseconds: 200),
            imageErrorBuilder: (context, error, stackTrace) {
              return TomCenter(
                child: TomIcon(
                  icon: Icons.broken_image,
                  size: 32,
                  color: theme.colorScheme.error,
                ),
              );
            },
          ),
        ),
        TomSizedBox(height: 4),
        TomText(
          text: label,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 5: Animated Icons & Image Effects
  // ===========================================================================

  Widget _buildAnimatedIconSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    final theme = Theme.of(context);

    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'animatedIcon',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                // Animated icon showcase
                TomExpanded(
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomWrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          _buildAnimatedIconExample(
                            AnimatedIcons.menu_close,
                            'Menu / Close',
                          ),
                          _buildAnimatedIconExample(
                            AnimatedIcons.play_pause,
                            'Play / Pause',
                          ),
                          _buildAnimatedIconExample(
                            AnimatedIcons.add_event,
                            'Add / Event',
                          ),
                          _buildAnimatedIconExample(
                            AnimatedIcons.home_menu,
                            'Home / Menu',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 16),
            TomRow(
              children: [
                TomFilledButton(
                  tomId: 'animatedIcon.toggle',
                  label: _isAnimatedIconPlaying ? 'Reverse' : 'Animate',
                  onPressed: _toggleAnimatedIcon,
                ),
                TomSizedBox(width: 16),
                TomIcon(
                  icon: direction == AclDirection.rtl
                      ? Icons.format_textdirection_r_to_l
                      : Icons.format_textdirection_l_to_r,
                  size: 16,
                ),
                TomSizedBox(width: 8),
                TomText(
                  text: direction == AclDirection.rtl
                      ? 'Right-to-Left layout'
                      : 'Left-to-Right layout',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedIconExample(AnimatedIconData icon, String label) {
    final theme = Theme.of(context);
    return TomColumn(
      children: [
        TomContainer(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TomCenter(
            child: TomAnimatedIcon(
              icon: icon,
              progress: _animatedIconController,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        TomSizedBox(height: 4),
        TomText(
          text: label,
          style: theme.textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildImageFilterSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'imageFilter',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blur slider
          TomRow(
            children: [
              TomText(
                tomId: 'imageFilter.blurLabel',
                style: theme.textTheme.labelMedium,
              ),
              TomExpanded(
                child: TomSlider(
                  value: _blurAmount,
                  min: 0,
                  max: 10,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() => _blurAmount = value);
                  },
                ),
              ),
              TomSizedBox(
                width: 40,
                child: TomText(
                  text: _blurAmount.toStringAsFixed(1),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          TomSizedBox(height: 16),

          // Filtered images
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildFilteredImageExample('Original', null),
              _buildFilteredImageExample(
                'Blur',
                ui.ImageFilter.blur(sigmaX: _blurAmount, sigmaY: _blurAmount),
              ),
              _buildFilteredImageExample(
                'Matrix',
                ui.ImageFilter.matrix(
                  Matrix4.rotationZ(_blurAmount * 0.05).storage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredImageExample(String label, ui.ImageFilter? filter) {
    final theme = Theme.of(context);
    return TomColumn(
      children: [
        TomContainer(
          width: 150,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.hardEdge,
          child: filter != null
              ? TomImageFiltered(
                  imageFilter: filter,
                  child: TomNetworkImage(
                    src: 'https://picsum.photos/150/100?random=filter',
                    width: 150,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                )
              : TomNetworkImage(
                  src: 'https://picsum.photos/150/100?random=filter',
                  width: 150,
                  height: 100,
                  fit: BoxFit.cover,
                ),
        ),
        TomSizedBox(height: 4),
        TomText(
          text: label,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Creates a simple placeholder image bytes for FadeInImage.
Uint8List _createPlaceholderBytes() {
  // Simple 1x1 transparent PNG
  return Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
    0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
    0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
    0x0D, 0x0A, 0x2D, 0xB4,
    0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND chunk
    0xAE, 0x42, 0x60, 0x82,
  ]);
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header with title, subtitle, and gradient divider.
class _SectionHeader extends TomStatelessWidget {
  final String tomId;

  _SectionHeader({
    required this.tomId,
  });

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
          tomId: '$tomId.title',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        TomSizedBox(height: 4),
        TomText(
          tomId: '$tomId.subtitle',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TomSizedBox(height: 8),
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
    );
  }
}

/// Demo card widget for individual widget showcases.
class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({
    required this.tomId,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            TomRow(
              children: [
                TomIcon(tomId: tomId),
                TomSizedBox(width: 12),
                TomExpanded(
                  child: TomText(
                    tomId: '$tomId.title',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 8),
            // Description
            TomText(
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TomSizedBox(height: 16),
            TomDivider(),
            TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}

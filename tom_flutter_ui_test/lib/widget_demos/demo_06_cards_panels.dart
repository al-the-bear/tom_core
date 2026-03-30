/// Demo 06: Card & Panel Layouts
///
/// Comprehensive demonstration of Tom container widgets for
/// cards, expansion tiles, expansion panels, and material surfaces.
/// Widgets covered: TomCard, TomExpansionTile, TomCupertinoExpansionTile,
/// TomExpansionPanelList, TomMaterial, TomInk.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Card & Panel Layouts demo.
class CardPanelDemo extends StatelessWidget {
  const CardPanelDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CardPanelDemoContent();
  }
}

class _CardPanelDemoContent extends StatefulWidget {
  const _CardPanelDemoContent();

  @override
  State<_CardPanelDemoContent> createState() => _CardPanelDemoContentState();
}

class _CardPanelDemoContentState extends State<_CardPanelDemoContent> {
  // ===========================================================================
  // Section 2: Expansion Tiles state
  // ===========================================================================
  bool _orderExpanded = false;
  bool _shippingExpanded = true;
  bool _paymentExpanded = false;

  // ===========================================================================
  // Section 3: Expansion Panel List state
  // ===========================================================================
  final List<bool> _faqExpanded = [true, false, false, false];

  // ===========================================================================
  // Section 5: ACL state
  // ===========================================================================
  bool _aclExpanded = false;
  double _aclElevation = 2;

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Cards
            _SectionHeader(tomId: 'demo06.section.cards'),
            const TomSizedBox(height: 16),
            _buildCardVariantsSection(),
            const TomSizedBox(height: 24),
            _buildProductCardSection(),
            const TomSizedBox(height: 32),

            // Section 2: Expansion Tiles
            _SectionHeader(tomId: 'demo06.section.expansionTiles'),
            const TomSizedBox(height: 16),
            _buildExpansionTileSection(),
            const TomSizedBox(height: 24),
            _buildCupertinoExpansionTileSection(),
            const TomSizedBox(height: 32),

            // Section 3: Expansion Panel Lists
            _SectionHeader(tomId: 'demo06.section.expansionPanels'),
            const TomSizedBox(height: 16),
            _buildExpansionPanelSection(),
            const TomSizedBox(height: 32),

            // Section 4: Material & Ink
            _SectionHeader(tomId: 'demo06.section.materialInk'),
            const TomSizedBox(height: 16),
            _buildMaterialSection(),
            const TomSizedBox(height: 24),
            _buildInkSection(),
            const TomSizedBox(height: 32),

            // Section 5: ACL Layout Demo
            _SectionHeader(tomId: 'demo06.section.acl'),
            const TomSizedBox(height: 16),
            _buildAclCardSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Cards
  // ===========================================================================

  Widget _buildCardVariantsSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo06.cardVariants',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elevated card
          TomText(tomId: 'demo06.cardVariants.elevatedLabel'),
          const TomSizedBox(height: 8),
          TomCard(
            elevation: 4,
            child: TomPadding(
              padding: const EdgeInsets.all(16),
              child: TomRow(
                children: [
                  TomIcon(
                    icon: Icons.layers,
                    color: theme.colorScheme.primary,
                  ),
                  const TomSizedBox(width: 12),
                  TomExpanded(
                    child: TomColumn(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TomText(
                          tomId: 'demo06.cardVariants.elevatedTitle',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TomText(
                          tomId: 'demo06.cardVariants.elevatedDesc',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TomSizedBox(height: 16),

          // Outlined card
          TomText(tomId: 'demo06.cardVariants.outlinedLabel'),
          const TomSizedBox(height: 8),
          TomCard(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            child: TomPadding(
              padding: const EdgeInsets.all(16),
              child: TomRow(
                children: [
                  TomIcon(
                    icon: Icons.crop_square,
                    color: theme.colorScheme.primary,
                  ),
                  const TomSizedBox(width: 12),
                  TomExpanded(
                    child: TomColumn(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TomText(
                          tomId: 'demo06.cardVariants.outlinedTitle',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TomText(
                          tomId: 'demo06.cardVariants.outlinedDesc',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TomSizedBox(height: 16),

          // Filled card
          TomText(tomId: 'demo06.cardVariants.filledLabel'),
          const TomSizedBox(height: 8),
          TomCard(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: TomPadding(
              padding: const EdgeInsets.all(16),
              child: TomRow(
                children: [
                  TomIcon(
                    icon: Icons.square_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const TomSizedBox(width: 12),
                  TomExpanded(
                    child: TomColumn(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TomText(
                          tomId: 'demo06.cardVariants.filledTitle',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TomText(
                          tomId: 'demo06.cardVariants.filledDesc',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TomSizedBox(height: 16),

          // Elevation comparison row
          TomText(tomId: 'demo06.cardVariants.elevationLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final elev in [0.0, 1.0, 3.0, 6.0, 12.0])
                TomColumn(
                  children: [
                    TomCard(
                      elevation: elev,
                      child: TomSizedBox(
                        width: 56,
                        height: 56,
                        child: TomCenter(
                          child: TomText(
                            text: '${elev.toInt()}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                    const TomSizedBox(height: 4),
                    TomText(
                      text: '${elev.toInt()}dp',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCardSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo06.productCard',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product card example
          TomCard(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image placeholder
                TomContainer(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                  ),
                  child: TomCenter(
                    child: TomColumn(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TomIcon(
                          icon: Icons.image,
                          size: 48,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.5),
                        ),
                        const TomSizedBox(height: 8),
                        TomText(
                          tomId: 'demo06.productCard.imagePlaceholder',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Product info
                TomPadding(
                  padding: const EdgeInsets.all(16),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomRow(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TomText(
                            tomId: 'demo06.productCard.productName',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TomText(
                            tomId: 'demo06.productCard.price',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const TomSizedBox(height: 4),
                      TomText(
                        tomId: 'demo06.productCard.productDescription',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const TomSizedBox(height: 8),
                      // Star rating
                      TomRow(
                        children: [
                          for (int i = 0; i < 4; i++)
                            Icon(Icons.star,
                                size: 16, color: Colors.amber.shade600),
                          Icon(Icons.star_half,
                              size: 16, color: Colors.amber.shade600),
                          const TomSizedBox(width: 4),
                          TomText(
                            tomId: 'demo06.productCard.rating',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const TomSizedBox(height: 12),
                      // Action buttons
                      TomRow(
                        children: [
                          TomExpanded(
                            child: TomFilledButton(
                              tomId: 'demo06.productCard.addToCart',
                              onPressed: () {},
                            ),
                          ),
                          const TomSizedBox(width: 8),
                          TomIconButton(
                            tooltip: 'Favorite',
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          // Action card with horizontal layout
          TomText(tomId: 'demo06.productCard.actionCardLabel'),
          const TomSizedBox(height: 8),
          TomCard(
            elevation: 1,
            child: TomPadding(
              padding: const EdgeInsets.all(16),
              child: TomRow(
                children: [
                  TomContainer(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TomCenter(
                      child: TomIcon(
                        icon: Icons.local_shipping,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  const TomSizedBox(width: 16),
                  TomExpanded(
                    child: TomColumn(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TomText(
                          tomId: 'demo06.productCard.shippingTitle',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TomText(
                          tomId: 'demo06.productCard.shippingDesc',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TomIcon(
                    icon: Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Expansion Tiles
  // ===========================================================================

  Widget _buildExpansionTileSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo06.expansionTile',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Details (collapsed by default)
          TomCard(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: TomExpansionTile(
              leading: const Icon(Icons.inventory_2),
              titleText: 'Order Details',
              initiallyExpanded: _orderExpanded,
              onExpansionChanged: (v) =>
                  setState(() => _orderExpanded = v),
              children: [
                TomPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Order #', 'ORD-2026-1234'),
                      _buildDetailRow('Date', 'March 30, 2026'),
                      _buildDetailRow('Items', '3 items'),
                      _buildDetailRow('Total', '\$299.97'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 8),

          // Shipping Address (expanded by default)
          TomCard(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: TomExpansionTile(
              leading: const Icon(Icons.location_on),
              titleText: 'Shipping Address',
              initiallyExpanded: _shippingExpanded,
              onExpansionChanged: (v) =>
                  setState(() => _shippingExpanded = v),
              children: [
                TomPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        tomId: 'demo06.expansionTile.addressName',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TomText(tomId: 'demo06.expansionTile.addressLine1'),
                      TomText(tomId: 'demo06.expansionTile.addressLine2'),
                      TomText(tomId: 'demo06.expansionTile.addressCountry'),
                      const TomSizedBox(height: 8),
                      TomTextButton(
                        tomId: 'demo06.expansionTile.editAddress',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 8),

          // Payment Method (collapsed by default)
          TomCard(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: TomExpansionTile(
              leading: const Icon(Icons.credit_card),
              titleText: 'Payment Method',
              initiallyExpanded: _paymentExpanded,
              onExpansionChanged: (v) =>
                  setState(() => _paymentExpanded = v),
              children: [
                TomPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomRow(
                        children: [
                          const Icon(Icons.credit_card, size: 20),
                          const TomSizedBox(width: 8),
                          TomText(
                            tomId: 'demo06.expansionTile.cardInfo',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const TomSizedBox(height: 4),
                      TomText(
                        tomId: 'demo06.expansionTile.cardExpiry',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 16),

          // Nested expansion tiles
          TomText(tomId: 'demo06.expansionTile.nestedLabel'),
          const TomSizedBox(height: 8),
          TomCard(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: TomExpansionTile(
              leading: const Icon(Icons.settings),
              titleText: 'Settings',
              children: [
                TomPadding(
                  padding: const EdgeInsets.only(left: 16),
                  child: TomExpansionTile(
                    leading: const Icon(Icons.notifications, size: 20),
                    titleText: 'Notifications',
                    dense: true,
                    children: [
                      TomPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TomText(
                          tomId: 'demo06.expansionTile.notifContent',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                TomPadding(
                  padding: const EdgeInsets.only(left: 16),
                  child: TomExpansionTile(
                    leading: const Icon(Icons.lock, size: 20),
                    titleText: 'Privacy',
                    dense: true,
                    children: [
                      TomPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TomText(
                          tomId: 'demo06.expansionTile.privacyContent',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return TomPadding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TomRow(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TomText(
            text: label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          TomText(
            text: value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoExpansionTileSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo06.cupertinoExpansion',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomCard(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: TomCupertinoExpansionTile(
              titleText: 'Account Information',
              child: TomPadding(
                padding: const EdgeInsets.all(16),
                child: TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Name', 'John Doe'),
                    _buildDetailRow('Email', 'john@example.com'),
                    _buildDetailRow('Plan', 'Premium'),
                  ],
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 8),
          TomCard(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: TomCupertinoExpansionTile(
              titleText: 'Preferences',
              child: TomPadding(
                padding: const EdgeInsets.all(16),
                child: TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Language', 'English'),
                    _buildDetailRow('Theme', 'System'),
                    _buildDetailRow('Currency', 'USD'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Expansion Panel Lists
  // ===========================================================================

  Widget _buildExpansionPanelSection() {
    return _DemoCard(
      tomId: 'demo06.expansionPanel',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo06.expansionPanel.faqTitle'),
          const TomSizedBox(height: 12),
          TomExpansionPanelList(
            expansionCallback: (panelIndex, isExpanded) {
              setState(() {
                _faqExpanded[panelIndex] = isExpanded;
              });
            },
            children: [
              _buildFaqPanel(
                0,
                'What is your return policy?',
                'We offer a 30-day return policy on all products. '
                    'Items must be in original packaging and unused condition. '
                    'Refunds are processed within 5-7 business days.',
              ),
              _buildFaqPanel(
                1,
                'How do I track my order?',
                'After your order ships, you will receive a tracking '
                    'number via email. You can use this number on our website '
                    'or the carrier\'s website to track your package.',
              ),
              _buildFaqPanel(
                2,
                'Do you ship internationally?',
                'Yes, we ship to over 50 countries worldwide. '
                    'International shipping rates and delivery times vary '
                    'depending on the destination.',
              ),
              _buildFaqPanel(
                3,
                'What payment methods do you accept?',
                'We accept all major credit cards (Visa, MasterCard, Amex), '
                    'PayPal, Apple Pay, and Google Pay. '
                    'Corporate accounts can also pay via invoice.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  ExpansionPanel _buildFaqPanel(int index, String header, String body) {
    return ExpansionPanel(
      headerBuilder: (context, isExpanded) {
        return TomPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TomText(
            text: header,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isExpanded ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        );
      },
      body: TomPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: TomText(
          text: body,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      isExpanded: _faqExpanded[index],
      canTapOnHeader: true,
    );
  }

  // ===========================================================================
  // Section 4: Material & Ink
  // ===========================================================================

  Widget _buildMaterialSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo06.material',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elevation levels
          TomText(tomId: 'demo06.material.elevationLabel'),
          const TomSizedBox(height: 12),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final elev in [0.0, 1.0, 3.0, 6.0, 12.0])
                TomColumn(
                  children: [
                    TomMaterial(
                      elevation: elev,
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surfaceContainerLow,
                      child: TomSizedBox(
                        width: 56,
                        height: 56,
                        child: TomCenter(
                          child: TomText(
                            text: '${elev.toInt()}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                    const TomSizedBox(height: 4),
                    TomText(
                      text: '${elev.toInt()}dp',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Material types
          TomText(tomId: 'demo06.material.typesLabel'),
          const TomSizedBox(height: 12),
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMaterialTypeChip(
                MaterialType.canvas,
                'Canvas',
                theme,
              ),
              _buildMaterialTypeChip(
                MaterialType.card,
                'Card',
                theme,
              ),
              _buildMaterialTypeChip(
                MaterialType.circle,
                'Circle',
                theme,
              ),
              _buildMaterialTypeChip(
                MaterialType.button,
                'Button',
                theme,
              ),
              _buildMaterialTypeChip(
                MaterialType.transparency,
                'Transparent',
                theme,
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Material with shape
          TomText(tomId: 'demo06.material.shapesLabel'),
          const TomSizedBox(height: 12),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TomMaterial(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                color: theme.colorScheme.primaryContainer,
                child: const TomSizedBox(width: 60, height: 60),
              ),
              TomMaterial(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: theme.colorScheme.secondaryContainer,
                child: const TomSizedBox(width: 60, height: 60),
              ),
              TomMaterial(
                elevation: 2,
                shape: const CircleBorder(),
                color: theme.colorScheme.tertiaryContainer,
                child: const TomSizedBox(width: 60, height: 60),
              ),
              TomMaterial(
                elevation: 2,
                shape: const StadiumBorder(),
                color: theme.colorScheme.errorContainer,
                child: const TomSizedBox(width: 80, height: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialTypeChip(
    MaterialType type,
    String label,
    ThemeData theme,
  ) {
    return TomMaterial(
      type: type,
      elevation: 2,
      color: type == MaterialType.transparency
          ? null
          : theme.colorScheme.surfaceContainerLow,
      child: TomPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TomText(
          text: label,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildInkSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'demo06.ink',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic ink with splash
          TomText(tomId: 'demo06.ink.splashLabel'),
          const TomSizedBox(height: 12),
          TomMaterial(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(8),
              child: TomPadding(
                padding: const EdgeInsets.all(24),
                child: TomCenter(
                  child: TomText(
                    tomId: 'demo06.ink.tapHere',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 16),

          // Ink decoration
          TomText(tomId: 'demo06.ink.decorationLabel'),
          const TomSizedBox(height: 12),
          TomMaterial(
            color: Colors.transparent,
            child: TomInk(
              color: theme.colorScheme.primaryContainer,
              height: 80,
              child: InkWell(
                onTap: () {},
                child: TomCenter(
                  child: TomText(
                    tomId: 'demo06.ink.decoratedInk',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const TomSizedBox(height: 16),

          // Ink with gradient decoration
          TomText(tomId: 'demo06.ink.gradientLabel'),
          const TomSizedBox(height: 12),
          TomMaterial(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: TomInk(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              height: 80,
              child: InkWell(
                onTap: () {},
                child: TomCenter(
                  child: TomText(
                    tomId: 'demo06.ink.gradientText',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: ACL Layout Demo
  // ===========================================================================

  Widget _buildAclCardSection() {
    return _DemoCard(
      tomId: 'demo06.aclCard',
      child: AclBuilder()
          // Row 1: Label + Card with elevation slider
          .append(TomText(tomId: 'demo06.aclCard.elevationLabel'))
          .append(
            TomSlider(
              value: _aclElevation,
              min: 0,
              max: 12,
              divisions: 12,
              label: _aclElevation.round().toString(),
              onChanged: (v) => setState(() => _aclElevation = v),
            ),
            dist: 16,
          )
          .expandX()
          .append(
            TomText(
              text: '${_aclElevation.round()}dp',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            dist: 8,
          )
          .newRow(dist: 16)
          // Row 2: Preview card
          .append(
            TomCard(
              elevation: _aclElevation,
              child: TomPadding(
                padding: const EdgeInsets.all(16),
                child: TomRow(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TomIcon(
                      icon: Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const TomSizedBox(width: 8),
                    TomText(
                      tomId: 'demo06.aclCard.previewText',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          )
          .expandX()
          .newRow(dist: 16)
          // Row 3: Expansion tile
          .append(
            TomExpansionTile(
              leading: const Icon(Icons.info_outline),
              titleText: 'More Information',
              initiallyExpanded: _aclExpanded,
              onExpansionChanged: (v) =>
                  setState(() => _aclExpanded = v),
              children: [
                TomPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TomText(
                    tomId: 'demo06.aclCard.moreInfo',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          )
          .expandX()
          .newRow(dist: 16)
          // Row 4: Buttons
          .append(
            TomTextButton(
              tomId: 'demo06.aclCard.reset',
              onPressed: () {
                setState(() {
                  _aclElevation = 2;
                  _aclExpanded = false;
                });
              },
            ),
          )
          .gap()
          .append(
            TomFilledButton(
              tomId: 'demo06.aclCard.apply',
              onPressed: () {},
            ),
            dist: 8,
          )
          .build(),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header widget for demo sections.
class _SectionHeader extends StatelessWidget {
  final String tomId;

  const _SectionHeader({
    required this.tomId,
  });

  @override
  Widget build(BuildContext context) {
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
        const TomSizedBox(height: 4),
        TomText(
          tomId: '$tomId.subtitle',
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
    );
  }
}

/// Demo card widget for individual widget showcases.
class _DemoCard extends StatelessWidget {
  final String tomId;
  final Widget child;

  const _DemoCard({
    required this.tomId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      elevation: 2,
      child: TomPadding(
        padding: const EdgeInsets.all(20),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            TomRow(
              children: [
                TomContainer(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomIcon(
                    tomId: '$tomId.icon',
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const TomSizedBox(width: 12),
                TomExpanded(
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        tomId: '$tomId.title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TomText(
                        tomId: '$tomId.description',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const TomSizedBox(height: 16),
            TomDivider(color: theme.colorScheme.outlineVariant),
            const TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}

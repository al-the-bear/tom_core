/// Demo 16: Tree & Hierarchy
///
/// Comprehensive demonstration of all Tom tree and hierarchy widgets.
/// Widgets covered: TomTreeView, TomTreeSliver, TomExpansionTile
/// (nested patterns for file explorer and organizational hierarchy).
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Tree & Hierarchy demo.
class TreesDemo extends TomStatelessWidget {
  TreesDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _TreesDemoContent();

  }
}

class _TreesDemoContent extends TomStatefulWidget {
  _TreesDemoContent();

  @override
  State<_TreesDemoContent> createState() => _TreesDemoContentState();
}

class _TreesDemoContentState extends TomState<_TreesDemoContent>
    with TickerProviderStateMixin {
  // TreeSliver controller for programmatic expand/collapse
  late TreeSliverController _treeSliverController;

  @override
  void initState() {
    super.initState();
    _treeSliverController = TreeSliverController();
  }

  // Note: TreeSliverController doesn't require disposal

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Simple Tree View
            _SectionHeader(
              tomId: 'section.simple',
            ),
            TomSizedBox(height: 16),
            _buildSimpleTreeSection(),
            TomSizedBox(height: 32),

            // Section 2: TreeSliver (High Performance)
            _SectionHeader(
              tomId: 'section.sliver',
            ),
            TomSizedBox(height: 16),
            _buildTreeSliverSection(),
            TomSizedBox(height: 32),

            // Section 3: Nested Expansion Tiles
            _SectionHeader(
              tomId: 'section.expansion',
            ),
            TomSizedBox(height: 16),
            _buildExpansionTileSection(),
            TomSizedBox(height: 32),

            // Section 4: File Explorer Pattern
            _SectionHeader(
              tomId: 'section.fileExplorer',
            ),
            TomSizedBox(height: 16),
            _buildFileExplorerSection(),
            TomSizedBox(height: 32),

            // Section 5: Organizational Hierarchy
            _SectionHeader(
              tomId: 'section.organization',
            ),
            TomSizedBox(height: 16),
            _buildOrganizationSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Simple Tree View
  // ===========================================================================

  Widget _buildSimpleTreeSection() {
    return _DemoCard(
      tomId: 'treeView',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'treeView.basicLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomTreeView(
              padding: const EdgeInsets.all(8),
              nodes: [
                TomTreeNode(
                  title: TomText(text: 'Animals'),
                  leading: TomIcon(
                    icon: Icons.pets,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  initiallyExpanded: true,
                  children: [
                    TomTreeNode(
                      title: TomText(text: 'Mammals'),
                      leading: TomIcon(icon: Icons.category),
                      children: [
                        TomTreeNode(
                          title: TomText(text: 'Dogs'),
                          leading: TomIcon(icon: Icons.emoji_nature),
                          onTap: () => _showNodeTapped(context, 'Dogs'),
                        ),
                        TomTreeNode(
                          title: TomText(text: 'Cats'),
                          leading: TomIcon(icon: Icons.emoji_nature),
                          onTap: () => _showNodeTapped(context, 'Cats'),
                        ),
                        TomTreeNode(
                          title: TomText(text: 'Elephants'),
                          leading: TomIcon(icon: Icons.emoji_nature),
                          onTap: () => _showNodeTapped(context, 'Elephants'),
                        ),
                      ],
                    ),
                    TomTreeNode(
                      title: TomText(text: 'Birds'),
                      leading: TomIcon(icon: Icons.category),
                      children: [
                        TomTreeNode(
                          title: TomText(text: 'Eagles'),
                          leading: TomIcon(icon: Icons.flight),
                          onTap: () => _showNodeTapped(context, 'Eagles'),
                        ),
                        TomTreeNode(
                          title: TomText(text: 'Parrots'),
                          leading: TomIcon(icon: Icons.flight),
                          onTap: () => _showNodeTapped(context, 'Parrots'),
                        ),
                      ],
                    ),
                    TomTreeNode(
                      title: TomText(text: 'Fish'),
                      leading: TomIcon(icon: Icons.category),
                      children: [
                        TomTreeNode(
                          title: TomText(text: 'Salmon'),
                          leading: TomIcon(icon: Icons.water),
                          onTap: () => _showNodeTapped(context, 'Salmon'),
                        ),
                        TomTreeNode(
                          title: TomText(text: 'Tuna'),
                          leading: TomIcon(icon: Icons.water),
                          onTap: () => _showNodeTapped(context, 'Tuna'),
                        ),
                      ],
                    ),
                  ],
                ),
                TomTreeNode(
                  title: TomText(text: 'Plants'),
                  leading: TomIcon(
                    icon: Icons.park,
                    color: Colors.green,
                  ),
                  children: [
                    TomTreeNode(
                      title: TomText(text: 'Trees'),
                      leading: TomIcon(icon: Icons.forest),
                      children: [
                        TomTreeNode(
                          title: TomText(text: 'Oak'),
                          onTap: () => _showNodeTapped(context, 'Oak'),
                        ),
                        TomTreeNode(
                          title: TomText(text: 'Pine'),
                          onTap: () => _showNodeTapped(context, 'Pine'),
                        ),
                      ],
                    ),
                    TomTreeNode(
                      title: TomText(text: 'Flowers'),
                      leading: TomIcon(icon: Icons.local_florist),
                      children: [
                        TomTreeNode(
                          title: TomText(text: 'Roses'),
                          onTap: () => _showNodeTapped(context, 'Roses'),
                        ),
                        TomTreeNode(
                          title: TomText(text: 'Tulips'),
                          onTap: () => _showNodeTapped(context, 'Tulips'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          TomSizedBox(height: 12),
          TomText(
            tomId: 'treeView.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  void _showNodeTapped(BuildContext context, String nodeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tapped: $nodeName'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ===========================================================================
  // Section 2: TreeSliver (High Performance)
  // ===========================================================================

  Widget _buildTreeSliverSection() {
    return _DemoCard(
      tomId: 'treeSliver',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'treeSliver.descriptionText',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          TomSizedBox(height: 16),

          // Control buttons
          TomWrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TomElevatedButton(
                tomId: 'treeSliver.expandAll',
                onPressed: _expandAllTreeSliver,
              ),
              TomOutlinedButton(
                tomId: 'treeSliver.collapseAll',
                onPressed: _collapseAllTreeSliver,
              ),
            ],
          ),
          TomSizedBox(height: 16),

          // TreeSliver demo
          TomContainer(
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomScrollView(
              slivers: [
                TomTreeSliver<String>(
                  controller: _treeSliverController,
                  tree: _buildLargeTreeData(),
                  onNodeToggle: (node) {
                    // Optional: Handle node toggle events
                  },
                  treeNodeBuilder: (
                    BuildContext context,
                    TreeSliverNode<Object?> node,
                    AnimationStyle animationStyle,
                  ) {
                    final data = node.content as String;
                    final depth = _getNodeDepth(node);
                    final hasChildren = node.children.isNotEmpty;

                    return TreeSliver.wrapChildToToggleNode(
                      node: node,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            if (hasChildren)
                              AnimatedRotation(
                                turns: node.isExpanded ? 0.25 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.chevron_right, size: 20),
                              )
                            else
                              const SizedBox(width: 20),
                            const SizedBox(width: 8),
                            Icon(
                              hasChildren
                                  ? Icons.folder
                                  : Icons.insert_drive_file,
                              size: 20,
                              color: hasChildren
                                  ? Colors.amber.shade700
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              data,
                              style: TextStyle(
                                fontWeight: depth == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          TomSizedBox(height: 12),
          TomText(
            tomId: 'treeSliver.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  List<TreeSliverNode<String>> _buildLargeTreeData() {
    return [
      TreeSliverNode<String>(
        'Documents',
        children: [
          TreeSliverNode<String>(
            'Work',
            children: [
              TreeSliverNode<String>('Report_Q1.pdf'),
              TreeSliverNode<String>('Report_Q2.pdf'),
              TreeSliverNode<String>('Presentation.pptx'),
              TreeSliverNode<String>(
                'Projects',
                children: [
                  TreeSliverNode<String>('Project_Alpha.docx'),
                  TreeSliverNode<String>('Project_Beta.docx'),
                  TreeSliverNode<String>('Project_Gamma.docx'),
                ],
              ),
            ],
          ),
          TreeSliverNode<String>(
            'Personal',
            children: [
              TreeSliverNode<String>('Resume.pdf'),
              TreeSliverNode<String>('Cover_Letter.docx'),
              TreeSliverNode<String>(
                'Photos',
                children: [
                  TreeSliverNode<String>('Vacation_2025'),
                  TreeSliverNode<String>('Birthday_Party'),
                  TreeSliverNode<String>('Graduation'),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeSliverNode<String>(
        'Downloads',
        children: [
          TreeSliverNode<String>('flutter_sdk.zip'),
          TreeSliverNode<String>('vscode_setup.exe'),
          TreeSliverNode<String>('music_album.zip'),
        ],
      ),
      TreeSliverNode<String>(
        'Pictures',
        children: [
          TreeSliverNode<String>(
            'Screenshots',
            children: [
              TreeSliverNode<String>('Screenshot_001.png'),
              TreeSliverNode<String>('Screenshot_002.png'),
              TreeSliverNode<String>('Screenshot_003.png'),
            ],
          ),
          TreeSliverNode<String>(
            'Wallpapers',
            children: [
              TreeSliverNode<String>('Nature.jpg'),
              TreeSliverNode<String>('Space.jpg'),
              TreeSliverNode<String>('Abstract.jpg'),
            ],
          ),
        ],
      ),
    ];
  }

  int _getNodeDepth(TreeSliverNode<Object?> node) {
    int depth = 0;
    TreeSliverNode<Object?>? current = node.parent;
    while (current != null) {
      depth++;
      current = current.parent;
    }
    return depth;
  }

  void _expandAllTreeSliver() {
    final nodes = _buildLargeTreeData();
    _expandNodes(nodes);
  }

  void _expandNodes(List<TreeSliverNode<String>> nodes) {
    for (final node in nodes) {
      if (node.children.isNotEmpty) {
        _treeSliverController.expandNode(node);
        _expandNodes(node.children.cast<TreeSliverNode<String>>());
      }
    }
  }

  void _collapseAllTreeSliver() {
    final nodes = _buildLargeTreeData();
    _collapseNodes(nodes);
  }

  void _collapseNodes(List<TreeSliverNode<String>> nodes) {
    for (final node in nodes) {
      if (node.children.isNotEmpty) {
        _treeSliverController.collapseNode(node);
        _collapseNodes(node.children.cast<TreeSliverNode<String>>());
      }
    }
  }

  // ===========================================================================
  // Section 3: Nested Expansion Tiles
  // ===========================================================================

  Widget _buildExpansionTileSection() {
    return _DemoCard(
      tomId: 'expansionTile',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic expansion tiles
          TomText(
            tomId: 'expansionTile.basicLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),

          TomExpansionTile(
            leading: TomIcon(
              icon: Icons.settings,
              color: Theme.of(context).colorScheme.primary,
            ),
            titleText: 'General Settings',
            subtitle: TomText(text: 'App preferences and configuration'),
            children: [
              TomListTile(
                leading: TomIcon(icon: Icons.language),
                titleText: 'Language',
                subtitle: TomText(text: 'English'),
                trailing: TomIcon(icon: Icons.chevron_right),
                onTap: () {},
              ),
              TomListTile(
                leading: TomIcon(icon: Icons.dark_mode),
                titleText: 'Theme',
                subtitle: TomText(text: 'System default'),
                trailing: TomIcon(icon: Icons.chevron_right),
                onTap: () {},
              ),
              TomListTile(
                leading: TomIcon(icon: Icons.notifications),
                titleText: 'Notifications',
                subtitle: TomText(text: 'Enabled'),
                trailing: TomSwitch(
                  value: true,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
          TomSizedBox(height: 8),

          TomExpansionTile(
            leading: TomIcon(
              icon: Icons.security,
              color: Theme.of(context).colorScheme.secondary,
            ),
            titleText: 'Privacy & Security',
            subtitle: TomText(text: 'Account security options'),
            children: [
              TomListTile(
                leading: TomIcon(icon: Icons.lock),
                titleText: 'Change Password',
                trailing: TomIcon(icon: Icons.chevron_right),
                onTap: () {},
              ),
              TomListTile(
                leading: TomIcon(icon: Icons.fingerprint),
                titleText: 'Biometric Login',
                trailing: TomSwitch(
                  value: false,
                  onChanged: (_) {},
                ),
              ),
              TomListTile(
                leading: TomIcon(icon: Icons.verified_user),
                titleText: 'Two-Factor Authentication',
                trailing: TomIcon(icon: Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
          TomSizedBox(height: 24),

          // Nested expansion tiles
          TomText(
            tomId: 'expansionTile.nestedLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),

          TomExpansionTile(
            initiallyExpanded: true,
            leading: TomIcon(
              icon: Icons.school,
              color: Colors.indigo,
            ),
            titleText: 'Computer Science',
            children: [
              TomExpansionTile(
                leading: TomIcon(icon: Icons.code),
                titleText: 'Programming',
                children: [
                  TomExpansionTile(
                    leading: TomIcon(icon: Icons.flutter_dash),
                    titleText: 'Mobile Development',
                    children: [
                      TomListTile(
                        titleText: 'Flutter',
                        subtitle: TomText(text: 'Cross-platform framework'),
                      ),
                      TomListTile(
                        titleText: 'React Native',
                        subtitle: TomText(text: 'JavaScript framework'),
                      ),
                      TomListTile(
                        titleText: 'Swift/SwiftUI',
                        subtitle: TomText(text: 'iOS native'),
                      ),
                    ],
                  ),
                  TomExpansionTile(
                    leading: TomIcon(icon: Icons.web),
                    titleText: 'Web Development',
                    children: [
                      TomListTile(
                        titleText: 'React',
                        subtitle: TomText(text: 'Frontend library'),
                      ),
                      TomListTile(
                        titleText: 'Vue.js',
                        subtitle: TomText(text: 'Progressive framework'),
                      ),
                    ],
                  ),
                ],
              ),
              TomExpansionTile(
                leading: TomIcon(icon: Icons.memory),
                titleText: 'Algorithms',
                children: [
                  TomListTile(
                    titleText: 'Sorting',
                    subtitle: TomText(text: 'QuickSort, MergeSort, etc.'),
                  ),
                  TomListTile(
                    titleText: 'Graph Theory',
                    subtitle: TomText(text: 'BFS, DFS, Dijkstra'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: File Explorer Pattern
  // ===========================================================================

  Widget _buildFileExplorerSection() {
    return _DemoCard(
      tomId: 'fileExplorer',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          TomRow(
            children: [
              TomIconButton(
                tooltip: 'New folder',
                icon: const Icon(Icons.create_new_folder),
                onPressed: () {},
              ),
              TomIconButton(
                tooltip: 'New file',
                icon: const Icon(Icons.note_add),
                onPressed: () {},
              ),
              TomSpacer(),
              TomIconButton(
                tooltip: 'List view',
                icon: const Icon(Icons.view_list),
                onPressed: () {},
              ),
              TomIconButton(
                tooltip: 'Grid view',
                icon: const Icon(Icons.grid_view),
                onPressed: () {},
              ),
            ],
          ),
          TomSizedBox(height: 8),
          TomDivider(),
          TomSizedBox(height: 8),

          // File explorer tree
          TomContainer(
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
            ),
            clipBehavior: Clip.antiAlias,
            child: TomTreeView(
              padding: const EdgeInsets.all(8),
              indentation: 20,
              nodes: [
                TomTreeNode(
                  title: TomText(
                    text: 'my_project',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  leading: Icon(
                    Icons.folder_special,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  initiallyExpanded: true,
                  children: [
                    TomTreeNode(
                      title: TomText(text: 'lib'),
                      leading: Icon(
                        Icons.folder,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      initiallyExpanded: true,
                      children: [
                        TomTreeNode(
                          title: TomText(text: 'src'),
                          leading: Icon(
                            Icons.folder,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          children: [
                            _buildFileNode('main.dart', Icons.code, Colors.blue),
                            _buildFileNode(
                                'app.dart', Icons.code, Colors.blue),
                            _buildFileNode(
                                'config.dart', Icons.settings, Colors.grey),
                          ],
                        ),
                        TomTreeNode(
                          title: TomText(text: 'widgets'),
                          leading: Icon(
                            Icons.folder,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          children: [
                            _buildFileNode(
                                'button.dart', Icons.code, Colors.blue),
                            _buildFileNode(
                                'card.dart', Icons.code, Colors.blue),
                            _buildFileNode(
                                'dialog.dart', Icons.code, Colors.blue),
                          ],
                        ),
                      ],
                    ),
                    TomTreeNode(
                      title: TomText(text: 'test'),
                      leading: Icon(
                        Icons.folder,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      children: [
                        _buildFileNode(
                            'widget_test.dart', Icons.bug_report, Colors.green),
                        _buildFileNode(
                            'unit_test.dart', Icons.bug_report, Colors.green),
                      ],
                    ),
                    TomTreeNode(
                      title: TomText(text: 'assets'),
                      leading: Icon(
                        Icons.folder,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      children: [
                        _buildFileNode(
                            'logo.png', Icons.image, Colors.purple),
                        _buildFileNode(
                            'icon.svg', Icons.image, Colors.purple),
                      ],
                    ),
                    _buildFileNode(
                        'pubspec.yaml', Icons.description, Colors.red),
                    _buildFileNode(
                        'README.md', Icons.article, Colors.orange),
                    _buildFileNode(
                        '.gitignore', Icons.visibility_off, Colors.grey),
                  ],
                ),
              ],
            ),
          ),
          TomSizedBox(height: 12),
          TomText(
            tomId: 'fileExplorer.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  TomTreeNode _buildFileNode(String name, IconData icon, Color color) {
    return TomTreeNode(
      title: TomText(text: name),
      leading: Icon(icon, color: color, size: 18),
      trailing: TomPopupMenuButton<String>(
        tooltip: 'More actions',
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'open', child: Text('Open')),
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
        child: const Icon(Icons.more_horiz, size: 16),
      ),
      onTap: () => _showNodeTapped(context, name),
    );
  }

  // ===========================================================================
  // Section 5: Organizational Hierarchy
  // ===========================================================================

  Widget _buildOrganizationSection() {
    return _DemoCard(
      tomId: 'organization',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Organization tree
          TomContainer(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: TomColumn(
              children: [
                // CEO
                _buildOrgCard(
                  name: 'Sarah Johnson',
                  role: 'Chief Executive Officer',
                  avatar: 'SJ',
                  color: Theme.of(context).colorScheme.primary,
                  isExpanded: true,
                ),
                TomSizedBox(height: 8),
                // Vertical connector
                TomContainer(
                  width: 2,
                  height: 20,
                  color: Theme.of(context).colorScheme.outline,
                ),
                // Horizontal spread
                TomRow(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TomContainer(
                      width: 100,
                      height: 2,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ],
                ),
                TomSizedBox(height: 8),
                // Department heads
                TomRow(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CTO Branch
                    TomExpanded(
                      child: TomColumn(
                        children: [
                          _buildOrgCard(
                            name: 'Mike Chen',
                            role: 'CTO',
                            avatar: 'MC',
                            color: Colors.blue,
                          ),
                          TomSizedBox(height: 8),
                          TomContainer(
                            width: 2,
                            height: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          TomSizedBox(height: 8),
                          _buildOrgCard(
                            name: 'Alex Park',
                            role: 'Lead Developer',
                            avatar: 'AP',
                            color: Colors.lightBlue,
                            compact: true,
                          ),
                          TomSizedBox(height: 4),
                          _buildOrgCard(
                            name: 'Lisa Wang',
                            role: 'DevOps Manager',
                            avatar: 'LW',
                            color: Colors.lightBlue,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                    TomSizedBox(width: 16),
                    // CFO Branch
                    TomExpanded(
                      child: TomColumn(
                        children: [
                          _buildOrgCard(
                            name: 'Emily Brown',
                            role: 'CFO',
                            avatar: 'EB',
                            color: Colors.green,
                          ),
                          TomSizedBox(height: 8),
                          TomContainer(
                            width: 2,
                            height: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          TomSizedBox(height: 8),
                          _buildOrgCard(
                            name: 'David Kim',
                            role: 'Finance Manager',
                            avatar: 'DK',
                            color: Colors.lightGreen,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                    TomSizedBox(width: 16),
                    // CMO Branch
                    TomExpanded(
                      child: TomColumn(
                        children: [
                          _buildOrgCard(
                            name: 'James Wilson',
                            role: 'CMO',
                            avatar: 'JW',
                            color: Colors.orange,
                          ),
                          TomSizedBox(height: 8),
                          TomContainer(
                            width: 2,
                            height: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          TomSizedBox(height: 8),
                          _buildOrgCard(
                            name: 'Anna Lee',
                            role: 'Marketing Lead',
                            avatar: 'AL',
                            color: Colors.amber,
                            compact: true,
                          ),
                          TomSizedBox(height: 4),
                          _buildOrgCard(
                            name: 'Tom Scott',
                            role: 'Brand Manager',
                            avatar: 'TS',
                            color: Colors.amber,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TomSizedBox(height: 12),
          TomText(
            tomId: 'organization.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgCard({
    required String name,
    required String role,
    required String avatar,
    required Color color,
    bool isExpanded = false,
    bool compact = false,
  }) {
    if (compact) {
      return TomCard(
        child: TomPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: TomRow(
            mainAxisSize: MainAxisSize.min,
            children: [
              TomCircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.2),
                child: TomText(
                  text: avatar,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              TomSizedBox(width: 8),
              TomColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TomText(
                    text: name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TomText(
                    text: role,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return TomCard(
      elevation: isExpanded ? 4 : 2,
      child: TomPadding(
        padding: const EdgeInsets.all(12),
        child: TomColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            TomCircleAvatar(
              radius: isExpanded ? 28 : 22,
              backgroundColor: color.withValues(alpha: 0.2),
              child: TomText(
                text: avatar,
                style: TextStyle(
                  fontSize: isExpanded ? 18 : 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            TomSizedBox(height: 8),
            TomText(
              text: name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isExpanded ? 14 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            TomText(
              text: role,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isExpanded ? 12 : 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Section Header & Demo Card (Local Helpers)
// =============================================================================

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

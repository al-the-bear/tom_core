/// Comprehensive Trees Demo
///
/// This demo showcases tree view patterns, nested lists,
/// folder structures, and hierarchical data display.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main trees demo screen.
class TreesDemo extends StatelessWidget {
  const TreesDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Basic Tree View',
          subtitle: 'Simple hierarchical list',
        ),
        _BasicTreeSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'File Explorer Tree',
          subtitle: 'Folder and file structure',
        ),
        _FileExplorerSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Selectable Tree',
          subtitle: 'Tree with selection support',
        ),
        _SelectableTreeSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Checkbox Tree',
          subtitle: 'Tree with checkboxes',
        ),
        _CheckboxTreeSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Custom Tree Node',
          subtitle: 'Tree with custom styling',
        ),
        _CustomTreeSection(),
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
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const TomSizedBox(height: 4),
          Text(
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
// Tree Node Model
// =============================================================================

class TreeNode {
  final String id;
  final String title;
  final IconData? icon;
  final List<TreeNode> children;
  bool isExpanded;

  TreeNode({
    required this.id,
    required this.title,
    this.icon,
    this.children = const [],
    this.isExpanded = false,
  });
}

// =============================================================================
// Basic Tree Section
// =============================================================================

class _BasicTreeSection extends StatefulWidget {
  const _BasicTreeSection();

  @override
  State<_BasicTreeSection> createState() => _BasicTreeSectionState();
}

class _BasicTreeSectionState extends State<_BasicTreeSection> {
  late List<TreeNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = [
      TreeNode(
        id: '1',
        title: 'Electronics',
        icon: Icons.devices,
        children: [
          TreeNode(
            id: '1.1',
            title: 'Computers',
            children: [
              TreeNode(id: '1.1.1', title: 'Laptops'),
              TreeNode(id: '1.1.2', title: 'Desktops'),
              TreeNode(id: '1.1.3', title: 'Tablets'),
            ],
          ),
          TreeNode(
            id: '1.2',
            title: 'Phones',
            children: [
              TreeNode(id: '1.2.1', title: 'Smartphones'),
              TreeNode(id: '1.2.2', title: 'Feature Phones'),
            ],
          ),
          TreeNode(id: '1.3', title: 'Accessories'),
        ],
      ),
      TreeNode(
        id: '2',
        title: 'Clothing',
        icon: Icons.checkroom,
        children: [
          TreeNode(id: '2.1', title: 'Men'),
          TreeNode(id: '2.2', title: 'Women'),
          TreeNode(id: '2.3', title: 'Kids'),
        ],
      ),
      TreeNode(
        id: '3',
        title: 'Books',
        icon: Icons.book,
        children: [
          TreeNode(id: '3.1', title: 'Fiction'),
          TreeNode(id: '3.2', title: 'Non-Fiction'),
          TreeNode(id: '3.3', title: 'Academic'),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(8),
        child: TomColumn(
          children: _nodes.map((node) => _buildNode(node, 0)).toList(),
        ),
      ),
    );
  }

  Widget _buildNode(TreeNode node, int level) {
    final hasChildren = node.children.isNotEmpty;
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasChildren
              ? () => setState(() => node.isExpanded = !node.isExpanded)
              : null,
          borderRadius: BorderRadius.circular(4),
          child: TomPadding(
            padding: EdgeInsets.only(left: level * 24.0),
            child: TomRow(
              children: [
                TomSizedBox(
                  width: 24,
                  child: hasChildren
                      ? TomIcon(
                          node.isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 20,
                        )
                      : null,
                ),
                if (node.icon != null) ...[
                  TomIcon(node.icon, size: 20),
                  const TomSizedBox(width: 8),
                ],
                TomExpanded(
                  child: TomPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(node.title),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (node.isExpanded)
          ...node.children.map((child) => _buildNode(child, level + 1)),
      ],
    );
  }
}

// =============================================================================
// File Explorer Section
// =============================================================================

class _FileExplorerSection extends StatefulWidget {
  const _FileExplorerSection();

  @override
  State<_FileExplorerSection> createState() => _FileExplorerSectionState();
}

class _FileExplorerSectionState extends State<_FileExplorerSection> {
  late List<_FileNode> _files;

  @override
  void initState() {
    super.initState();
    _files = [
      _FileNode(
        name: 'project',
        isDirectory: true,
        children: [
          _FileNode(
            name: 'lib',
            isDirectory: true,
            children: [
              _FileNode(name: 'main.dart'),
              _FileNode(name: 'app.dart'),
              _FileNode(
                name: 'screens',
                isDirectory: true,
                children: [
                  _FileNode(name: 'home_screen.dart'),
                  _FileNode(name: 'settings_screen.dart'),
                ],
              ),
              _FileNode(
                name: 'widgets',
                isDirectory: true,
                children: [
                  _FileNode(name: 'button.dart'),
                  _FileNode(name: 'card.dart'),
                ],
              ),
            ],
          ),
          _FileNode(
            name: 'test',
            isDirectory: true,
            children: [
              _FileNode(name: 'widget_test.dart'),
            ],
          ),
          _FileNode(name: 'pubspec.yaml'),
          _FileNode(name: 'README.md'),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomContainer(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                Text(
                  'EXPLORER',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const TomSpacer(),
                TomIcon(Icons.more_horiz, color: Colors.grey.shade500, size: 16),
              ],
            ),
            const TomSizedBox(height: 8),
            ..._files.map((file) => _buildFileNode(file, 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildFileNode(_FileNode file, int level) {
    final isDir = file.isDirectory;
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: isDir
              ? () => setState(() => file.isExpanded = !file.isExpanded)
              : null,
          child: TomPadding(
            padding: EdgeInsets.only(left: level * 16.0, top: 2, bottom: 2),
            child: TomRow(
              children: [
                if (isDir)
                  TomIcon(
                    file.isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: Colors.grey.shade400,
                  )
                else
                  const TomSizedBox(width: 16),
                TomIcon(
                  _getFileIcon(file),
                  size: 16,
                  color: _getFileColor(file),
                ),
                const TomSizedBox(width: 6),
                Text(
                  file.name,
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (file.isExpanded && file.children != null)
          ...file.children!.map((child) => _buildFileNode(child, level + 1)),
      ],
    );
  }

  IconData _getFileIcon(_FileNode file) {
    if (file.isDirectory) {
      return file.isExpanded ? Icons.folder_open : Icons.folder;
    }
    if (file.name.endsWith('.dart')) return Icons.code;
    if (file.name.endsWith('.yaml') || file.name.endsWith('.yml')) {
      return Icons.settings;
    }
    if (file.name.endsWith('.md')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(_FileNode file) {
    if (file.isDirectory) return Colors.amber;
    if (file.name.endsWith('.dart')) return Colors.blue;
    if (file.name.endsWith('.yaml') || file.name.endsWith('.yml')) {
      return Colors.pink;
    }
    if (file.name.endsWith('.md')) return Colors.cyan;
    return Colors.grey;
  }
}

class _FileNode {
  final String name;
  final bool isDirectory;
  final List<_FileNode>? children;
  bool isExpanded;

  _FileNode({
    required this.name,
    this.isDirectory = false,
    this.children,
    this.isExpanded = true,
  });
}

// =============================================================================
// Selectable Tree Section
// =============================================================================

class _SelectableTreeSection extends StatefulWidget {
  const _SelectableTreeSection();

  @override
  State<_SelectableTreeSection> createState() => _SelectableTreeSectionState();
}

class _SelectableTreeSectionState extends State<_SelectableTreeSection> {
  String? _selectedId;
  late List<TreeNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = [
      TreeNode(
        id: '1',
        title: 'Sales',
        icon: Icons.attach_money,
        isExpanded: true,
        children: [
          TreeNode(id: '1.1', title: 'Q1 Report'),
          TreeNode(id: '1.2', title: 'Q2 Report'),
          TreeNode(id: '1.3', title: 'Q3 Report'),
          TreeNode(id: '1.4', title: 'Q4 Report'),
        ],
      ),
      TreeNode(
        id: '2',
        title: 'Marketing',
        icon: Icons.campaign,
        children: [
          TreeNode(id: '2.1', title: 'Campaigns'),
          TreeNode(id: '2.2', title: 'Analytics'),
        ],
      ),
      TreeNode(
        id: '3',
        title: 'Engineering',
        icon: Icons.engineering,
        children: [
          TreeNode(id: '3.1', title: 'Frontend'),
          TreeNode(id: '3.2', title: 'Backend'),
          TreeNode(id: '3.3', title: 'DevOps'),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(8),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedId != null)
              TomPadding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Selected: $_selectedId',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ..._nodes.map((node) => _buildNode(node, 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildNode(TreeNode node, int level) {
    final hasChildren = node.children.isNotEmpty;
    final isSelected = _selectedId == node.id;
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomContainer(
          margin: EdgeInsets.only(left: level * 24.0),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: InkWell(
            onTap: () {
              if (hasChildren) {
                setState(() => node.isExpanded = !node.isExpanded);
              }
              setState(() => _selectedId = node.id);
            },
            borderRadius: BorderRadius.circular(4),
            child: TomPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: TomRow(
                children: [
                  TomSizedBox(
                    width: 24,
                    child: hasChildren
                        ? TomIcon(
                            node.isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 20,
                            color: isSelected ? Colors.blue : null,
                          )
                        : null,
                  ),
                  if (node.icon != null) ...[
                    TomIcon(
                      node.icon,
                      size: 20,
                      color: isSelected ? Colors.blue : null,
                    ),
                    const TomSizedBox(width: 8),
                  ],
                  TomExpanded(
                    child: Text(
                      node.title,
                      style: TextStyle(
                        color: isSelected ? Colors.blue : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (node.isExpanded)
          ...node.children.map((child) => _buildNode(child, level + 1)),
      ],
    );
  }
}

// =============================================================================
// Checkbox Tree Section
// =============================================================================

class _CheckboxTreeSection extends StatefulWidget {
  const _CheckboxTreeSection();

  @override
  State<_CheckboxTreeSection> createState() => _CheckboxTreeSectionState();
}

class _CheckboxTreeSectionState extends State<_CheckboxTreeSection> {
  late List<_CheckNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = [
      _CheckNode(
        id: '1',
        title: 'Permissions',
        isExpanded: true,
        children: [
          _CheckNode(
            id: '1.1',
            title: 'Read',
            children: [
              _CheckNode(id: '1.1.1', title: 'View files', isChecked: true),
              _CheckNode(id: '1.1.2', title: 'List directories', isChecked: true),
            ],
          ),
          _CheckNode(
            id: '1.2',
            title: 'Write',
            children: [
              _CheckNode(id: '1.2.1', title: 'Create files'),
              _CheckNode(id: '1.2.2', title: 'Edit files', isChecked: true),
              _CheckNode(id: '1.2.3', title: 'Delete files'),
            ],
          ),
          _CheckNode(
            id: '1.3',
            title: 'Execute',
            children: [
              _CheckNode(id: '1.3.1', title: 'Run scripts'),
              _CheckNode(id: '1.3.2', title: 'Install packages'),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(8),
        child: TomColumn(
          children: _nodes.map((node) => _buildNode(node, 0)).toList(),
        ),
      ),
    );
  }

  Widget _buildNode(_CheckNode node, int level) {
    final hasChildren = node.children.isNotEmpty;
    final checkState = _getCheckState(node);

    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomPadding(
          padding: EdgeInsets.only(left: level * 24.0),
          child: TomRow(
            children: [
              TomSizedBox(
                width: 24,
                child: hasChildren
                    ? GestureDetector(
                        onTap: () =>
                            setState(() => node.isExpanded = !node.isExpanded),
                        child: TomIcon(
                          node.isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 20,
                        ),
                      )
                    : null,
              ),
              Checkbox(
                value: checkState == _CheckState.checked
                    ? true
                    : checkState == _CheckState.partial
                        ? null
                        : false,
                tristate: hasChildren,
                onChanged: (value) {
                  setState(() => _setChecked(node, value ?? false));
                },
              ),
              TomExpanded(
                child: GestureDetector(
                  onTap: () {
                    if (hasChildren) {
                      setState(() => node.isExpanded = !node.isExpanded);
                    }
                  },
                  child: TomPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      node.title,
                      style: TextStyle(
                        fontWeight: hasChildren ? FontWeight.w500 : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (node.isExpanded)
          ...node.children.map((child) => _buildNode(child, level + 1)),
      ],
    );
  }

  _CheckState _getCheckState(_CheckNode node) {
    if (node.children.isEmpty) {
      return node.isChecked ? _CheckState.checked : _CheckState.unchecked;
    }
    final checkedCount = node.children.where((c) => _getCheckState(c) == _CheckState.checked).length;
    final partialCount = node.children.where((c) => _getCheckState(c) == _CheckState.partial).length;
    if (checkedCount == node.children.length) return _CheckState.checked;
    if (checkedCount > 0 || partialCount > 0) return _CheckState.partial;
    return _CheckState.unchecked;
  }

  void _setChecked(_CheckNode node, bool value) {
    node.isChecked = value;
    for (final child in node.children) {
      _setChecked(child, value);
    }
  }
}

enum _CheckState { unchecked, partial, checked }

class _CheckNode {
  final String id;
  final String title;
  final List<_CheckNode> children;
  bool isExpanded;
  bool isChecked;

  _CheckNode({
    required this.id,
    required this.title,
    this.children = const [],
    this.isExpanded = true,
    this.isChecked = false,
  });
}

// =============================================================================
// Custom Tree Section
// =============================================================================

class _CustomTreeSection extends StatefulWidget {
  const _CustomTreeSection();

  @override
  State<_CustomTreeSection> createState() => _CustomTreeSectionState();
}

class _CustomTreeSectionState extends State<_CustomTreeSection> {
  late List<_OrgNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = [
      _OrgNode(
        name: 'CEO',
        role: 'Chief Executive',
        avatar: 'C',
        color: Colors.purple,
        isExpanded: true,
        children: [
          _OrgNode(
            name: 'CTO',
            role: 'Technology',
            avatar: 'T',
            color: Colors.blue,
            children: [
              _OrgNode(name: 'Dev Lead', role: 'Development', avatar: 'D', color: Colors.indigo),
              _OrgNode(name: 'QA Lead', role: 'Quality', avatar: 'Q', color: Colors.teal),
            ],
          ),
          _OrgNode(
            name: 'CFO',
            role: 'Finance',
            avatar: 'F',
            color: Colors.green,
            children: [
              _OrgNode(name: 'Accountant', role: 'Accounting', avatar: 'A', color: Colors.lime),
            ],
          ),
          _OrgNode(
            name: 'CMO',
            role: 'Marketing',
            avatar: 'M',
            color: Colors.orange,
            children: [
              _OrgNode(name: 'Designer', role: 'Design', avatar: 'D', color: Colors.pink),
              _OrgNode(name: 'Writer', role: 'Content', avatar: 'W', color: Colors.amber),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Chart',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const TomSizedBox(height: 16),
            ..._nodes.map((node) => _buildNode(node, 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildNode(_OrgNode node, int level) {
    final hasChildren = node.children.isNotEmpty;
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomRow(
          children: [
            ...List.generate(level, (i) => _buildConnector(i == level - 1)),
            TomExpanded(
              child: InkWell(
                onTap: hasChildren
                    ? () => setState(() => node.isExpanded = !node.isExpanded)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: TomContainer(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        node.color.withValues(alpha: 0.1),
                        node.color.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: node.color.withValues(alpha: 0.3)),
                  ),
                  child: TomRow(
                    children: [
                      CircleAvatar(
                        backgroundColor: node.color,
                        radius: 18,
                        child: Text(
                          node.avatar,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const TomSizedBox(width: 12),
                      TomExpanded(
                        child: TomColumn(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              node.role,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasChildren)
                        TomIcon(
                          node.isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: node.color,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (node.isExpanded)
          ...node.children.map((child) => _buildNode(child, level + 1)),
      ],
    );
  }

  Widget _buildConnector(bool isLast) {
    return TomContainer(
      width: 32,
      height: 48,
      alignment: Alignment.centerLeft,
      child: TomContainer(
        width: 16,
        height: 1,
        color: Colors.grey.shade300,
      ),
    );
  }
}

class _OrgNode {
  final String name;
  final String role;
  final String avatar;
  final Color color;
  final List<_OrgNode> children;
  bool isExpanded;

  _OrgNode({
    required this.name,
    required this.role,
    required this.avatar,
    required this.color,
    this.children = const [],
    this.isExpanded = false,
  });
}

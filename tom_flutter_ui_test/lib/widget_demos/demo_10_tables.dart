/// Demo 10: Data Tables
///
/// Comprehensive demonstration of Tom table and grid widgets for
/// data display, pagination, sorting, selection, grid layouts,
/// and reorderable lists.
/// Widgets covered: TomDataTable, TomPaginatedDataTable, TomTable,
/// TomGridView, TomReorderableListView.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Data Tables demo.
class DataTablesDemo extends TomStatelessWidget {
  DataTablesDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _TablesDemoContent();
  }
}

class _TablesDemoContent extends TomStatefulWidget {
  _TablesDemoContent();

  @override
  State<_TablesDemoContent> createState() => _TablesDemoContentState();
}

class _TablesDemoContentState extends TomState<_TablesDemoContent> {
  // ===========================================================================
  // Section 1: TomDataTable state
  // ===========================================================================
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final Set<int> _selectedRows = {};
  late List<_Product> _products;

  // ===========================================================================
  // Section 2: TomPaginatedDataTable state
  // ===========================================================================
  late _ProductDataSource _productDataSource;
  int _rowsPerPage = 5;

  // ===========================================================================
  // Section 3: TomTable state
  // ===========================================================================
  // Static layout - no state needed

  // ===========================================================================
  // Section 4: TomGridView state
  // ===========================================================================
  int _gridCrossAxisCount = 3;

  // ===========================================================================
  // Section 5: TomReorderableListView state
  // ===========================================================================
  late List<String> _reorderableItems;

  @override
  void initState() {
    super.initState();
    _initSampleData();
    _productDataSource = _ProductDataSource(_products);
    _reorderableItems = List.generate(8, (i) => 'Item ${i + 1}');
  }

  void _initSampleData() {
    _products = [
      _Product(1, 'Laptop Pro', 'Electronics', 1299.99, 45, true),
      _Product(2, 'Wireless Mouse', 'Electronics', 29.99, 150, true),
      _Product(3, 'Office Chair', 'Furniture', 349.00, 28, true),
      _Product(4, 'Monitor 27"', 'Electronics', 449.99, 62, false),
      _Product(5, 'Keyboard RGB', 'Electronics', 89.99, 95, true),
      _Product(6, 'Desk Lamp', 'Furniture', 45.00, 73, true),
      _Product(7, 'USB Hub', 'Electronics', 24.99, 200, true),
      _Product(8, 'Webcam HD', 'Electronics', 79.99, 55, false),
      _Product(9, 'Standing Desk', 'Furniture', 599.00, 15, true),
      _Product(10, 'Headphones', 'Electronics', 199.99, 80, true),
    ];
  }

  void _sortData(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      switch (columnIndex) {
        case 0:
          _products.sort(
            (a, b) => ascending ? a.id.compareTo(b.id) : b.id.compareTo(a.id),
          );
        case 1:
          _products.sort(
            (a, b) =>
                ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name),
          );
        case 2:
          _products.sort(
            (a, b) => ascending
                ? a.category.compareTo(b.category)
                : b.category.compareTo(a.category),
          );
        case 3:
          _products.sort(
            (a, b) => ascending
                ? a.price.compareTo(b.price)
                : b.price.compareTo(a.price),
          );
        case 4:
          _products.sort(
            (a, b) => ascending
                ? a.stock.compareTo(b.stock)
                : b.stock.compareTo(a.stock),
          );
      }
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
            // Section 1: TomDataTable
            _SectionHeader(tomId: 'section.dataTable'),
            TomSizedBox(height: 16),
            _buildDataTableSection(),
            TomSizedBox(height: 32),

            // Section 2: TomPaginatedDataTable
            _SectionHeader(tomId: 'section.paginated'),
            TomSizedBox(height: 16),
            _buildPaginatedTableSection(),
            TomSizedBox(height: 32),

            // Section 3: TomTable
            _SectionHeader(tomId: 'section.table'),
            TomSizedBox(height: 16),
            _buildTableSection(),
            TomSizedBox(height: 32),

            // Section 4: TomGridView
            _SectionHeader(tomId: 'section.grid'),
            TomSizedBox(height: 16),
            _buildGridViewSection(),
            TomSizedBox(height: 32),

            // Section 5: TomReorderableListView / ACL
            _SectionHeader(tomId: 'section.acl'),
            TomSizedBox(height: 16),
            _buildReorderableListSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: TomDataTable
  // ===========================================================================

  Widget _buildDataTableSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'dataTable',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomRow(
            children: [
              TomText(
                tomId: 'dataTable.selectedLabel',
                style: theme.textTheme.bodyMedium,
              ),
              TomSizedBox(width: 8),
              TomText(
                text: '${_selectedRows.length} rows',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TomSizedBox(width: 16),
              TomTextButton(
                tomId: 'dataTable.clearSelection',
                onPressed: _selectedRows.isNotEmpty
                    ? () => setState(() => _selectedRows.clear())
                    : null,
              ),
            ],
          ),
          TomSizedBox(height: 16),
          TomSingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: TomDataTable(
              tomId: 'dataTable.table',
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              showCheckboxColumn: true,
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.surfaceContainerHighest,
              ),
              columns: [
                TomDataColumn(
                  label: TomText(tomId: 'dataTable.col.id'),
                  numeric: true,
                  onSort: (i, asc) => _sortData(i, asc),
                ),
                TomDataColumn(
                  label: TomText(tomId: 'dataTable.col.name'),
                  onSort: (i, asc) => _sortData(i, asc),
                ),
                TomDataColumn(
                  label: TomText(tomId: 'dataTable.col.category'),
                  onSort: (i, asc) => _sortData(i, asc),
                ),
                TomDataColumn(
                  label: TomText(tomId: 'dataTable.col.price'),
                  numeric: true,
                  onSort: (i, asc) => _sortData(i, asc),
                ),
                TomDataColumn(
                  label: TomText(tomId: 'dataTable.col.stock'),
                  numeric: true,
                  onSort: (i, asc) => _sortData(i, asc),
                ),
                TomDataColumn(label: TomText(tomId: 'dataTable.col.status')),
              ],
              rows: _products.take(5).map((p) {
                final isSelected = _selectedRows.contains(p.id);
                return TomDataRow(
                  selected: isSelected,
                  onSelectChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedRows.add(p.id);
                      } else {
                        _selectedRows.remove(p.id);
                      }
                    });
                  },
                  cells: [
                    TomDataCell(child: TomText(text: '${p.id}')),
                    TomDataCell(child: TomText(text: p.name)),
                    TomDataCell(child: TomChip(label: Text(p.category))),
                    TomDataCell(
                      child: TomText(
                        text: '\$${p.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TomDataCell(child: TomText(text: '${p.stock}')),
                    TomDataCell(
                      child: p.inStock
                          ? Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                              size: 20,
                            )
                          : Icon(
                              Icons.cancel,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: TomPaginatedDataTable
  // ===========================================================================

  Widget _buildPaginatedTableSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'paginatedTable',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'paginatedTable.infoLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 16),
          TomPaginatedDataTable(
            tomId: 'paginatedTable.table',
            header: TomText(
              tomId: 'paginatedTable.header',
              style: theme.textTheme.titleMedium,
            ),
            actions: [
              TomIconButton(
                tooltip: 'Refresh data',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _initSampleData();
                    _productDataSource = _ProductDataSource(_products);
                  });
                },
              ),
            ],
            rowsPerPage: _rowsPerPage,
            availableRowsPerPage: const [5, 10],
            onRowsPerPageChanged: (value) {
              if (value != null) {
                setState(() => _rowsPerPage = value);
              }
            },
            showFirstLastButtons: true,
            columns: [
              TomDataColumn(
                label: TomText(tomId: 'paginatedTable.col.id'),
                numeric: true,
              ),
              TomDataColumn(label: TomText(tomId: 'paginatedTable.col.name')),
              TomDataColumn(
                label: TomText(tomId: 'paginatedTable.col.category'),
              ),
              TomDataColumn(
                label: TomText(tomId: 'paginatedTable.col.price'),
                numeric: true,
              ),
            ],
            source: _productDataSource,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: TomTable
  // ===========================================================================

  Widget _buildTableSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'table',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'table.infoLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 16),
          TomTable(
            tomId: 'table.layout',
            border: TableBorder.all(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                children: [
                  _tableCell(context, 'Feature', isHeader: true),
                  _tableCell(context, 'Basic', isHeader: true),
                  _tableCell(context, 'Pro', isHeader: true),
                  _tableCell(context, 'Enterprise', isHeader: true),
                ],
              ),
              // Data rows
              TableRow(
                children: [
                  _tableCell(context, 'Users'),
                  _tableCell(context, '1'),
                  _tableCell(context, '10'),
                  _tableCell(context, 'Unlimited'),
                ],
              ),
              TableRow(
                children: [
                  _tableCell(context, 'Storage'),
                  _tableCell(context, '5 GB'),
                  _tableCell(context, '100 GB'),
                  _tableCell(context, '1 TB'),
                ],
              ),
              TableRow(
                children: [
                  _tableCell(context, 'Support'),
                  _tableCell(context, 'Email'),
                  _tableCell(context, 'Priority'),
                  _tableCell(context, '24/7'),
                ],
              ),
              TableRow(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                children: [
                  _tableCell(context, 'Price/month'),
                  _tableCell(context, '\$9'),
                  _tableCell(context, '\$29'),
                  _tableCell(context, '\$99'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableCell(
    BuildContext context,
    String text, {
    bool isHeader = false,
  }) {
    return TomPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TomText(
        text: text,
        style: isHeader
            ? Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
            : Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  // ===========================================================================
  // Section 4: TomGridView
  // ===========================================================================

  Widget _buildGridViewSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'gridView',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomRow(
            children: [
              TomText(
                tomId: 'gridView.columnsLabel',
                style: theme.textTheme.bodyMedium,
              ),
              TomSizedBox(width: 16),
              TomSegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 4, label: Text('4')),
                ],
                selected: {_gridCrossAxisCount},
                onSelectionChanged: (v) =>
                    setState(() => _gridCrossAxisCount = v.first),
              ),
            ],
          ),
          TomSizedBox(height: 16),
          TomContainer(
            height: 300,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomGridView(
              tomId: 'gridView.grid',
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridCrossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) => _GridItem(
                  index: index,
                  color: Colors.primaries[index % Colors.primaries.length],
                ),
                childCount: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: TomReorderableListView / ACL
  // ===========================================================================

  Widget _buildReorderableListSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'reorderable',
      child: AclBuilder()
          // Row 1: Info text
          .append(
            TomText(
              tomId: 'reorderable.infoLabel',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
          .expandX()
          .newRow(dist: 12)
          // Row 2: Reorderable list
          .append(
            TomContainer(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.hardEdge,
              child: TomReorderableListView(
                tomId: 'reorderable.list',
                padding: const EdgeInsets.all(8),
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final item = _reorderableItems.removeAt(oldIndex);
                    _reorderableItems.insert(newIndex, item);
                  });
                },
                children: [
                  for (int i = 0; i < _reorderableItems.length; i++)
                    _ReorderableItem(
                      key: ValueKey(_reorderableItems[i]),
                      title: _reorderableItems[i],
                      index: i,
                    ),
                ],
              ),
            ),
          )
          .expandX()
          .newRow(dist: 12)
          // Row 3: Current order display
          .append(
            TomContainer(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TomText(
                text: 'Order: ${_reorderableItems.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          )
          .expandX()
          .newRow(dist: 12)
          // Row 4: Reset button
          .append(
            TomTextButton(
              tomId: 'reorderable.reset',
              onPressed: () {
                setState(() {
                  _reorderableItems = List.generate(8, (i) => 'Item ${i + 1}');
                });
              },
            ),
          )
          .build(),
    );
  }
}

// =============================================================================
// Data Models
// =============================================================================

class _Product {
  final int id;
  final String name;
  final String category;
  final double price;
  final int stock;
  final bool inStock;

  _Product(
    this.id,
    this.name,
    this.category,
    this.price,
    this.stock,
    this.inStock,
  );
}

class _ProductDataSource extends DataTableSource {
  final List<_Product> _products;

  _ProductDataSource(this._products);

  @override
  DataRow getRow(int index) {
    final p = _products[index];
    return DataRow(
      cells: [
        DataCell(Text('${p.id}')),
        DataCell(Text(p.name)),
        DataCell(Text(p.category)),
        DataCell(Text('\$${p.price.toStringAsFixed(2)}')),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _products.length;

  @override
  int get selectedRowCount => 0;
}

// =============================================================================
// Helper Widgets
// =============================================================================

class _GridItem extends TomStatelessWidget {
  final int index;
  final Color color;

  _GridItem({required this.index, required this.color});

  @override
  Widget buildContent(BuildContext context) {
    return TomCard(
      elevation: 2,
      color: color.withValues(alpha: 0.2),
      child: TomCenter(
        child: TomColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view, color: color),
            TomSizedBox(height: 4),
            TomText(
              text: 'Grid ${index + 1}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReorderableItem extends TomStatelessWidget {
  final String title;
  final int index;

  _ReorderableItem({super.key, required this.title, required this.index});

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: TomListTile(
        titleText: title,
        leading: CircleAvatar(
          backgroundColor: Colors.primaries[index % Colors.primaries.length],
          child: TomText(
            text: '${index + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        subtitle: TomText(text: 'Drag to reorder'),
        trailing: Icon(
          Icons.drag_handle,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Section header widget for demo sections.
class _SectionHeader extends TomStatelessWidget {
  final String tomId;

  _SectionHeader({required this.tomId});

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

  _DemoCard({required this.tomId, required this.child});

  @override
  Widget buildContent(BuildContext context) {
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
                    tomId: tomId,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                TomSizedBox(width: 12),
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
            TomSizedBox(height: 16),
            TomDivider(color: theme.colorScheme.outlineVariant),
            TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}

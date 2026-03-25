/// Comprehensive Tables Demo
///
/// This demo showcases DataTable, Table, PaginatedDataTable,
/// and various table customization options.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main tables demo screen.
class TablesDemo extends StatelessWidget {
  const TablesDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'DataTable',
          subtitle: 'Material design data tables',
        ),
        _DataTableSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Sortable DataTable',
          subtitle: 'Tables with column sorting',
        ),
        _SortableDataTableSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Selectable DataTable',
          subtitle: 'Tables with row selection',
        ),
        _SelectableDataTableSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'PaginatedDataTable',
          subtitle: 'Tables with pagination',
        ),
        _PaginatedDataTableSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Table Widget',
          subtitle: 'Low-level table layout',
        ),
        _TableWidgetSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Styled Tables',
          subtitle: 'Custom table styling',
        ),
        _StyledTablesSection(),
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
// DataTable Section
// =============================================================================

class _DataTableSection extends StatelessWidget {
  const _DataTableSection();

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TomText(
              'Basic DataTable',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            const TomText(
              'Standard data table with columns and rows.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
            TomSingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TomDataTable(
                columns: [
                  TomDataColumn(tomId: 'id', label: TomText('ID')),
                  TomDataColumn(tomId: 'name', label: TomText('Name')),
                  TomDataColumn(tomId: 'email', label: TomText('Email')),
                  TomDataColumn(tomId: 'role', label: TomText('Role'), numeric: true),
                ],
                rows: [
                  TomDataRow(
                    tomId: 'user.1',
                    cells: [
                      TomDataCell(tomId: 'id', child: TomText('1')),
                      TomDataCell(tomId: 'name', child: TomText('John Doe')),
                      TomDataCell(tomId: 'email', child: TomText('john@example.com')),
                      TomDataCell(tomId: 'role', child: TomText('Admin')),
                    ],
                  ),
                  TomDataRow(
                    tomId: 'user.2',
                    cells: [
                      TomDataCell(tomId: 'id', child: TomText('2')),
                      TomDataCell(tomId: 'name', child: TomText('Jane Smith')),
                      TomDataCell(tomId: 'email', child: TomText('jane@example.com')),
                      TomDataCell(tomId: 'role', child: TomText('Editor')),
                    ],
                  ),
                  TomDataRow(
                    tomId: 'user.3',
                    cells: [
                      TomDataCell(tomId: 'id', child: TomText('3')),
                      TomDataCell(tomId: 'name', child: TomText('Bob Wilson')),
                      TomDataCell(tomId: 'email', child: TomText('bob@example.com')),
                      TomDataCell(tomId: 'role', child: TomText('Viewer')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sortable DataTable Section
// =============================================================================

class _SortableDataTableSection extends StatefulWidget {
  const _SortableDataTableSection();

  @override
  State<_SortableDataTableSection> createState() =>
      _SortableDataTableSectionState();
}

class _SortableDataTableSectionState extends State<_SortableDataTableSection> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  final List<Map<String, dynamic>> _data = [
    {'id': 1, 'name': 'Alice', 'sales': 1250, 'region': 'North'},
    {'id': 2, 'name': 'Bob', 'sales': 980, 'region': 'South'},
    {'id': 3, 'name': 'Charlie', 'sales': 2100, 'region': 'East'},
    {'id': 4, 'name': 'Diana', 'sales': 1800, 'region': 'West'},
    {'id': 5, 'name': 'Eve', 'sales': 750, 'region': 'North'},
  ];

  void _sort<T>(
    Comparable<T> Function(Map<String, dynamic>) getField,
    int columnIndex,
    bool ascending,
  ) {
    _data.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TomText(
              'Click column headers to sort',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
            TomSingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TomDataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  TomDataColumn(
                    tomId: 'id',
                    label: const TomText('ID'),
                    numeric: true,
                    onSort: (i, asc) => _sort((d) => d['id'] as int, i, asc),
                  ),
                  TomDataColumn(
                    tomId: 'name',
                    label: const TomText('Name'),
                    onSort:
                        (i, asc) => _sort((d) => d['name'] as String, i, asc),
                  ),
                  TomDataColumn(
                    tomId: 'sales',
                    label: const TomText('Sales'),
                    numeric: true,
                    onSort: (i, asc) => _sort((d) => d['sales'] as int, i, asc),
                  ),
                  TomDataColumn(
                    tomId: 'region',
                    label: const TomText('Region'),
                    onSort:
                        (i, asc) => _sort((d) => d['region'] as String, i, asc),
                  ),
                ],
                rows:
                    _data.map((item) {
                      return TomDataRow(
                        tomId: 'sales.${item['id']}',
                        cells: [
                          TomDataCell(tomId: 'id', child: TomText('${item['id']}')),
                          TomDataCell(tomId: 'name', child: TomText(item['name'])),
                          TomDataCell(tomId: 'sales', child: TomText('\$${item['sales']}')),
                          TomDataCell(tomId: 'region', child: TomText(item['region'])),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Selectable DataTable Section
// =============================================================================

class _SelectableDataTableSection extends StatefulWidget {
  const _SelectableDataTableSection();

  @override
  State<_SelectableDataTableSection> createState() =>
      _SelectableDataTableSectionState();
}

class _SelectableDataTableSectionState
    extends State<_SelectableDataTableSection> {
  final Set<int> _selectedIds = {};

  final List<Map<String, dynamic>> _data = [
    {'id': 1, 'product': 'Laptop', 'price': 999.99, 'stock': 25},
    {'id': 2, 'product': 'Mouse', 'price': 29.99, 'stock': 150},
    {'id': 3, 'product': 'Keyboard', 'price': 79.99, 'stock': 80},
    {'id': 4, 'product': 'Monitor', 'price': 349.99, 'stock': 42},
    {'id': 5, 'product': 'Headphones', 'price': 149.99, 'stock': 60},
  ];

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                TomText(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const TomSpacer(),
                if (_selectedIds.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedIds.clear()),
                    icon: const TomIcon(Icons.clear, size: 16),
                    label: const TomText('Clear'),
                  ),
              ],
            ),
            const TomSizedBox(height: 12),
            TomSingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TomDataTable(
                showCheckboxColumn: true,
                columns: [
                  TomDataColumn(tomId: 'product', label: TomText('Product')),
                  TomDataColumn(tomId: 'price', label: TomText('Price'), numeric: true),
                  TomDataColumn(tomId: 'stock', label: TomText('Stock'), numeric: true),
                  TomDataColumn(tomId: 'actions', label: TomText('Actions')),
                ],
                rows:
                    _data.map((item) {
                      final id = item['id'] as int;
                      return TomDataRow(
                        tomId: 'product.$id',
                        selected: _selectedIds.contains(id),
                        onSelectChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedIds.add(id);
                            } else {
                              _selectedIds.remove(id);
                            }
                          });
                        },
                        cells: [
                          TomDataCell(tomId: 'product', child: TomText(item['product'])),
                          TomDataCell(tomId: 'price', child: TomText('\$${item['price']}')),
                          TomDataCell(tomId: 'stock', child: TomText('${item['stock']}')),
                          TomDataCell(
                            tomId: 'actions',
                            child: TomRow(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TomIconButton(
                                  icon: const TomIcon(Icons.edit, size: 18),
                                  onPressed: () {},
                                ),
                                TomIconButton(
                                  icon: const TomIcon(Icons.delete, size: 18),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PaginatedDataTable Section
// =============================================================================

class _PaginatedDataTableSection extends StatefulWidget {
  const _PaginatedDataTableSection();

  @override
  State<_PaginatedDataTableSection> createState() =>
      _PaginatedDataTableSectionState();
}

class _PaginatedDataTableSectionState
    extends State<_PaginatedDataTableSection> {
  int _rowsPerPage = 5;

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomSingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TomSizedBox(
                width: 600,
                child: TomPaginatedDataTable(
                  header: const TomText('Orders'),
                  actions: [
                    TomIconButton(
                      icon: const TomIcon(Icons.refresh),
                      onPressed: () {},
                    ),
                    TomIconButton(
                      icon: const TomIcon(Icons.download),
                      onPressed: () {},
                    ),
                  ],
                  columns: [
                    TomDataColumn(tomId: 'orderId', label: TomText('Order #')),
                    TomDataColumn(tomId: 'customer', label: TomText('Customer')),
                    TomDataColumn(tomId: 'date', label: TomText('Date')),
                    TomDataColumn(tomId: 'amount', label: TomText('Amount'), numeric: true),
                    TomDataColumn(tomId: 'status', label: TomText('Status')),
                  ],
                  source: _OrderDataSource(),
                  rowsPerPage: _rowsPerPage,
                  availableRowsPerPage: const [5, 10, 15],
                  onRowsPerPageChanged: (value) {
                    if (value != null) {
                      setState(() => _rowsPerPage = value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderDataSource extends DataTableSource {
  final List<Map<String, dynamic>> _orders = List.generate(50, (index) {
    return {
      'id': 'ORD-${1000 + index}',
      'customer': [
        'Alice',
        'Bob',
        'Charlie',
        'Diana',
        'Eve',
      ][index % 5],
      'date': '2024-${(index % 12 + 1).toString().padLeft(2, '0')}-${(index % 28 + 1).toString().padLeft(2, '0')}',
      'amount': (index + 1) * 25.99,
      'status': ['Pending', 'Shipped', 'Delivered'][index % 3],
    };
  });

  @override
  DataRow? getRow(int index) {
    if (index >= _orders.length) return null;
    final order = _orders[index];
    return TomDataRow(
      tomId: 'order.$index',
      cells: [
        TomDataCell(tomId: 'orderId', child: TomText(order['id'])),
        TomDataCell(tomId: 'customer', child: TomText(order['customer'])),
        TomDataCell(tomId: 'date', child: TomText(order['date'])),
        TomDataCell(tomId: 'amount', child: TomText('\$${(order['amount'] as double).toStringAsFixed(2)}')),
        TomDataCell(tomId: 'status', child: _buildStatusChip(order['status'])),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Pending':
        color = Colors.orange;
        break;
      case 'Shipped':
        color = Colors.blue;
        break;
      case 'Delivered':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return TomChip(
      label: TomText(status, style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _orders.length;

  @override
  int get selectedRowCount => 0;
}

// =============================================================================
// Table Widget Section
// =============================================================================

class _TableWidgetSection extends StatelessWidget {
  const _TableWidgetSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic Table',
          'Low-level Table widget for simple layouts.',
          TomTable(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey),
                children: [
                  TomPadding(
                    padding: EdgeInsets.all(8),
                    child: TomText(
                      'Header 1',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TomPadding(
                    padding: EdgeInsets.all(8),
                    child: TomText(
                      'Header 2',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TomPadding(
                    padding: EdgeInsets.all(8),
                    child: TomText(
                      'Header 3',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  TomPadding(padding: EdgeInsets.all(8), child: TomText('Row 1')),
                  TomPadding(
                    padding: EdgeInsets.all(8),
                    child: TomText('Extended content for row 1'),
                  ),
                  TomPadding(padding: EdgeInsets.all(8), child: TomText('Value 1')),
                ],
              ),
              TableRow(
                children: [
                  TomPadding(padding: EdgeInsets.all(8), child: TomText('Row 2')),
                  TomPadding(
                    padding: EdgeInsets.all(8),
                    child: TomText('Data for row 2'),
                  ),
                  TomPadding(padding: EdgeInsets.all(8), child: TomText('Value 2')),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Column Width Types',
          'Different column width specifications.',
          TomTable(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FixedColumnWidth(80),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
              3: IntrinsicColumnWidth(),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                children: [
                  TomPadding(
                    padding: EdgeInsets.all(8),
                    child: TomText(
                      'Fixed\n80px',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TomPadding(
                    padding: EdgeInsets.all(8),
                    child: TomText(
                      'Flex (2)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TomPadding(
                    padding: EdgeInsets.all(8),
                    child: TomText(
                      'Flex (1)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TomPadding(
                    padding: EdgeInsets.all(8),
                    child: TomText(
                      'Intrinsic',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const TableRow(
                children: [
                  TomPadding(padding: EdgeInsets.all(8), child: TomText('A')),
                  TomPadding(padding: EdgeInsets.all(8), child: TomText('Takes 2x space')),
                  TomPadding(padding: EdgeInsets.all(8), child: TomText('1x space')),
                  TomPadding(padding: EdgeInsets.all(8), child: TomText('Fits content')),
                ],
              ),
            ],
          ),
        ),
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
// Styled Tables Section
// =============================================================================

class _StyledTablesSection extends StatelessWidget {
  const _StyledTablesSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Striped Table',
          'Alternating row colors.',
          TomDataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            columns: [
              TomDataColumn(tomId: 'name', label: TomText('Name')),
              TomDataColumn(tomId: 'department', label: TomText('Department')),
              TomDataColumn(tomId: 'salary', label: TomText('Salary'), numeric: true),
            ],
            rows: List.generate(5, (index) {
              return TomDataRow(
                tomId: 'employee.$index',
                color: WidgetStateProperty.resolveWith((states) {
                  return index.isEven ? Colors.grey.withValues(alpha: 0.1) : null;
                }),
                cells: [
                  TomDataCell(tomId: 'name', child: TomText('Employee ${index + 1}')),
                  TomDataCell(
                    tomId: 'department',
                    child: TomText(
                      ['Engineering', 'Marketing', 'Sales', 'HR', 'Finance'][
                          index],
                    ),
                  ),
                  TomDataCell(tomId: 'salary', child: TomText('\$${50000 + index * 5000}')),
                ],
              );
            }),
          ),
        ),
        _buildDemoCard(
          'Hoverable Table',
          'Rows highlight on hover.',
          TomDataTable(
            columns: [
              TomDataColumn(tomId: 'item', label: TomText('Item')),
              TomDataColumn(tomId: 'quantity', label: TomText('Quantity'), numeric: true),
              TomDataColumn(tomId: 'price', label: TomText('Price'), numeric: true),
            ],
            rows: List.generate(4, (index) {
              return TomDataRow(
                tomId: 'product.$index',
                color: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1);
                  }
                  return null;
                }),
                cells: [
                  TomDataCell(tomId: 'item', child: TomText('Product ${index + 1}')),
                  TomDataCell(tomId: 'quantity', child: TomText('${(index + 1) * 5}')),
                  TomDataCell(tomId: 'price', child: TomText('\$${(index + 1) * 19.99}')),
                ],
              );
            }),
          ),
        ),
        _buildDemoCard(
          'Dense Table',
          'Compact table with less padding.',
          Theme(
            data: Theme.of(context).copyWith(
              dataTableTheme: DataTableThemeData(
                horizontalMargin: 8,
                columnSpacing: 16,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 36,
                headingRowHeight: 40,
              ),
            ),
            child: TomDataTable(
              columns: [
                TomDataColumn(tomId: 'code', label: TomText('Code')),
                TomDataColumn(tomId: 'item', label: TomText('Item')),
                TomDataColumn(tomId: 'qty', label: TomText('Qty'), numeric: true),
              ],
              rows: List.generate(6, (index) {
                return TomDataRow(
                  tomId: 'sku.$index',
                  cells: [
                    TomDataCell(tomId: 'code', child: TomText('SKU${1000 + index}')),
                    TomDataCell(tomId: 'item', child: TomText('Item ${index + 1}')),
                    TomDataCell(tomId: 'qty', child: TomText('${(index + 1) * 10}')),
                  ],
                );
              }),
            ),
          ),
        ),
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
            TomSingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

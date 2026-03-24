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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'DataTable',
          subtitle: 'Material design data tables',
        ),
        _DataTableSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Sortable DataTable',
          subtitle: 'Tables with column sorting',
        ),
        _SortableDataTableSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Selectable DataTable',
          subtitle: 'Tables with row selection',
        ),
        _SelectableDataTableSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'PaginatedDataTable',
          subtitle: 'Tables with pagination',
        ),
        _PaginatedDataTableSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Table Widget',
          subtitle: 'Low-level table layout',
        ),
        _TableWidgetSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Styled Tables',
          subtitle: 'Custom table styling',
        ),
        _StyledTablesSection(),
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
// DataTable Section
// =============================================================================

class _DataTableSection extends StatelessWidget {
  const _DataTableSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic DataTable',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Standard data table with columns and rows.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Role'), numeric: true),
                ],
                rows: const [
                  DataRow(
                    cells: [
                      DataCell(Text('1')),
                      DataCell(Text('John Doe')),
                      DataCell(Text('john@example.com')),
                      DataCell(Text('Admin')),
                    ],
                  ),
                  DataRow(
                    cells: [
                      DataCell(Text('2')),
                      DataCell(Text('Jane Smith')),
                      DataCell(Text('jane@example.com')),
                      DataCell(Text('Editor')),
                    ],
                  ),
                  DataRow(
                    cells: [
                      DataCell(Text('3')),
                      DataCell(Text('Bob Wilson')),
                      DataCell(Text('bob@example.com')),
                      DataCell(Text('Viewer')),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Click column headers to sort',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: const Text('ID'),
                    numeric: true,
                    onSort: (i, asc) => _sort((d) => d['id'] as int, i, asc),
                  ),
                  DataColumn(
                    label: const Text('Name'),
                    onSort:
                        (i, asc) => _sort((d) => d['name'] as String, i, asc),
                  ),
                  DataColumn(
                    label: const Text('Sales'),
                    numeric: true,
                    onSort: (i, asc) => _sort((d) => d['sales'] as int, i, asc),
                  ),
                  DataColumn(
                    label: const Text('Region'),
                    onSort:
                        (i, asc) => _sort((d) => d['region'] as String, i, asc),
                  ),
                ],
                rows:
                    _data.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text('${item['id']}')),
                          DataCell(Text(item['name'])),
                          DataCell(Text('\$${item['sales']}')),
                          DataCell(Text(item['region'])),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedIds.clear()),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: true,
                columns: const [
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Price'), numeric: true),
                  DataColumn(label: Text('Stock'), numeric: true),
                  DataColumn(label: Text('Actions')),
                ],
                rows:
                    _data.map((item) {
                      final id = item['id'] as int;
                      return DataRow(
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
                          DataCell(Text(item['product'])),
                          DataCell(Text('\$${item['price']}')),
                          DataCell(Text('${item['stock']}')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 600,
                child: PaginatedDataTable(
                  header: const Text('Orders'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () {},
                    ),
                  ],
                  columns: const [
                    DataColumn(label: Text('Order #')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Amount'), numeric: true),
                    DataColumn(label: Text('Status')),
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
    return DataRow(
      cells: [
        DataCell(Text(order['id'])),
        DataCell(Text(order['customer'])),
        DataCell(Text(order['date'])),
        DataCell(Text('\$${(order['amount'] as double).toStringAsFixed(2)}')),
        DataCell(_buildStatusChip(order['status'])),
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
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 10)),
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
    return Column(
      children: [
        _buildDemoCard(
          'Basic Table',
          'Low-level Table widget for simple layouts.',
          Table(
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
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Header 1',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Header 2',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
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
                  Padding(padding: EdgeInsets.all(8), child: Text('Row 1')),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Extended content for row 1'),
                  ),
                  Padding(padding: EdgeInsets.all(8), child: Text('Value 1')),
                ],
              ),
              TableRow(
                children: [
                  Padding(padding: EdgeInsets.all(8), child: Text('Row 2')),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Data for row 2'),
                  ),
                  Padding(padding: EdgeInsets.all(8), child: Text('Value 2')),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Column Width Types',
          'Different column width specifications.',
          Table(
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
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Fixed\n80px',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Flex (2)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Flex (1)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Intrinsic',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const TableRow(
                children: [
                  Padding(padding: EdgeInsets.all(8), child: Text('A')),
                  Padding(padding: EdgeInsets.all(8), child: Text('Takes 2x space')),
                  Padding(padding: EdgeInsets.all(8), child: Text('1x space')),
                  Padding(padding: EdgeInsets.all(8), child: Text('Fits content')),
                ],
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
            const SizedBox(height: 12),
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
    return Column(
      children: [
        _buildDemoCard(
          'Striped Table',
          'Alternating row colors.',
          DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Department')),
              DataColumn(label: Text('Salary'), numeric: true),
            ],
            rows: List.generate(5, (index) {
              return DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  return index.isEven ? Colors.grey.withValues(alpha: 0.1) : null;
                }),
                cells: [
                  DataCell(Text('Employee ${index + 1}')),
                  DataCell(
                    Text(
                      ['Engineering', 'Marketing', 'Sales', 'HR', 'Finance'][
                          index],
                    ),
                  ),
                  DataCell(Text('\$${50000 + index * 5000}')),
                ],
              );
            }),
          ),
        ),
        _buildDemoCard(
          'Hoverable Table',
          'Rows highlight on hover.',
          DataTable(
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Quantity'), numeric: true),
              DataColumn(label: Text('Price'), numeric: true),
            ],
            rows: List.generate(4, (index) {
              return DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1);
                  }
                  return null;
                }),
                cells: [
                  DataCell(Text('Product ${index + 1}')),
                  DataCell(Text('${(index + 1) * 5}')),
                  DataCell(Text('\$${(index + 1) * 19.99}')),
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
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Code')),
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Qty'), numeric: true),
              ],
              rows: List.generate(6, (index) {
                return DataRow(
                  cells: [
                    DataCell(Text('SKU${1000 + index}')),
                    DataCell(Text('Item ${index + 1}')),
                    DataCell(Text('${(index + 1) * 10}')),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

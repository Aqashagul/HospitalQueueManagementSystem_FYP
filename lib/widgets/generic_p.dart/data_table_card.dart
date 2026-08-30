import 'package:flutter/material.dart';
import 'package:queue_management_system/widgets/resuable/rounded_card.dart';

// Config for a single table column: its header label, its width ratio
// relative to the other columns, and a function that builds the cell
// widget for a given row item.
class TableColumn<T> {
  final String label;
  final int flex;
  final Widget Function(T item) cellBuilder;

  const TableColumn({
    required this.label,
    required this.flex,
    required this.cellBuilder,
  });
}

// Generic reusable table shell. <T> means it works with any row data
// type — each page supplies its own columns and cell-building logic.
class DataTableCard<T> extends StatelessWidget {
  final List<T> items;
  final List<TableColumn<T>> columns;
  final String emptyMessage;

  const DataTableCard({
    super.key,
    required this.items,
    required this.columns,
    this.emptyMessage = "No data available",
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow(),
          const Divider(height: 24),

          if (items.isEmpty)
            _buildEmptyState()
          else
            ...List.generate(items.length, (index) {
              final item = items[index];
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  _buildDataRow(item),
                  if (!isLast) const Divider(height: 24),
                ],
              );
            }),
        ],
      ),
    );
  }

  // Renders the header labels using each column's flex value.
  Widget _buildHeaderRow() {
    final TextStyle headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade600,
    );

    return Row(
      children: columns.map((col) {
        return Expanded(
          flex: col.flex,
          child: Text(col.label, style: headerStyle),
        );
      }).toList(),
    );
  }

  // Renders one row by calling each column's cellBuilder with this item.
  Widget _buildDataRow(T item) {
    return Row(
      children: columns.map((col) {
        return Expanded(flex: col.flex, child: col.cellBuilder(item));
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      ),
    );
  }
}
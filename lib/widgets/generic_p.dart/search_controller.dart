import 'package:flutter/foundation.dart';

// Generic reusable search controller. <T> means it works with any list
// item type — the caller supplies the matching logic via _filterLogic,
// so this class stays agnostic to what it's actually searching.
class GenericSearchController<T> extends ChangeNotifier {
  GenericSearchController({
    required List<T> items,
    required this._filterLogic,
  })  : _allItems = items,
        _filteredItems = items;

  // Full unfiltered source list.
  List<T> _allItems;
  // Given an item and the (lowercased) query, returns true if it's a match.
  final bool Function(T item, String query) _filterLogic;
  // Result of applying the current query to _allItems.
  List<T> _filteredItems;
  String _query = '';

  List<T> get filteredItems => _filteredItems;
  String get query => _query;

  // Re-filters the list against a new query and notifies listeners so
  // widgets rebuild with the updated results.
  void search(String query) {
    _query = query;
    _filteredItems = query.isEmpty
        ? _allItems
        : _allItems
            .where((item) => _filterLogic(item, query.toLowerCase()))
            .toList();
    notifyListeners();
  }

  // Call this whenever the source list changes (e.g. an item was added,
  // edited, or removed elsewhere) so search results stay in sync.
  void updateItems(List<T> items) {
    _allItems = items;
    search(_query);
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_lost_found/core/widgets/empty_state.dart';
import 'package:campus_lost_found/core/widgets/search_field.dart';
import 'package:campus_lost_found/features/found_items/presentation/widgets/found_item_card.dart';
import 'package:campus_lost_found/features/found_items/presentation/widgets/filter_chips.dart';
import 'package:campus_lost_found/features/found_items/domain/found_item.dart';
import 'package:campus_lost_found/providers/providers.dart';

class FoundItemsPage extends ConsumerStatefulWidget {
  const FoundItemsPage({super.key});

  @override
  ConsumerState<FoundItemsPage> createState() => _FoundItemsPageState();
}

class _FoundItemsPageState extends ConsumerState<FoundItemsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FoundItem> _getFilteredItems(List<FoundItem> allItems) {
    var filtered = allItems;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final query = _searchQuery.toLowerCase();
        return item.title.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            item.foundLocation.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered.where((item) => item.category == _selectedCategory).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(foundItemsProvider);
    final items = _getFilteredItems(allItems);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Found Items'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.tertiary,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SearchField(
                controller: _searchController,
                hintText: 'Search items...',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FilterChips(
              selectedCategory: _selectedCategory,
              onCategorySelected: (category) {
                setState(() {
                  _selectedCategory = category;
                });
              },
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: '🔍',
                title: 'No items found',
                subtitle: _searchQuery.isNotEmpty || _selectedCategory != null
                    ? 'Try adjusting your search or filters'
                    : 'No items have been reported yet',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  return FoundItemCard(
                    item: item,
                    onTap: () {
                      context.push('/item/${item.id}');
                    },
                  );
                },
                childCount: items.length,
              ),
            ),
        ],
      ),
    );
  }
}


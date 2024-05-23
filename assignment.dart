import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<dynamic> _products = [];
  Set<String> _categories = {};
  String? _selectedCategory;
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  ScrollController _scrollController = ScrollController();

  String _selectedSortOption = 'name'; // selected sort option mate
  Timer? _debounce; // timer mate

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(() {
      _debounceSearch(_searchController.text);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _fetchProducts(loadMore: true);
    }
  }

  Future<void> _fetchProducts({bool loadMore = false}) async {
    if (_isLoading || (!_hasMore && loadMore)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(
          'https://dummyjson.com/products?limit=10&skip=${(_currentPage - 1) * 10}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map &&
            data.containsKey('products') &&
            data['products'] is List) {
          final products = data['products'];
          final categories = products
              .map<String>((product) => product['category'] as String)
              .toSet();

          setState(() {
            if (loadMore) {
              _products.addAll(products);
            } else {
              _products = products;
            }
            _categories.addAll(categories);
            _hasMore = products.length == 10;
            if (_hasMore) {
              _currentPage++;
            }
          });
        } else {
          throw Exception('Products data format is invalid');
        }
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortProducts(String criterion) {
    setState(() {
      if (_sortBy == criterion) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = criterion;
        _sortAscending = true;
      }
    });
  }

  List<dynamic> _sortedProducts() {
    List<dynamic> sortedList = List.from(_products.where((product) {
      return (_selectedCategory == null ||
          product['category'] == _selectedCategory) &&
          (product['title'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
              product['description']
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()));
    }));
    sortedList.sort((a, b) {
      int comparison = 0;
      if (_sortBy == 'name') {
        comparison = a['title'].compareTo(b['title']);
      } else if (_sortBy == 'price') {
        comparison = a['price'].compareTo(b['price']);
      }
      return _sortAscending ? comparison : -comparison;
    });
    return sortedList;
  }

  void _debounceSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
          _currentPage = 1;
          _hasMore = true;
          _products.clear();
          _fetchProducts();
        });
      }
    });
  }

  void _showSortingOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  'Sort by Name',
                  style: TextStyle(
                    color: _selectedSortOption == 'name' ? Colors.blue : Colors.black,
                  ),
                ),
                onTap: () {
                  _sortProducts('name');
                  setState(() {
                    _selectedSortOption = 'name';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(
                  'Sort by Price',
                  style: TextStyle(
                    color: _selectedSortOption == 'price' ? Colors.blue : Colors.black,
                  ),
                ),
                onTap: () {
                  _sortProducts('price');
                  setState(() {
                    _selectedSortOption = 'price';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedProducts = _sortedProducts();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.0),
                  InkWell(
                    onTap: () {
                      _showSortingOptions(context);
                    },
                    child: Container(
                      padding: EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                      ),
                      child: Icon(Icons.sort),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              height: 50.0,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          'All',
                          style: TextStyle(color: _selectedCategory == null ? Colors.white : Colors.black),
                        ),
                        selected: _selectedCategory == null,
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedCategory = selected ? null : _selectedCategory;
                          });
                        },
                        selectedColor: Colors.black,
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0), // Circular shape
                        ),
                      ),
                    );
                  } else {
                    final category = _categories.elementAt(index - 1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ChoiceChip(
                        label: Text(category, style: TextStyle(color: _selectedCategory == category ? Colors.white : Colors.black)),
                        selected: _selectedCategory == category,
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedCategory = selected ? category : null;
                          });
                        },
                        selectedColor: Colors.black,
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0), // Circular shape
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Products',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: sortedProducts.isEmpty
                  ? Center(
                child: _isLoading ? CircularProgressIndicator() : Text('No products found.'),
              )
                  : ListView.builder(
                controller: _scrollController,
                itemCount: sortedProducts.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == sortedProducts.length) {
                    return Center(
                      child: _isLoading ? CircularProgressIndicator() : SizedBox(),
                    );
                  }
                  final product = sortedProducts[index];
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    padding: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      title: Text(product['title'], style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(product['description']),
                      trailing: Text('\$${product['price']}'),
                      leading: product['thumbnail'] != null
                          ? Image.network(
                        product['thumbnail'],
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return CircularProgressIndicator();
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.error);
                        },
                      )
                          : Icon(Icons.image),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}



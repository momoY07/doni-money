import 'package:flutter/material.dart';
import '../utils/i18n.dart';
import '../utils/category_store.dart';
import 'paywall_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final String language;
  final bool isPremium;
  const CategoriesScreen({super.key, required this.language, required this.isPremium});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<String> _customExpense = [];
  List<String> _customIncome = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _customExpense = CategoryStore.customExpense();
      _customIncome = CategoryStore.customIncome();
    });
  }

  Future<void> _add(bool isExpense) async {
    if (!widget.isPremium) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('add_category', widget.language)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t('category_name_hint', widget.language),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel', widget.language)),
          ),
          FilledButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isEmpty) return;
              Navigator.pop(ctx);
              if (isExpense) {
                await CategoryStore.addExpense(val);
              } else {
                await CategoryStore.addIncome(val);
              }
              _reload();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('category_saved', widget.language))),
              );
            },
            child: Text(t('save', widget.language)),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(bool isExpense, String cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete_entry_title', widget.language)),
        content: Text(cat),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel', widget.language)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('delete', widget.language)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (isExpense) {
      await CategoryStore.removeExpense(cat);
    } else {
      await CategoryStore.removeIncome(cat);
    }
    _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('category_deleted', widget.language))),
    );
  }

  Widget _buildTab(bool isExpense) {
    final defaults = isExpense
        ? CategoryStore.defaultExpenseCategories
        : CategoryStore.defaultIncomeCategories;
    final customs = isExpense ? _customExpense : _customIncome;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(t('default_categories', widget.language)),
        const SizedBox(height: 8),
        ...defaults.map(
          (c) => _CategoryTile(
            name: categoryText(c, widget.language),
            canDelete: false,
            onDelete: null,
          ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(t('custom_category_label', widget.language)),
        const SizedBox(height: 8),
        if (customs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              t('no_custom_categories', widget.language),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF75879A),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...customs.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CategoryTile(
                name: categoryText(c, widget.language),
                canDelete: true,
                onDelete: () => _remove(isExpense, c),
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _add(isExpense),
          icon: Icon(widget.isPremium ? Icons.add : Icons.lock_rounded),
          label: Text(widget.isPremium
              ? t('add_category', widget.language)
              : t('premium_locked_hint', widget.language)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('custom_categories', widget.language)),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: t('expense', widget.language)),
            Tab(text: t('income', widget.language)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildTab(true),
          _buildTab(false),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF75879A),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _CategoryTile({
    required this.name,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E4EE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF24364A),
              ),
            ),
          ),
          if (canDelete && onDelete != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFB4544A),
                size: 20,
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

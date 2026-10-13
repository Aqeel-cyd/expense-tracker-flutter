import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Change this to your own currency symbol, e.g. 'Rs. ' or '€'.
const String kCurrency = 'Rs. ';
final NumberFormat money = NumberFormat.currency(symbol: kCurrency);

void main() => runApp(const ExpenseApp());

// ─────────────────────────── MODELS ───────────────────────────

enum Category { food, transport, shopping, bills, health, entertainment, other }

extension CategoryX on Category {
  String get label => name[0].toUpperCase() + name.substring(1);

  Color get color => switch (this) {
    Category.food => const Color(0xFFF97316),
    Category.transport => const Color(0xFF3B82F6),
    Category.shopping => const Color(0xFFEC4899),
    Category.bills => const Color(0xFF8B5CF6),
    Category.health => const Color(0xFF10B981),
    Category.entertainment => const Color(0xFFEAB308),
    Category.other => const Color(0xFF64748B),
  };

  IconData get icon => switch (this) {
    Category.food => Icons.restaurant_rounded,
    Category.transport => Icons.directions_bus_rounded,
    Category.shopping => Icons.shopping_bag_rounded,
    Category.bills => Icons.receipt_long_rounded,
    Category.health => Icons.favorite_rounded,
    Category.entertainment => Icons.movie_rounded,
    Category.other => Icons.category_rounded,
  };
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final Category category;
  final DateTime date;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'category': category.name,
    'date': date.toIso8601String(),
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String,
    title: j['title'] as String,
    amount: (j['amount'] as num).toDouble(),
    category: Category.values.firstWhere(
      (c) => c.name == j['category'],
      orElse: () => Category.other,
    ),
    date: DateTime.parse(j['date'] as String),
  );
}

// ─────────────────────────── APP ───────────────────────────

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4F46E5),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _storeKey = 'expenses_v1';
  final List<Expense> _all = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── persistence (localStorage on web) ──
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _all.addAll(list.map((e) => Expense.fromJson(e as Map<String, dynamic>)));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storeKey,
      jsonEncode(_all.map((e) => e.toJson()).toList()),
    );
  }

  // ── actions ──
  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddExpenseSheet(),
    );
    if (result != null) {
      setState(() => _all.add(result));
      _save();
    }
  }

  void _delete(Expense e) {
    final index = _all.indexOf(e);
    setState(() => _all.remove(e));
    _save();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${e.title}"'),
          behavior: SnackBarBehavior.floating,
          width: 360,
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              setState(() => _all.insert(index, e));
              _save();
            },
          ),
        ),
      );
  }

  void _loadSample() {
    final now = DateTime.now();
    final samples = <(String, double, Category, int)>[
      ('Groceries', 54.20, Category.food, 0),
      ('Bus pass', 22.00, Category.transport, 0),
      ('Electricity bill', 78.90, Category.bills, 1),
      ('Cinema night', 18.50, Category.entertainment, 1),
      ('New headphones', 89.99, Category.shopping, 2),
      ('Lunch with friends', 27.40, Category.food, 3),
      ('Pharmacy', 16.75, Category.health, 4),
      ('Taxi', 12.30, Category.transport, 5),
      ('Internet bill', 35.00, Category.bills, 5),
      ('Coffee', 4.80, Category.food, 6),
    ];
    setState(() {
      for (final s in samples) {
        _all.add(
          Expense(
            id: '${DateTime.now().microsecondsSinceEpoch}-${s.$1}',
            title: s.$1,
            amount: s.$2,
            category: s.$3,
            date: DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: s.$4)),
          ),
        );
      }
    });
    _save();
  }

  // ── derived data ──
  List<Expense> get _monthExpenses {
    final list =
        _all
            .where(
              (e) => e.date.year == _month.year && e.date.month == _month.month,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  // ─────────────────────────── UI ───────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final expenses = _monthExpenses;
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final byCategory = <Category, double>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final topCategory = byCategory.isEmpty
        ? null
        : (byCategory.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
    final daysInScope = _isCurrentMonth
        ? DateTime.now().day
        : DateUtils.getDaysInMonth(_month.year, _month.month);
    final dailyAvg = total / daysInScope;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 24,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Expense Tracker',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: FilledButton.icon(
              onPressed: _openAddSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add expense'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 900;
                  final cardW = wide
                      ? (c.maxWidth - 48) / 4
                      : (c.maxWidth - 16) / 2;

                  final stats = Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _StatCard(
                        width: cardW,
                        icon: Icons.payments_rounded,
                        color: const Color(0xFF4F46E5),
                        label: 'Total spent',
                        value: money.format(total),
                      ),
                      _StatCard(
                        width: cardW,
                        icon: Icons.receipt_rounded,
                        color: const Color(0xFF0EA5E9),
                        label: 'Transactions',
                        value: '${expenses.length}',
                      ),
                      _StatCard(
                        width: cardW,
                        icon: Icons.today_rounded,
                        color: const Color(0xFF10B981),
                        label: 'Daily average',
                        value: money.format(dailyAvg),
                      ),
                      _StatCard(
                        width: cardW,
                        icon: topCategory?.icon ?? Icons.star_rounded,
                        color: topCategory?.color ?? const Color(0xFF64748B),
                        label: 'Top category',
                        value: topCategory?.label ?? '—',
                      ),
                    ],
                  );

                  final pie = _Panel(
                    child: _CategoryPie(byCategory: byCategory, total: total),
                  );
                  final bar = _Panel(child: _WeeklyBars(all: _all));
                  final list = _Panel(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: _TransactionList(
                      expenses: expenses,
                      onDelete: _delete,
                      onSample: _all.isEmpty ? _loadSample : null,
                    ),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MonthSwitcher(
                        month: _month,
                        onPrev: () => _shiftMonth(-1),
                        onNext: _isCurrentMonth ? null : () => _shiftMonth(1),
                      ),
                      const SizedBox(height: 20),
                      stats,
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: pie),
                            const SizedBox(width: 16),
                            Expanded(child: bar),
                          ],
                        )
                      else ...[
                        pie,
                        const SizedBox(height: 16),
                        bar,
                      ],
                      const SizedBox(height: 16),
                      list,
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── WIDGETS ───────────────────────────

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatCard({
    required this.width,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _Panel(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  const _MonthSwitcher({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              Text(
                'Track where your money goes',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        IconButton.outlined(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _CategoryPie extends StatelessWidget {
  final Map<Category, double> byCategory;
  final double total;
  const _CategoryPie({required this.byCategory, required this.total});

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spending by category',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const _EmptyChart(message: 'No expenses this month')
        else ...[
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 55,
                sections: [
                  for (final e in entries)
                    PieChartSectionData(
                      value: e.value,
                      color: e.key.color,
                      radius: 42,
                      title: '${(e.value / total * 100).round()}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final e in entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: e.key.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${e.key.label} · ${money.format(e.value)}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  final List<Expense> all;
  const _WeeklyBars({required this.all});

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final totals = days
        .map(
          (d) => all
              .where((e) => DateUtils.isSameDay(e.date, d))
              .fold<double>(0, (s, e) => s + e.amount),
        )
        .toList();
    final maxVal = totals.reduce((a, b) => a > b ? a : b);
    final hasData = maxVal > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last 7 days',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (!hasData)
          const _EmptyChart(message: 'No spending in the last 7 days')
        else
          SizedBox(
            height: 270,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.25,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, meta) {
                        if (v == meta.max) return const SizedBox.shrink();
                        return Text(
                          '$kCurrency${v.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) {
                        final d = days[v.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('E').format(d),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      money.format(rod.toY),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < 7; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: totals[i],
                          width: 22,
                          color: i == 6
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFA5B4FC),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<Expense> expenses;
  final void Function(Expense) onDelete;
  final VoidCallback? onSample;
  const _TransactionList({
    required this.expenses,
    required this.onDelete,
    this.onSample,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Transactions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        if (expenses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 44,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nothing here yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  if (onSample != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onSample,
                      child: const Text('Load sample data'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          for (final e in expenses)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onDelete(e),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: Colors.red.shade50,
                child: Icon(Icons.delete_rounded, color: Colors.red.shade400),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: CircleAvatar(
                  backgroundColor: e.category.color.withValues(alpha: 0.12),
                  child: Icon(
                    e.category.icon,
                    color: e.category.color,
                    size: 20,
                  ),
                ),
                title: Text(
                  e.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${e.category.label} · ${DateFormat('d MMM yyyy').format(e.date)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '-${money.format(e.amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () => onDelete(e),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

// ─────────────────────────── ADD SHEET ───────────────────────────

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  Category _category = Category.food;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Enter a title and a valid amount.');
      return;
    }
    Navigator.pop(
      context,
      Expense(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        category: _category,
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New expense',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '$kCurrency ',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in Category.values)
                      ChoiceChip(
                        avatar: Icon(
                          c.icon,
                          size: 16,
                          color: _category == c ? Colors.white : c.color,
                        ),
                        label: Text(c.label),
                        selected: _category == c,
                        selectedColor: c.color,
                        labelStyle: TextStyle(
                          color: _category == c ? Colors.white : null,
                        ),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Colors.red.shade600)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Save expense'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

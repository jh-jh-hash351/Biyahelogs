import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../models/log_entry.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/log_tile.dart';
import 'log_detail_screen.dart';
import 'log_form_screen.dart';

class RecentLogsScreen extends StatefulWidget {
  final Vehicle vehicle;

  const RecentLogsScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<RecentLogsScreen> createState() => _RecentLogsScreenState();
}

class _RecentLogsScreenState extends State<RecentLogsScreen> {
  final _db = DatabaseService.instance;

  static const int _pageSize = 15;

  List<LogEntry> _logs = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;
  String? _error;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant RecentLogsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicle.id != widget.vehicle.id) {
      _load();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasMore = true;
      _error = null;
    });
    try {
      final total = await _db.getLogCount(widget.vehicle.id);
      final logs = await _db.getLogsForVehiclePaged(
        widget.vehicle.id,
        offset: 0,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _totalCount = total;
        _loading = false;
        _hasMore = logs.length == _pageSize;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load logs. $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _db.getLogsForVehiclePaged(
        widget.vehicle.id,
        offset: _logs.length,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _logs = [..._logs, ...more];
        _loadingMore = false;
        _hasMore = more.length == _pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogFormScreen(
          vehicle: widget.vehicle,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openDetail(LogEntry log) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogDetailScreen(vehicle: widget.vehicle, log: log),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent logs',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              '${widget.vehicle.name} · ${_loading ? "..." : "$_totalCount ${_totalCount == 1 ? "entry" : "entries"}"}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add log'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return Center(
        child: LoadingAnimationWidget.beat(
          color: theme.colorScheme.primary,
          size: 44,
        ),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 44, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (_logs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: Icons.receipt_long,
            title: 'No biyahe logged yet',
            message:
                'Track fuel, oil changes, repairs, and other expenses for ${widget.vehicle.name}.',
            actionLabel: 'Add your first log',
            onAction: _openAdd,
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: _logs.length + 1, // +1 for infinite scroll footer
      itemBuilder: (context, index) {
        if (index < _logs.length) {
          final log = _logs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LogTile(
              log: log,
              fuelUnit: widget.vehicle.fuelUnit,
              onTap: () => _openDetail(log),
            ),
          );
        }

        // Footer at the bottom
        if (_loadingMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: LoadingAnimationWidget.beat(
                color: theme.colorScheme.primary,
                size: 32,
              ),
            ),
          );
        }

        if (!_hasMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'All logs loaded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

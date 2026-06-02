import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';
import 'package:simple_cached_future_builder/simple_cached_future_builder.dart';

/// Hive database used by [MyCustomCacheManager].
Box? database;

void main() async {
  await Hive.initFlutter();
  database = await Hive.openBox('database');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimpleCachedFutureBuilder Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _defaultManager = BasicCacheManager<String>();
  final _hiveManager = MyCustomCacheManager();

  /// Incremented by the Reload FAB — forces timed/no-cache rows to re-resolve.
  int _reloadKey = 0;

  /// Incremented by "Clear all" — forces ALL rows in that section to re-initialize.
  int _defaultClearKey = 0;
  int _hiveClearKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('SimpleCachedFutureBuilder'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _reloadKey++),
        icon: const Icon(Icons.refresh),
        label: const Text('Reload'),
        tooltip: 'Rebuild widget tree — cached rows serve instantly, '
            'uncached rows refetch',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoBanner(),
            const SizedBox(height: 16),
            _CacheSection(
              title: 'BasicCacheManager (default)',
              subtitle: 'In-memory — cleared on app restart',
              color: Colors.blue.shade50,
              manager: _defaultManager,
              tagPrefix: 'basic',
              reloadKey: _reloadKey,
              clearKey: _defaultClearKey,
              onClearAll: () => setState(() {
                _defaultManager.clearCache();
                _defaultClearKey++;
              }),
            ),
            const SizedBox(height: 16),
            _CacheSection(
              title: 'MyCustomCacheManager (Hive)',
              subtitle: 'Persistent — survives app restarts',
              color: Colors.green.shade50,
              manager: _hiveManager,
              tagPrefix: 'hive',
              reloadKey: _reloadKey,
              clearKey: _hiveClearKey,
              onClearAll: () => setState(() {
                _hiveManager.clearCache();
                _hiveClearKey++;
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Tap Reload to simulate a parent widget rebuild:\n'
          '  • Permanent rows serve cached data immediately — no spinner.\n'
          '  • Timed rows re-check the cache; new data appears after the 10 s timer expires.\n'
          '  • No-cache rows always show a spinner and fetch fresh data.\n'
          'Hive cache survives app restarts; BasicCacheManager is in-memory only.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// Displays one cache-manager section with three demo rows.
class _CacheSection extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color color;
  final CacheManager<String> manager;
  final String tagPrefix;
  final int reloadKey;
  final int clearKey;
  final VoidCallback onClearAll;

  const _CacheSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.manager,
    required this.tagPrefix,
    required this.reloadKey,
    required this.clearKey,
    required this.onClearAll,
  });

  @override
  State<_CacheSection> createState() => _CacheSectionState();
}

class _CacheSectionState extends State<_CacheSection> {
  /// Incremented when the permanent row's individual delete button is pressed,
  /// forcing that row to rebuild and refetch.
  int _permanentDeleteKey = 0;

  static Future<String> _fetch() =>
      get(Uri.parse('https://bored-api.appbrewery.com/random'))
          .then((r) => jsonDecode(r.body)['activity'] as String);

  @override
  Widget build(BuildContext context) {
    final timedCache = SimpleCache(
      tag: '${widget.tagPrefix}_timed',
      validFor: const Duration(seconds: 10),
    );
    final permanentCache =
        SimpleCache(tag: '${widget.tagPrefix}_permanent');

    return Card(
      color: widget.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // — Section header —
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(widget.subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onClearAll,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear all'),
                ),
              ],
            ),
            const Divider(),

            // Permanent — key changes on "Clear all" OR individual delete,
            // forcing the row to rebuild and refetch in both cases.
            _CacheRow(
              key: ValueKey(
                  '${widget.tagPrefix}_permanent_${widget.clearKey}_$_permanentDeleteKey'),
              label: 'Permanent',
              future: _fetch(),
              cache: permanentCache,
              manager: widget.manager,
              onDeleted: () => setState(() => _permanentDeleteKey++),
            ),
            const Divider(height: 8),

            // Timed — key changes on every Reload so the widget re-initializes
            // and re-checks whether the 10 s cache is still valid.
            _CacheRow(
              key: ValueKey(
                  '${widget.tagPrefix}_timed_${widget.reloadKey}_${widget.clearKey}'),
              label: 'Timed (10 s)',
              future: _fetch(),
              cache: timedCache,
              manager: widget.manager,
            ),
            const Divider(height: 8),

            // No cache — always re-fetches on Reload.
            _CacheRow(
              key: ValueKey(
                  '${widget.tagPrefix}_nocache_${widget.reloadKey}_${widget.clearKey}'),
              label: 'No cache',
              future: _fetch(),
              cache: null,
              manager: widget.manager,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single labelled row wrapping [SimpleCachedFutureBuilder].
class _CacheRow extends StatelessWidget {
  final String label;
  final Future<String> future;
  final SimpleCache? cache;
  final CacheManager<String> manager;
  final VoidCallback? onDeleted;

  const _CacheRow({
    super.key,
    required this.label,
    required this.future,
    required this.cache,
    required this.manager,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: SimpleCachedFutureBuilder<String>(
              future: future,
              builder: (context, activity) =>
                  Text(activity, style: Theme.of(context).textTheme.bodySmall),
              onLoadingWidget: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              onErrorWidget: (e) => const Icon(Icons.warning_amber, size: 16),
              cache: cache,
              cacheManager: cache != null ? manager : null,
            ),
          ),
          if (cache != null)
            _TimerWidget(
              cache: cache!,
              manager: manager,
              onDeleted: onDeleted,
            ),
        ],
      ),
    );
  }
}

/// Shows the remaining cache time and a delete button for a single entry.
class _TimerWidget extends StatelessWidget {
  final SimpleCache cache;
  final CacheManager<String> manager;
  final VoidCallback? onDeleted;

  const _TimerWidget({
    required this.cache,
    required this.manager,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: manager.stream(cache),
      builder: (context, snapshot) {
        final secs = snapshot.data?.inSeconds;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                secs != null && secs > 0 ? '${secs}s' : '',
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.right,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Remove this cache entry',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                manager.removeCache(cache);
                onDeleted?.call();
              },
            ),
          ],
        );
      },
    );
  }
}

/// Hive-backed [CacheManager] — values survive app restarts.
class MyCustomCacheManager extends CacheManager<String> {
  @override
  void clearCache() {
    super.clearCache();
    database?.clear();
  }

  @override
  Future<bool> exists(SimpleCache tag) async =>
      database?.containsKey(tag.tag) ?? false;

  @override
  void removeCache(SimpleCache tag) {
    super.removeCache(tag);
    database?.delete(tag.tag);
  }

  @override
  String retrieveCache(SimpleCache tag) =>
      database?.get(tag.tag, defaultValue: '');

  @override
  void storeCache(SimpleCache tag, String data) => database?.put(tag.tag, data);
}

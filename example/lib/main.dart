import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';
import 'package:simple_cached_future_builder/simple_cached_future_builder.dart';

/// A [Hive](https://pub.dev/packages/hive) database to store the cached values
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
      home: const MyHomePage(title: 'SimpleCachedFutureBuilder Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MyCustomCacheManager cacheManager = MyCustomCacheManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
          actions: [
            IconButton(
                tooltip: 'Clear all cache',
                onPressed: () {
                  cacheManager.clearCache();
                },
                icon: const Icon(Icons.clear_all))
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Reload',
          child: const Icon(Icons.refresh),
          onPressed: () => setState(() {}),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              futureBuilderForCache(SimpleCache(
                  tag: 'activitySuggestion',
                  // Allow new data to be fetched after 10 seconds
                  validFor: const Duration(seconds: 10))),
              futureBuilderForCache(
                  // Never fetch new data, keep the value after the first fetch
                  SimpleCache(tag: 'keepForEver')),
              // Always fetch new data
              futureBuilderForCache(null),
            ],
          ),
        ));
  }

  SimpleCachedFutureBuilder futureBuilderForCache(SimpleCache? simpleCache) =>
      SimpleCachedFutureBuilder<String>(
        // Required: A future value
        future: get(Uri.parse('https://www.boredapi.com/api/activity'))
            .then((value) => value.body),
        // Required: A function returning a widget from the data returned by the future method
        builder: (context, activityResponse) {
          var activityData = jsonDecode(activityResponse);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(activityData['activity']),
              if (simpleCache != null) cacheInfoWidget(simpleCache)
            ],
          );
        },
        // Optional: A widget to appear while the data is being fetched
        onLoadingWidget: const CircularProgressIndicator(),
        // Optional: A widget to appear if fetching the data fails or the value is `null`
        onErrorWidget: (error) => const Icon(Icons.warning),
        // Optional: Cache the value for a period of time.
        cache: simpleCache,
        // Optional: A manager to handle the cache, for instance to manually clear the cache or to cache it between sessions
        cacheManager: cacheManager,
      );

  /// Displays time left and adds a delete button for a specific cached item
  Widget cacheInfoWidget(SimpleCache simpleCache) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: StreamBuilder<Duration?>(
        stream: cacheManager.stream(simpleCache),
        builder: (context, snapshot) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                snapshot.data?.inSeconds != null
                    ? '${snapshot.data!.inSeconds} s'
                    : '   ',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              IconButton(
                  tooltip: 'Delete this cache',
                  onPressed: (snapshot.data?.inSeconds ?? 0) > 0
                      ? () {
                          cacheManager.removeCache(simpleCache);
                        }
                      : null,
                  icon: const Icon(Icons.delete))
            ],
          );
        },
      ),
    );
  }
}

/// An example implementation of a `CacheManager` using Hive.
class MyCustomCacheManager extends CacheManager<String> {
  @override
  void clearCache() {
    super.clearCache();
    database?.clear();
  }

  @override
  Future<bool> exists(SimpleCache tag) async {
    var exists = database?.containsKey(tag.tag) ?? false;
    return exists;
  }

  @override
  void removeCache(SimpleCache tag) {
    super.removeCache(tag);
    database?.delete(tag.tag);
  }

  @override
  String retrieveCache(SimpleCache tag) {
    return database?.get(tag.tag, defaultValue: '');
  }

  @override
  void storeCache(SimpleCache tag, String data) {
    database?.put(tag.tag, data);
  }
}

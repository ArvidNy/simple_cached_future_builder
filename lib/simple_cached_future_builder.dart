library simple_cached_future_builder;

// Flutter imports:
import 'dart:async';

import 'package:flutter/material.dart';

class SimpleCachedFutureBuilder<T> extends StatefulWidget {
  /// (Use `BasicCacheManager` if you do not want to create your own implementation.)
  final CacheManager _cacheManager;

  /// A simplified `FutureBuilder` with basic caching abilities.
  ///
  /// Created to avoid the need to check `if (snapshot.connectionState == ConnectionState.done && snapshot.hasData)`
  /// for each `FutureBuilder`.
  ///
  /// The data is returned in the `builder` method.
  ///
  /// Cache the data by providing a `SimpleCache`. The data is by default stored in a `Map` so use the feature sparsely
  /// or override `CacheManager` to implement your own way of caching the data.
  ///
  /// # Example
  /// ```
  /// SimpleCachedFutureBuilder<String>(
  /// future: get(Uri.parse('https://www.boredapi.com/api/activity'))
  ///         .then((value) => value.body), // Required: A future value
  /// builder: (context, activityResponse) {
  ///     var activityData = jsonDecode(activityResponse);
  ///     return Text(activityData['activity']);
  /// }, // Required: A function returning a widget from the data returned by the future method
  /// onLoadingWidget:
  ///     const CircularProgressIndicator(), // Optional: A widget to appear while the data is being fetched
  /// onErrorWidget: (error) => const Icon(Icons
  ///     .warning), // Optional: A widget to appear if fetching the data fails or the value is `null`
  /// cache: SimpleCache(
  ///     tag: 'activitySuggestion',
  ///     validFor: const Duration(
  ///         minutes:
  ///             3)), // Optional: Cache the value for a period of time.
  /// cacheManager:
  ///     MyCustomCacheManager(), // Optional: Create a custom manager for the cached data. See the full example code for an example with Hive.
  /// ```
  SimpleCachedFutureBuilder({
    Key? key,
    required this.future,
    required this.builder,
    this.onLoadingWidget,
    this.onErrorWidget,
    this.cache,
    CacheManager? cacheManager,
  })  : _cacheManager = cacheManager ?? _defaultCacheManager,
        super(key: key) {
    if (cache?.validFor != null) {
      _TimerManager.add(cache, _cacheManager);
    }
  }

  /// The future method to be processed.
  /// Must be a future value.
  ///
  /// Example
  /// ```
  /// SimpleCachedFutureBuilder(
  ///   future: get(Uri.parse('https://www.boredapi.com/api/activity)),
  /// );
  /// ```
  final Future<T> future;

  /// A method that returns the fetched data. Must return a widget.
  ///
  /// Example
  /// ```
  /// SimpleCachedFutureBuilder(
  ///   builder: (context, data) => Text(data)
  /// );
  /// ```
  final Widget Function(BuildContext, T) builder;

  /// The widget to be displayed while loading.
  ///
  /// Example
  /// ```
  /// SimpleCachedFutureBuilder(
  ///   onLoadingWidget: CircularProgressIndicator()
  /// );
  /// ```
  final Widget? onLoadingWidget;

  /// The widget to be displayed if the data returned `null`.
  ///
  /// Example
  /// ```
  /// SimpleCachedFutureBuilder(
  ///   onErrorWidget: (error) => Row(children: [Icon(Icons.alert),Text(error)])
  /// );
  /// ```
  final Widget Function(String error)? onErrorWidget;

  /// A cache tag to be used to cache the fetched data.
  ///
  /// If provided, the future method will only run once and the preceding times load the value from cache.
  ///
  /// To manually clear cache, pass your own `CacheManager` to the widget. (Tip: Use `BasicCacheManager` if you do not want to create your own implementation.)
  final SimpleCache? cache;

  @override
  State<SimpleCachedFutureBuilder<T>> createState() =>
      _SimpleCachedFutureBuilderState2<T>();
}

class _SimpleCachedFutureBuilderState2<T>
    extends State<SimpleCachedFutureBuilder<T>> {
  T? _futureValue;

  Future<T> get futureValue async {
    if (widget.cache != null &&
        await widget._cacheManager.exists(widget.cache!)) {
      return widget._cacheManager.retrieveCache(widget.cache!);
    } else if (widget.cache != null) {
      _futureValue = await widget.future;
      if (_futureValue != null) {
        widget._cacheManager.storeCache(widget.cache!, _futureValue!);
        return _futureValue!;
      }
    }
    return widget.future;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cache != null) {
      // Use cached data to build the widget
      return FutureBuilder(
          future: Future.value(widget._cacheManager.exists(widget.cache!)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              if (snapshot.data!) {
                return widget.builder(
                    context, widget._cacheManager.retrieveCache(widget.cache!));
              } else {
                return newFutureBuilder;
              }
            } else {
              return widget.onLoadingWidget ?? Container();
            }
          });
    } else {
      return newFutureBuilder;
    }
  }

  Widget get newFutureBuilder => FutureBuilder<T>(
      future: futureValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return widget.builder(context, snapshot.data as T);
        } else if (snapshot.connectionState == ConnectionState.done &&
            widget.onErrorWidget != null) {
          return widget.onErrorWidget!(snapshot.error.toString());
        } else {
          return widget.onLoadingWidget ?? Container();
        }
      });
}

class SimpleCache {
  /// The cache tag to identify the stored data
  String tag;

  /// An optional value for automatical deletion
  Duration? validFor;

  /// The creation date
  final DateTime _createdAt;

  /// The creation date
  DateTime get createdAt => _createdAt;

  /// Check if the stored data should be deleted
  bool get shouldBeDeleted => validFor != null
      ? _createdAt.add(validFor!).isBefore(DateTime.now())
      : false;

  /// Creates a new cache object. If `validFor` is supplied,
  /// the value will automatically be deleted/replaced after that time.
  SimpleCache({required this.tag, this.validFor}) : _createdAt = DateTime.now();
}

/// Statically handle timers to avoid restarting them on each build
class _TimerManager {
  /// All the timers
  static final Map<String, _StreamTimer?> _timers = {};

  /// Add a new timer if the value is not already there
  static add(SimpleCache? cache, CacheManager cacheManager) {
    if (cache == null) return;
    if (_timers[cache.tag] == null && cache.validFor != null) {
      _timers[cache.tag] = _StreamTimer(cache.validFor!, () {
        cacheManager.removeCache(cache);
        _timers[cache.tag] = null;
      });
    }
  }

  /// Remove all timers
  static clear() {
    for (var timer in _timers.entries) {
      timer.value?.cancel();
    }
    _timers.clear();
  }

  /// Remove a specific timer
  static remove(SimpleCache cache) {
    _timers[cache.tag]?.cancel();
    _timers[cache.tag] = null;
  }
}

/// A class used to listen to a timer as a stream
class _StreamTimer {
  Timer? timer;
  Duration? timeLeft;
  Duration startTime;
  _StreamTimer(this.startTime, void Function() callback) {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      timeLeft = Duration(seconds: startTime.inSeconds - t.tick);
      if (t.tick == startTime.inSeconds) {
        callback();
        t.cancel();
      }
    });
  }

  Stream<Duration?> stream() async* {
    int i = 0;
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      yield timeLeft;
      i++;
      if (i == startTime.inSeconds || (timeLeft?.inSeconds ?? 0) <= 0) break;
    }
  }

  void cancel() {
    timer?.cancel();
  }

  int? get tick => timer?.tick;
}

/// The base class for creating a cache manager
/// Can be used to create a custom chache manager, for example using [Hive](https://pub.dev/packages/hive) or other database options.
abstract class CacheManager<T> {
  /// Delete all stored cache
  @mustCallSuper
  void clearCache() {
    _TimerManager.clear();
  }

  /// Delete a specific cached value
  @mustCallSuper
  void removeCache(SimpleCache tag) {
    _TimerManager.remove(tag);
  }

  /// Get a cached value
  T? retrieveCache(SimpleCache tag);

  /// Store data to the cache value
  void storeCache(SimpleCache tag, T data);

  /// Check if there is data stored to the cache tag
  FutureOr<bool> exists(SimpleCache tag);

  Duration timeLeftFor(SimpleCache simpleCache) => Duration(
      seconds: (simpleCache.validFor?.inSeconds ?? 0) -
          (_TimerManager._timers[simpleCache]?.tick ?? 0));

  Stream<Duration?>? stream(SimpleCache simpleCache) =>
      _TimerManager._timers[simpleCache.tag]?.stream();
}

/// The default cache manager
final BasicCacheManager _defaultCacheManager = BasicCacheManager();

/// A basic cache manager storing the data in a `Map`.
/// Will only retain data during a session due to the nature of a Map variable.
///
/// This is the default manager, but you can use your own manager by overriding the `CacheManager` class.
class BasicCacheManager<T> extends CacheManager<T> {
  final Map<String, dynamic> _cacheManager = {};

  @override
  void clearCache() {
    super.clearCache();
    _cacheManager.clear();
  }

  @override
  bool exists(SimpleCache tag) {
    return _cacheManager[tag.tag] != null && !tag.shouldBeDeleted;
  }

  @override
  void removeCache(SimpleCache tag) {
    super.removeCache(tag);
    _cacheManager.remove(tag.tag);
  }

  @override
  T retrieveCache(SimpleCache tag) {
    return _cacheManager[tag.tag];
  }

  @override
  void storeCache(SimpleCache tag, T data) {
    _cacheManager[tag.tag] = data;
  }
}

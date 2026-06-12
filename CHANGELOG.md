## 0.1.2

* Fixed future being re-subscribed on every `build()` call — it is now stored in `initState`.
* Fixed nested `FutureBuilder` for cache-existence check that caused an unnecessary loading-widget frame on every rebuild.
* Fixed wrong map key in `CacheManager.timeLeftFor` (`_timers[simpleCache]` → `_timers[simpleCache.tag]`).
* Added `didUpdateWidget` override to re-resolve the future when the cache tag changes.
* Improved example app

## 0.1.1

* Update description.

## 0.1.0

* Initial development release.
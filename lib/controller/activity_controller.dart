// Copyright 2026 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// 学术活动 / 听报告登记 控制器。
// 结构与 ExamController 保持一致：signals + AsyncState + FetchResult。

import 'package:signals/signals.dart';
import 'package:watermeter/model/fetch_result.dart';
import 'package:watermeter/model/jzxxtj/activity_report.dart';
import 'package:watermeter/repository/ids_session/activity_session.dart';
import 'package:watermeter/repository/logger.dart';

class ActivityController {
  static final ActivityController i = ActivityController._();
  final session = ActivitySession();

  ActivityController._();

  final _lastValidReports =
      signal<FetchResult<List<ActivityReport>>?>(null);

  final activityStateSignal =
      signal<AsyncState<FetchResult<List<ActivityReport>>>>(
        const AsyncLoading(),
      );

  Future<void> reloadActivityReports() async {
    final previous = _lastValidReports.value;
    activityStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.getActivityReports();
      _lastValidReports.value = result;
      activityStateSignal.set(AsyncState.data(result), force: true);
    } catch (e, s) {
      activityStateSignal.value = AsyncState.error(e, s);
      log.handle(
        e,
        s,
        "[ActivityController][reloadActivityReports] Have issue",
      );
    }
  }

  late final reports = computed(
    () => _lastValidReports.value?.data ?? <ActivityReport>[],
  );

  late final hasValidReports = computed(
    () => _lastValidReports.value != null,
  );

  late final isFromCache = computed(
    () => _lastValidReports.value?.isCache ?? false,
  );

  late final fetchTime = computed<DateTime?>(
    () => _lastValidReports.value?.fetchTime,
  );

  late final cacheHintKey = computed<String?>(
    () => _lastValidReports.value?.hintKey,
  );

  /// 首页卡片用：是否有任何记录。
  late final hasAnyReport = computed(() => reports.value.isNotEmpty);
}

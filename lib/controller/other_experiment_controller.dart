// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'package:intl/intl.dart';
import 'package:signals/signals_flutter.dart';
import 'package:time/time.dart';
import 'package:watermeter/controller/global_timer_controller.dart';
import 'package:watermeter/model/fetch_result.dart';
import 'package:watermeter/model/home_arrangement.dart';
import 'package:watermeter/model/xidian_ids/experiment.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/ids_session/sysj_session.dart';

class OtherExperimentController {
  static final OtherExperimentController i = OtherExperimentController._();
  final session = SysjSession();

  OtherExperimentController._() {
    /// 其他实验系统（原西电实验室预约系统）已下架：先清掉历史缓存，
    /// 然后直接进入「空数据」终态（与 [PhysicsExperimentController] 同构）。
    ///
    /// `_lastValidOtherExperiment` 若留 null，会让 `hasValidOtherExperiment`
    /// 为 false，而 `experiment_window.dart:324` 在既非 error 也非 loading 时
    /// 会落到 `CircularProgressIndicator` —— 即永久转圈。
    session.deleteCache();
    final empty = FetchResult.fresh(
      fetchTime: DateTime.now(),
      data: <ExperimentData>[],
    );
    _lastValidOtherExperiment.value = empty;
    otherExperimentStateSignal.value = AsyncState.data(empty);
  }

  final _lastValidOtherExperiment = signal<FetchResult<List<ExperimentData>>?>(
    null,
  );
  final otherExperimentStateSignal =
      signal<AsyncState<FetchResult<List<ExperimentData>>>>(
        const AsyncLoading(),
      );

  Future<void> reloadOtherExperiment() async {
    final previous = _lastValidOtherExperiment.value;
    otherExperimentStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.getOtherExperimentData();
      _lastValidOtherExperiment.value = result;
      otherExperimentStateSignal.set(AsyncState.data(result), force: true);
    } catch (e, s) {
      otherExperimentStateSignal.value = AsyncState.error(e, s);
      log.handle(
        e,
        s,
        "[OtherExperimentController][reloadOtherExperiment] Have issue",
      );
    }
  }

  late final otherExperiments = computed(
    () => _lastValidOtherExperiment.value?.data ?? <ExperimentData>[],
  );

  late final hasValidOtherExperiment = computed(
    () => _lastValidOtherExperiment.value != null,
  );

  late final isOtherExperimentFromCache = computed(
    () => _lastValidOtherExperiment.value?.isCache ?? false,
  );

  late final otherExperimentFetchTime = computed<DateTime?>(
    () => _lastValidOtherExperiment.value?.fetchTime,
  );

  late final otherExperimentCacheHintKey = computed<String?>(
    () => _lastValidOtherExperiment.value?.hintKey,
  );

  late final hasOtherExperimentArrangement = computed(
    () => otherExperiments.value.isNotEmpty,
  );

  late final otherExperimentOfTodayComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value;
    DateFormat formatter = DateFormat(HomeArrangement.format);
    List<HomeArrangement> toReturn = [];

    for (var i = 0; i < otherExperiments.value.length; i++) {
      final experiment = otherExperiments.value[i];
      for (final timeRange in experiment.timeRanges) {
        if (!timeRange.$1.isAtSameDayAs(now)) continue;
        toReturn.add(
          HomeArrangement(
            name: experiment.name,
            place: experiment.classroom,
            teacher: experiment.teacher,
            colorIndex: i,
            startTimeStr: formatter.format(timeRange.$1),
            endTimeStr: formatter.format(timeRange.$2),
          ),
        );
      }
    }

    return toReturn;
  });

  late final otherExperimentOfTomorrowComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    DateFormat formatter = DateFormat(HomeArrangement.format);
    List<HomeArrangement> toReturn = [];

    for (var i = 0; i < otherExperiments.value.length; i++) {
      final experiment = otherExperiments.value[i];
      for (final timeRange in experiment.timeRanges) {
        if (!timeRange.$1.isAtSameDayAs(now)) continue;
        toReturn.add(
          HomeArrangement(
            name: experiment.name,
            place: experiment.classroom,
            teacher: experiment.teacher,
            colorIndex: i,
            startTimeStr: formatter.format(timeRange.$1),
            endTimeStr: formatter.format(timeRange.$2),
          ),
        );
      }
    }

    return toReturn;
  });

  late final isFinishedOtherExperimentComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    List<ExperimentData> toReturn = [];

    bool isQualified((DateTime, DateTime) timeRange) =>
        now.isAfter(timeRange.$2);

    for (var experiment in otherExperiments.value) {
      bool containsDoing = experiment.timeRanges.where(isQualified).isNotEmpty;
      if (!containsDoing) continue;
      ExperimentData toAdd = ExperimentData.from(experiment);
      toAdd.timeRanges.removeWhere((timeRange) => !isQualified(timeRange));
      toReturn.add(toAdd);
    }
    return toReturn;
  });

  late final isNotStartedOtherExperimentComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    List<ExperimentData> toReturn = [];

    bool isQualified((DateTime, DateTime) timeRange) =>
        now.isBefore(timeRange.$1);

    for (var experiment in otherExperiments.value) {
      bool containsDoing = experiment.timeRanges.where(isQualified).isNotEmpty;
      if (!containsDoing) continue;
      ExperimentData toAdd = ExperimentData.from(experiment);
      toAdd.timeRanges.removeWhere((timeRange) => !isQualified(timeRange));
      toReturn.add(toAdd);
    }

    return toReturn;
  });

  late final isDoingOtherExperimentComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    List<ExperimentData> toReturn = [];

    bool isQualified((DateTime, DateTime) timeRange) =>
        now.isAfter(timeRange.$1) && now.isBefore(timeRange.$2);

    for (var experiment in otherExperiments.value) {
      bool containsDoing = experiment.timeRanges.where(isQualified).isNotEmpty;
      if (!containsDoing) continue;
      ExperimentData toAdd = ExperimentData.from(experiment);
      toAdd.timeRanges.removeWhere((timeRange) => !isQualified(timeRange));
      toReturn.add(toAdd);
    }

    return toReturn;
  });
}

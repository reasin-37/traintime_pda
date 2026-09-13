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
import 'package:watermeter/repository/experiment_session/physics_experiment_session.dart';

class PhysicsExperimentController {
  final ExperimentSession session = ExperimentSession();
  static final PhysicsExperimentController i = PhysicsExperimentController._();

  PhysicsExperimentController._() {
    /// 物理实验系统（原西电 PhyEws）已下架：先清掉历史缓存，
    /// 然后直接进入「空数据」终态。
    ///
    /// 必须 seed 而非留 null：`experiment_window.dart:324` 的 `!hasAnyValidData`
    /// 分支在既非 error 也非 loading 时会落到 `CircularProgressIndicator`，
    /// 而 `_lastValidPhysicsExperiment` 为 null 会让 `hasValidPhysicsExperiment`
    /// 为 false —— 那就是永久转圈。
    ///
    /// 用 `FetchResult.fresh`（而非 `.cache`）可同时压掉
    /// 「缓存提示条」与「缓存失败提示条」两条 UI 分支。
    session.deleteCache();
    final empty = FetchResult.fresh(
      fetchTime: DateTime.now(),
      data: <ExperimentData>[],
    );
    _lastValidPhysicsExperiment.value = empty;
    physicsExperimentStateSignal.value = AsyncState.data(empty);
  }

  final _lastValidPhysicsExperiment =
      signal<FetchResult<List<ExperimentData>>?>(null);
  final physicsExperimentStateSignal =
      signal<AsyncState<FetchResult<List<ExperimentData>>>>(
        const AsyncLoading(),
      );

  Future<void> reloadPhysicsExperiment() async {
    final previous = _lastValidPhysicsExperiment.value;
    physicsExperimentStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.getData();
      _lastValidPhysicsExperiment.value = result;
      physicsExperimentStateSignal.set(AsyncState.data(result), force: true);
    } catch (e, s) {
      physicsExperimentStateSignal.value = AsyncState.error(e, s);
      log.handle(
        e,
        s,
        "[PhysicsExperimentController][reloadPhysicsExperiment] Have issue",
      );
    }
  }

  late final physicsExperiments = computed(
    () => _lastValidPhysicsExperiment.value?.data ?? <ExperimentData>[],
  );

  late final hasValidPhysicsExperiment = computed(
    () => _lastValidPhysicsExperiment.value != null,
  );

  late final isPhysicsExperimentFromCache = computed(
    () => _lastValidPhysicsExperiment.value?.isCache ?? false,
  );

  late final physicsExperimentFetchTime = computed<DateTime?>(
    () => _lastValidPhysicsExperiment.value?.fetchTime,
  );

  late final physicsExperimentCacheHintKey = computed<String?>(
    () => _lastValidPhysicsExperiment.value?.hintKey,
  );

  late final hasPhysicsExperimentArrangement = computed(
    () => physicsExperiments.value.isNotEmpty,
  );

  late final physicsExperimentOfTodayComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value;
    DateFormat formatter = DateFormat(HomeArrangement.format);
    List<HomeArrangement> toReturn = [];

    for (var i = 0; i < physicsExperiments.value.length; i++) {
      final experiment = physicsExperiments.value[i];
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

  late final physicsExperimentOfTomorrowComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    DateFormat formatter = DateFormat(HomeArrangement.format);
    List<HomeArrangement> toReturn = [];

    for (var i = 0; i < physicsExperiments.value.length; i++) {
      final experiment = physicsExperiments.value[i];
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

  late final isFinishedPhysicsExperimentComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    List<ExperimentData> toReturn = [];

    bool isQualified((DateTime, DateTime) timeRange) =>
        now.isAfter(timeRange.$2);

    for (var experiment in physicsExperiments.value) {
      bool containsDoing = experiment.timeRanges.where(isQualified).isNotEmpty;
      if (!containsDoing) continue;
      ExperimentData toAdd = ExperimentData.from(experiment);
      toAdd.timeRanges.removeWhere((timeRange) => !isQualified(timeRange));
      toReturn.add(toAdd);
    }

    return toReturn;
  });

  late final isNotStartedPhysicsExperimentComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    List<ExperimentData> toReturn = [];

    bool isQualified((DateTime, DateTime) timeRange) =>
        now.isBefore(timeRange.$1);

    for (var experiment in physicsExperiments.value) {
      bool containsDoing = experiment.timeRanges.where(isQualified).isNotEmpty;
      if (!containsDoing) continue;
      ExperimentData toAdd = ExperimentData.from(experiment);
      toAdd.timeRanges.removeWhere((timeRange) => !isQualified(timeRange));
      toReturn.add(toAdd);
    }

    return toReturn;
  });

  late final isDoingPhysicsExperimentComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    List<ExperimentData> toReturn = [];

    bool isQualified((DateTime, DateTime) timeRange) =>
        now.isAfter(timeRange.$1) && now.isBefore(timeRange.$2);

    for (var experiment in physicsExperiments.value) {
      bool containsDoing = experiment.timeRanges.where(isQualified).isNotEmpty;
      if (!containsDoing) continue;
      ExperimentData toAdd = ExperimentData.from(experiment);
      toAdd.timeRanges.removeWhere((timeRange) => !isQualified(timeRange));
      toReturn.add(toAdd);
    }

    return toReturn;
  });
}

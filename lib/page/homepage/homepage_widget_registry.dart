// Copyright 2026 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:watermeter/page/homepage/info_widget/library_card.dart';
import 'package:watermeter/page/homepage/info_widget/school_card_info_card.dart';
import 'package:watermeter/page/homepage/toolbox/activity_card.dart';
import 'package:watermeter/page/homepage/toolbox/empty_classroom_card.dart';
import 'package:watermeter/page/homepage/toolbox/exam_card.dart';
import 'package:watermeter/page/homepage/toolbox/score_card.dart';
import 'package:watermeter/repository/preference.dart' as prefs;

typedef HomepageWidgetBuilder =
    Widget Function(BuildContext context, bool editMode);

class HomepageWidgetEntry {
  final String id;
  final String titleKey;
  final HomepageWidgetBuilder builder;
  final bool Function()? visible;
  final int gridSpan;

  const HomepageWidgetEntry({
    required this.id,
    required this.titleKey,
    required this.builder,
    required this.gridSpan,
    this.visible,
  });
}

/// 主页卡片清单的取舍（本轮，用户指示）：
///
/// - **移除** `energy`（宿舍电费）：上科大目前水/电/网均不收费，且其数据源是
///   西电电控系统（`ignypt`/`xxcapp.xidian.edu.cn`）。
/// - **移除** `experiment`（实验信息）：即此前已清空网络依赖的物理实验模块
///   （`ExperimentWindow` → `PhysicsExperimentController`/`OtherExperimentController`，
///   现为空数据源），已无实际内容。
/// - **移除** `sport`（体育信息）：连西电 `tybjxgl.xidian.edu.cn`。
/// - **移除** `class_attendance`（考勤）、`schoolnet`（网络查询）：连西电系统。
/// - **保留** `library`（图书馆）、`schoolcard`（校园卡）两张**大卡片**：
///   虽当前数据源仍指向西电，但将来可能对接上科大对应系统，故暂时保留展示。
/// - **保留** `score`、`exam`、`activity` 三张小卡（均已适配）。
///   `empty_classroom`（空闲教室）小卡暂留，待改造为「空间预约」。
///
/// 注：被移除的条目只是**从注册表清单去掉**，其卡片组件、session、controller
/// **代码全部保留**（西电遗留接口按用户指示统一留到发布前再清理）。
const defaultAllOrder = [
  'library',
  'schoolcard',
  'score',
  'exam',
  'activity',
  'empty_classroom',
];

final homepageRegistry = <HomepageWidgetEntry>[
  // ---- 大卡片 ----
  // 注：工厂已移除 `energy`（宿舍电费）——上科大目前水/电/网均不收费，
  // 且其数据源是西电电控系统（`ignypt`/`xxcapp.xidian.edu.cn`）。
  // `library` 与 `schoolcard` 暂时保留展示（将来可能对接上科大对应系统）。
  HomepageWidgetEntry(
    id: 'library',
    titleKey: 'homepage.library_card.title',
    gridSpan: 4,
    builder: (_, _) => const LibraryCard(),
  ),
  HomepageWidgetEntry(
    id: 'schoolcard',
    titleKey: 'homepage.school_card_info_card.bill',
    gridSpan: 4,
    builder: (_, _) => SchoolCardInfoCard(),
  ),
  // ---- 小格子 ----
  HomepageWidgetEntry(
    id: 'score',
    titleKey: 'homepage.toolbox.score',
    gridSpan: 1,
    builder: (_, _) => const ScoreCard(),
  ),
  HomepageWidgetEntry(
    id: 'exam',
    titleKey: 'homepage.toolbox.exam',
    gridSpan: 1,
    builder: (_, _) => const ExamCard(),
  ),
  HomepageWidgetEntry(
    id: 'activity',
    titleKey: 'homepage.toolbox.activity',
    gridSpan: 1,
    builder: (_, _) => const ActivityCard(),
  ),
  HomepageWidgetEntry(
    id: 'empty_classroom',
    titleKey: 'homepage.toolbox.empty_classroom',
    gridSpan: 1,
    builder: (_, _) => const EmptyClassroomCard(),
  ),
];

// ---- 顺序读写 ----

List<String> _readOrder(prefs.Preference prefKey) {
  final raw = prefs.getString(prefKey);
  if (raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.cast<String>();
  } catch (_) {}
  return [];
}

List<HomepageWidgetEntry> getOrderedEntries() {
  List<String> saved = _readOrder(prefs.Preference.homepageAllOrder);
  if (saved.isEmpty) {
    final info = _readOrder(prefs.Preference.homepageInfoOrder);
    final small = _readOrder(prefs.Preference.homepageSmallOrder);
    saved = [...info, ...small];
  }
  if (saved.isEmpty) saved = defaultAllOrder;

  final map = {for (var e in homepageRegistry) e.id: e};
  final ordered = <HomepageWidgetEntry>[];
  for (final id in saved) {
    if (map.containsKey(id)) ordered.add(map.remove(id)!);
  }
  ordered.addAll(map.values);

  return ordered.where((e) => e.visible?.call() ?? true).toList();
}

Future<void> saveOrder(List<String> ids) async {
  await prefs.setString(prefs.Preference.homepageAllOrder, jsonEncode(ids));
}

// ---- 隐藏读写 ----

List<String> _readHiddenIds() {
  final raw = prefs.getString(prefs.Preference.homepageHiddenIds);
  if (raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.cast<String>();
  } catch (_) {}
  return [];
}

Future<void> _saveHiddenIds(List<String> ids) async {
  await prefs.setString(prefs.Preference.homepageHiddenIds, jsonEncode(ids));
}

/// 获取已隐藏的条目（从注册表中查，保证顺序和完整性）。
List<HomepageWidgetEntry> getHiddenEntries() {
  final hidden = _readHiddenIds();
  final map = {for (var e in homepageRegistry) e.id: e};
  return hidden
      .where((id) => map.containsKey(id))
      .map((id) => map[id]!)
      .toList();
}

/// 过滤掉已隐藏的条目。
List<HomepageWidgetEntry> filterHidden(List<HomepageWidgetEntry> entries) {
  final hidden = _readHiddenIds().toSet();
  return entries.where((e) => !hidden.contains(e.id)).toList();
}

/// 隐藏一张卡片。
Future<void> hideEntry(String id) async {
  final hidden = _readHiddenIds();
  if (!hidden.contains(id)) {
    hidden.add(id);
    await _saveHiddenIds(hidden);
  }
}

/// 取消隐藏一张卡片。
Future<void> unhideEntry(String id) async {
  final hidden = _readHiddenIds();
  if (hidden.remove(id)) {
    await _saveHiddenIds(hidden);
  }
}

/// 清除所有隐藏。
Future<void> clearHidden() async {
  await prefs.remove(prefs.Preference.homepageHiddenIds);
}

/// 重置为默认顺序并清除隐藏。
Future<void> resetAll() async {
  await prefs.remove(prefs.Preference.homepageAllOrder);
  await prefs.remove(prefs.Preference.homepageInfoOrder);
  await prefs.remove(prefs.Preference.homepageSmallOrder);
  await clearHidden();
}

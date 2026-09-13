// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:io';

import 'package:watermeter/bridge/save_to_groupid.g.dart';
import 'package:watermeter/model/fetch_result.dart';
import 'package:watermeter/model/xidian_ids/experiment.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/network_client.dart' show supportPath;
import 'package:watermeter/repository/preference.dart' as prefs;

/// For physics experiment
///
/// 物理实验（原西电 PhyEws 实验报告系统）已下架：
/// 上海科技大学没有对应系统，本类降级为「只负责清理历史缓存的空数据源」。
/// 模型（`ExperimentData`）、UI、课表渲染与小组件均不受影响，
/// 只是永远不会再被喂到实验数据。
class ExperimentSession {
  static const physicsExperimentCacheName = "PhysicsExperiment.json";
  static File physicsExperimentCacheFile = File(
    "${supportPath.path}/$physicsExperimentCacheName",
  );

  bool get isCacheExist => physicsExperimentCacheFile.existsSync();

  /// 清掉历史版本写入的实验缓存（本地文件 + iOS App Group 副本）。
  ///
  /// Android 侧 `clearWidgetFiles()` 会因 `Platform.isIOS` 早退，
  /// 所以这里的本地删除是 Android 清理旧缓存的唯一途径。
  void deleteCache() {
    if (physicsExperimentCacheFile.existsSync()) {
      physicsExperimentCacheFile.deleteSync();
    }
    if (!Platform.isIOS) return;
    unawaited(() async {
      try {
        await SaveToGroupIdSwiftApi().deleteFromGroupId(
          FileToGroupID(
            appid: prefs.appId,
            fileName: physicsExperimentCacheName,
            data: '', // ignored by the native side
          ),
        );
      } catch (e, s) {
        log.handle(e, s, "[ExperimentSession][deleteCache] iOS group delete");
      }
    }());
  }

  /// 不再有缓存，恒为 null。
  (DateTime, List<ExperimentData>)? getCache() => null;

  /// 恒返回空列表的新鲜结果：让 UI 走空态分支，而不是 loading 或 error 分支。
  Future<FetchResult<List<ExperimentData>>> getData() async =>
      FetchResult.fresh(fetchTime: DateTime.now(), data: <ExperimentData>[]);
}

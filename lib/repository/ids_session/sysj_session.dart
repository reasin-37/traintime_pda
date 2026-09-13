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

/// 其他实验（原西电实验室预约系统）已下架：
/// 上海科技大学没有对应系统，本类降级为「只负责清理历史缓存的空数据源」，
/// 与 [ExperimentSession] 写法对称。
///
/// 说明：此处不再 `extends IDSSession` —— 改造后不需要 `dio` /
/// `checkAndLogin` / `followIDSRedirects` 等认证链路，且全仓没有按
/// `IDSSession` 类型使用本类的代码。
class SysjSession {
  static const otherExperimentCacheName = "OtherExperiment.json";
  static File otherExperimentCacheFile = File(
    "${supportPath.path}/$otherExperimentCacheName",
  );

  bool get isCacheExist => otherExperimentCacheFile.existsSync();

  /// 清掉历史版本写入的其他实验缓存（本地文件 + iOS App Group 副本）。
  void deleteCache() {
    if (otherExperimentCacheFile.existsSync()) {
      otherExperimentCacheFile.deleteSync();
    }
    if (!Platform.isIOS) return;
    unawaited(() async {
      try {
        await SaveToGroupIdSwiftApi().deleteFromGroupId(
          FileToGroupID(
            appid: prefs.appId,
            fileName: otherExperimentCacheName,
            data: '', // ignored by the native side
          ),
        );
      } catch (e, s) {
        log.handle(e, s, "[SysjSession][deleteCache] iOS group delete");
      }
    }());
  }

  /// 不再有缓存，恒为 null。
  (DateTime, List<ExperimentData>)? getCache() => null;

  /// 恒返回空列表的新鲜结果：让 UI 走空态分支，而不是 loading 或 error 分支。
  Future<FetchResult<List<ExperimentData>>> getOtherExperimentData() async =>
      FetchResult.fresh(fetchTime: DateTime.now(), data: <ExperimentData>[]);
}

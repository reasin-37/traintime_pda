// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

// 校园卡控制器。
//
// 【本分支改动】原先指向西电的 `SchoolCardSession`（`v8scan.xidian.edu.cn` 一卡通），
// 在上海科技大学不可用。现已改为上海科技大学的
// `repository/shanghaitech/card_session.dart`（新开普服务大厅）。
//
// 保留 `moneyStateSignal` 的 `AsyncState<String>` 形态，使既有 UI 无需改动即可工作：
// 其值为**余额的可读文本**（元，两位小数，如 `8.50`），配合 i18n
// `homepage.school_card_info_card.balance` =「卡里 {amount} 元」使用。

import 'package:signals/signals.dart';
import 'package:watermeter/controller/card_controller.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/shanghaitech/card_session.dart';

class SchoolCardController {
  static final SchoolCardController i = SchoolCardController._();
  final session = CardSession();

  SchoolCardController._();

  /// 余额文本（元，两位小数）。保持 `AsyncState<String>` 形态以兼容既有 UI。
  final moneyStateSignal = signal<AsyncState<String>>(const AsyncLoading());

  Future<void> reloadOverview() async {
    log.info("[SchoolCardController] Ready to fetch school card overview.");
    final previous = moneyStateSignal.peek().value;
    moneyStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final idserial = CardController.i.idserial;
      if (idserial.isEmpty) {
        throw const CardSessionException('未登录或学号缺失，无法查询校园卡');
      }
      final result = await session.fetchAccount(idserial);
      final account = result.data;
      moneyStateSignal.set(AsyncState.data(account.balanceText), force: true);
    } catch (e, s) {
      moneyStateSignal.value = AsyncState.error(e, s);
      log.handle(e, s, "[SchoolCardController][reloadOverview] Have issue");
    }
  }
}

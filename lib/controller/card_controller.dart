// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0
//
// 上海科技大学一卡通控制器。
//
// 【设计】与项目既有控制器同构（`signals` + `AsyncState`），
// 参照 `controller/school_card_controller.dart` 与 `controller/activity_controller.dart`。
//
// 【学号来源】一卡通接口需要 `idserial`（学号）。项目在登录时把学号存进
// `Preference.idsAccount`（见 `page/login/login_window.dart` 与
// `ids_session/classtable_session.dart:204` 的 `'XH'` 用法），故直接复用。

import 'package:signals/signals.dart';
import 'package:watermeter/model/shanghaitech/card.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as pref;
import 'package:watermeter/repository/shanghaitech/card_session.dart';

class CardController {
  static final CardController i = CardController._();

  /// 允许注入 session 以便测试。
  final CardSession session;

  CardController._({CardSession? session}) : session = session ?? CardSession();

  /// 账户信息（余额等）。
  final accountStateSignal =
      signal<AsyncState<CardAccount>>(const AsyncLoading());

  /// 近期交易流水。
  final transactionsStateSignal =
      signal<AsyncState<CardTransactionPage>>(const AsyncLoading());

  /// 最近一次成功抓取的账户（用于缓存提示；不写盘）。
  CardAccount? _lastAccount;

  CardAccount? get lastAccount => _lastAccount;

  /// 当前学号（`idserial` 的来源）。
  String get idserial => pref.getString(pref.Preference.idsAccount).trim();

  /// 拉取账户信息。
  Future<void> reloadAccount() async {
    final id = idserial;
    if (id.isEmpty) {
      accountStateSignal.value = AsyncState.error(
        const CardSessionException('未登录或学号缺失，无法查询一卡通'),
        StackTrace.current,
      );
      return;
    }

    // 与 physics_experiment_controller 同构：有旧值则显示「刷新中」，否则「加载中」
    final previous = accountStateSignal.peek().value;
    accountStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.fetchAccount(id);
      final account = result.data;
      _lastAccount = account;
      accountStateSignal.set(AsyncState.data(account), force: true);
    } catch (e, s) {
      accountStateSignal.value = AsyncState.error(e, s);
      // ⚠️ 不要把账户对象放进日志（含余额/卡号），见 model/shanghaitech/card.dart 的 toString 说明
      log.handle(e, s, '[CardController][reloadAccount] Have issue');
    }
  }

  /// 拉取交易流水。[days] 为回溯天数（默认近 30 天）。
  Future<void> reloadTransactions({int days = 30}) async {
    final id = idserial;
    if (id.isEmpty) {
      transactionsStateSignal.value = AsyncState.error(
        const CardSessionException('未登录或学号缺失，无法查询一卡通'),
        StackTrace.current,
      );
      return;
    }

    final previous = transactionsStateSignal.peek().value;
    transactionsStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final end = DateTime.now();
      final start = end.subtract(Duration(days: days));
      final result = await session.fetchTransactions(
        id,
        startDate: _formatDate(start),
        endDate: _formatDate(end),
      );
      transactionsStateSignal.set(AsyncState.data(result.data), force: true);
    } catch (e, s) {
      transactionsStateSignal.value = AsyncState.error(e, s);
      log.handle(e, s, '[CardController][reloadTransactions] Have issue');
    }
  }

  /// 按**指定日期区间**拉取交易流水（校园卡页面选区间时用）。
  ///
  /// [startDate] / [endDate] 形如 `2026-09-06`（与接口实测格式一致）。
  Future<void> reloadTransactionsRange({
    required String startDate,
    required String endDate,
    int page = 0,
  }) async {
    final id = idserial;
    if (id.isEmpty) {
      transactionsStateSignal.value = AsyncState.error(
        const CardSessionException('未登录或学号缺失，无法查询一卡通'),
        StackTrace.current,
      );
      return;
    }

    final previous = transactionsStateSignal.peek().value;
    transactionsStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.fetchTransactions(
        id,
        startDate: startDate,
        endDate: endDate,
        page: page,
      );
      transactionsStateSignal.set(AsyncState.data(result.data), force: true);
    } catch (e, s) {
      transactionsStateSignal.value = AsyncState.error(e, s);
      log.handle(e, s, '[CardController][reloadTransactionsRange] Have issue');
    }
  }

  /// 一并刷新账户与流水。
  Future<void> reloadAll({int days = 30}) async {
    await Future.wait([
      reloadAccount(),
      reloadTransactions(days: days),
    ]);
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 供测试/调试查看日期格式。
  static String debugFormatDate(DateTime d) => _formatDate(d);
}

/// 便于测试注入的工厂（保持单例语义之外的可用性）。
CardController createCardController({CardSession? session}) =>
    CardController._(session: session);

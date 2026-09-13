// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0
//
// 上海科技大学一卡通（新开普 NewCapec 服务大厅）数据模型。
//
// 【设计纪律】只 import dart:*，**不 import Flutter**，以便在沙盒内离线断言
// （见 devkit/verify_card.dart）。
//
// 【依据】字段名全部取自真实解密后的响应，实测结构见
// devkit/fixtures/stc_card_samples.json（已脱敏，只留字段名与非敏感的示例值）。

/// 一卡通账户信息（来自 `POST /servicehall/business/getCardUserInfoByIdserial`）。
///
/// 实测响应形态：
/// ```json
/// {"message":"成功","success":true,
///  "resultData":{"accountinfo":{...},"cardinfos":[{...}],"checksimple":"0","pname":"…"}}
/// ```
///
/// ⚠️ **金额单位是「分」**（实测确认）：接口返回 `balance: 850`，
/// 而页面显示「8.5 元」。故本模型保留**原始分值**（字段名带 `Cents` 以示单位），
/// 用 [balanceYuan] 等 getter 换算成元，避免误当元使用（差 100 倍）。
class CardAccount {
  /// 账户状态（实测 `"1"` = 正常）。
  final String? accStatus;

  /// **当前余额（单位：分）**。实测 850 对应页面的 8.5 元。
  final int? balanceCents;

  /// 透支总额度（单位：分）。
  final int? overdraftTotalCents;

  /// 最后一次交易时间（字符串，形如 `2026-09-13 11:35:13`）。
  final String? lastTxDate;

  /// 账户创建时间。
  final String? createDate;

  const CardAccount({
    this.accStatus,
    this.balanceCents,
    this.overdraftTotalCents,
    this.lastTxDate,
    this.createDate,
  });

  /// 当前余额（单位：元）。拿不到时返回 `null`（**不猜**）。
  double? get balanceYuan =>
      balanceCents == null ? null : balanceCents! / 100.0;

  /// 透支总额度（单位：元）。
  double? get overdraftTotalYuan =>
      overdraftTotalCents == null ? null : overdraftTotalCents! / 100.0;

  /// 余额是否可用。
  bool get hasBalance => balanceCents != null;

  /// 余额的可读文本（如 `8.50`）。UI 可直接配合 i18n 的「卡里 {amount} 元」使用。
  String get balanceText =>
      balanceYuan == null ? '' : balanceYuan!.toStringAsFixed(2);

  /// ⚠️ **刻意覆写**：本对象含账户信息，一旦被 `log.info(account)` 或异常信息
  /// 打印出来就会泄露余额与卡号。故只输出非敏感摘要。
  @override
  String toString() =>
      'CardAccount(accStatus: $accStatus, balanceText: $balanceText, '
      'lastTxDate: $lastTxDate)';
}

/// 一张卡片的信息（`resultData.cardinfos[]` 的一项）。
///
/// ⚠️ 金额单位同为**分**（见 [CardAccount] 的说明）。
class CardInfo {
  /// 单笔消费限额（单位：分）。
  final int? maxConsumeAmountCents;

  /// 当日累计限额（单位：分）。
  final int? maxConsumeTotalAmountCents;

  /// 已消费金额（单位：分）。
  final int? consumedAmountCents;

  /// 信用额度（单位：分）。
  final int? lineCreditCents;

  /// 是否允许消费（实测 `"1"` = 允许）。
  final String? allowConsume;

  /// 卡有效期。
  final String? effectDate;

  const CardInfo({
    this.maxConsumeAmountCents,
    this.maxConsumeTotalAmountCents,
    this.consumedAmountCents,
    this.lineCreditCents,
    this.allowConsume,
    this.effectDate,
  });

  double? get maxConsumeAmountYuan => _yuan(maxConsumeAmountCents);
  double? get maxConsumeTotalAmountYuan => _yuan(maxConsumeTotalAmountCents);
  double? get consumedAmountYuan => _yuan(consumedAmountCents);
  double? get lineCreditYuan => _yuan(lineCreditCents);

  /// ⚠️ **刻意覆写**：只输出限额摘要，不打印卡的有效期等可用于识别的信息。
  @override
  String toString() => 'CardInfo(maxConsumeAmountYuan: $maxConsumeAmountYuan, '
      'consumedAmountYuan: $consumedAmountYuan, allowConsume: $allowConsume)';
}

/// 一笔交易（来自 `POST /servicehall/business/thirdQuerSelfTrade` 的 `resultData.rows[]`）。
///
/// 实测字段：`txcode`(交易码)、`txamt`(**金额，单位：分，负数为消费**)、
/// `summary`(摘要)、`txdate`(**毫秒时间戳**)、`balance`(交易后余额，单位：分)。
///
/// 实测例：`txamt: -1250` → **-12.50 元**（一笔 12.5 元的消费）。
class CardTransaction {
  /// 交易金额（单位：**分**），**负数为消费、正数为充值**。
  final int? amountCents;

  /// 交易摘要（如「离线码在线消费」）。
  final String? summary;

  /// 交易时间（由毫秒时间戳换算）。
  final DateTime? time;

  /// 交易后余额（单位：分）。
  final int? balanceAfterCents;

  /// 交易码。
  final String? txCode;

  const CardTransaction({
    this.amountCents,
    this.summary,
    this.time,
    this.balanceAfterCents,
    this.txCode,
  });

  /// 交易金额（单位：元，保留正负号）。
  double? get amountYuan => _yuan(amountCents);

  /// 交易后余额（单位：元）。
  double? get balanceAfterYuan => _yuan(balanceAfterCents);

  /// 是否为消费（金额为负）。
  bool get isSpend => (amountCents ?? 0) < 0;

  /// 消费金额的绝对值（单位：元，用于显示）。
  double get absAmountYuan => ((amountCents ?? 0).abs()) / 100.0;

  /// 金额的可读文本（元，两位小数，保留正负号）。
  String get amountText =>
      amountYuan == null ? '' : amountYuan!.toStringAsFixed(2);

  /// ⚠️ **刻意覆写**：只输出金额、摘要与时间；**不打印**交易后余额与流水号
  /// （那些可用于关联账户）。
  @override
  String toString() => 'CardTransaction(amountYuan: $amountText, '
      'summary: $summary, time: $time, txCode: $txCode)';
}

/// 分 → 元。
double? _yuan(int? cents) => cents == null ? null : cents / 100.0;

/// 交易流水分页结果。
class CardTransactionPage {
  /// 总条数。
  final int total;

  /// 总页数。
  final int totalPage;

  final List<CardTransaction> rows;

  const CardTransactionPage({
    required this.total,
    required this.totalPage,
    this.rows = const [],
  });

  static const CardTransactionPage empty = CardTransactionPage(
    total: 0,
    totalPage: 0,
  );
}

/// 字典项（来自 `POST /servicehall/business/queryCommon`，如 `{"names":"acctype"}`）。
///
/// 实测返回 `resultData.<names>` 为数组，元素形如
/// `{"acctypecode":"4","acctypename":"学生卡", …}`。
class CardDictionaryItem {
  final String? code;
  final String? name;

  const CardDictionaryItem({this.code, this.name});
}

/// 服务大厅响应的统一外壳。
///
/// 实测：**HTTP 200**，body 形如 `{"data":"<密文>"}`；
/// 解密后才是 `{"message":"成功","success":true,"resultData":{…}}`。
class CardEnvelope {
  /// 业务是否成功（`success == true`）。
  final bool success;

  /// 服务端消息（实测成功时为「成功」）。
  final String? message;

  /// 解密并解析后的 `resultData`。
  final Map<String, dynamic>? resultData;

  const CardEnvelope({
    required this.success,
    this.message,
    this.resultData,
  });

  /// ⚠️ **刻意覆写（重要）**：默认 `toString()` 会把 Map 递归打印，
  /// 而 [resultData] 是**整份解密后的响应**——含学号、身份证号、手机号、
  /// 银行卡号、余额与流水。任何 `log.info(envelope)`（包括异常栈里带对象）
  /// 都会把它写进日志。故这里只输出结构键名，绝不输出值。
  @override
  String toString() {
    final keys = resultData?.keys.toList() ?? const <String>[];
    return 'CardEnvelope(success: $success, message: $message, '
        'resultDataKeys: ${keys.length} 项$keys)';
  }
}

/// 一卡通解析/解密失败。
class CardDecryptException implements Exception {
  final String message;
  const CardDecryptException(this.message);
  @override
  String toString() => message;
}

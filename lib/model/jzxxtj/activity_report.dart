// Copyright 2026 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// 学术活动 / 听报告登记 的数据模型（上海科技大学 jzxxtjapp · tbgdj 模块）。
//
// 字段来源：金智 gsapp 的列元数据接口
//   POST /gsapp/sys/jzxxtjapp/modules/tbgdj/tbgdj_lbcx.do   （请求体 *searchMeta=1）
// 其中 controls 定义了：
//   WID 主键 / SHZT 审核状态 / TBLX 数据来源 / XNXQ 学年学期 / BGMC 报告名称 /
//   BGSJ 时间(yyyy-MM-dd) / BGDD 报告地点 / ZJR 主讲人 / XH 学号 /
//   SFSYYY 是否使用英语 / FJ 附件
//
// 说明：本文件刻意不依赖 Flutter，也不使用 json_serializable 代码生成，
// 以便用纯 Dart 离线跑解析断言（见 devkit/verify_activity.dart）。

/// 取字段值：优先用金智返回的 `<字段>_DISPLAY`（字典/显示值），
/// 没有则退回原始值。仓库中既有的 score_session 也是这个套路
/// （`XNXQDM_DISPLAY`、`CJGXKLBDM_DISPLAY` 等）。
String _value(Map<String, dynamic> json, String key) {
  final display = json['${key}_DISPLAY'];
  if (display != null && display.toString().isNotEmpty) {
    return display.toString();
  }
  final raw = json[key];
  return raw?.toString() ?? '';
}

/// 一条听报告登记记录。
class ActivityReport {
  /// WID 主键
  final String wid;

  /// XNXQ 学年学期
  final String semester;

  /// BGMC 报告名称
  final String name;

  /// BGSJ 时间（接口格式 `yyyy-MM-dd`）
  final String date;

  /// BGDD 报告地点
  final String place;

  /// ZJR 主讲人
  final String speaker;

  /// SHZT 审核状态（**原始代码**，网页端用它判断可否编辑：`SHZT == "0"`）
  final String statusCode;

  /// SHZT 的可读文本（若接口返回了 `SHZT_DISPLAY` 就用它，否则同 [statusCode]）
  final String statusText;

  /// SFSYYY 是否使用英语
  final String inEnglish;

  /// FJ 附件 token（用于附件预览）
  final String? attachment;

  /// TBLX 数据来源
  final String source;

  const ActivityReport({
    required this.wid,
    required this.semester,
    required this.name,
    required this.date,
    required this.place,
    required this.speaker,
    required this.statusCode,
    required this.statusText,
    required this.inEnglish,
    this.attachment,
    required this.source,
  });

  /// 网页端逻辑：`SHZT == "0"` 时才显示「删除」并允许提交/编辑。
  bool get isEditable => statusCode == '0';

  /// 网页端「附件查看」列的判定：`FJ != null` 才算已上传。
  bool get hasAttachment =>
      attachment != null &&
      attachment!.isNotEmpty &&
      attachment!.toLowerCase() != 'null';

  factory ActivityReport.fromJson(Map<String, dynamic> json) {
    return ActivityReport(
      wid: _value(json, 'WID'),
      semester: _value(json, 'XNXQ'),
      name: _value(json, 'BGMC'),
      date: _value(json, 'BGSJ'),
      place: _value(json, 'BGDD'),
      speaker: _value(json, 'ZJR'),
      // 注意：statusCode 必须取**原始值**，不能取 _DISPLAY
      statusCode: json['SHZT']?.toString() ?? '',
      statusText: _value(json, 'SHZT'),
      inEnglish: _value(json, 'SFSYYY'),
      attachment: json['FJ']?.toString(),
      source: _value(json, 'TBLX'),
    );
  }

  /// 解析列表接口的响应体。
  ///
  /// 响应形如：
  /// `{"code":"0","datas":{"tbgdj_lbcx":{"totalSize":0,"pageNumber":1,"pageSize":10,"rows":[]}}}`
  ///
  /// [code] 不是 `"0"` 时抛 [ActivityFetchException]。
  static List<ActivityReport> listFromResponse(Map<String, dynamic> body) {
    final code = body['code']?.toString() ?? '';
    if (code != '0') {
      throw ActivityFetchException(
        body['msg']?.toString() ?? '听报告登记查询失败（code=$code）',
      );
    }
    final datas = body['datas'];
    if (datas is! Map) return const [];
    final page = datas['tbgdj_lbcx'];
    if (page is! Map) return const [];
    final rows = page['rows'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => ActivityReport.fromJson(row.cast<String, dynamic>()))
        .toList();
  }

  /// 总记录数（响应里的 `totalSize`）。
  static int totalFromResponse(Map<String, dynamic> body) {
    final datas = body['datas'];
    if (datas is! Map) return 0;
    final page = datas['tbgdj_lbcx'];
    if (page is! Map) return 0;
    final total = page['totalSize'];
    if (total is num) return total.toInt();
    return int.tryParse(total?.toString() ?? '') ?? 0;
  }
}

class ActivityFetchException implements Exception {
  final String msg;
  const ActivityFetchException(this.msg);

  @override
  String toString() => msg;
}

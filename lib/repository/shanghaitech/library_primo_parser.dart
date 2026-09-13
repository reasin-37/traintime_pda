// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0
//
// 上海科技大学图书馆（Ex Libris Primo）响应解析。
//
// 【设计纪律】只 import dart:* 与同目录模型，**不 import Flutter**，可在沙盒内离线断言。
//
// 【依据】全部字段路径来自真实响应实测：
//   - 检索：devkit/fixtures/stc_primo_search.json（GET …/primo-explore/v1/pnxs）
//   - 馆藏：同响应内的 rtaResultsLink 编码串
// 实测响应顶层键：rtaResultsLink / highlights / docs / timelog / lang3 / info / facets。

import 'dart:convert';

import 'package:watermeter/model/shanghaitech/library.dart';

// ---- 访客 JWT 的纯 Dart 处理（放这里以便离线断言，见 devkit/verify_library.dart）----
//
// Primo 的检索接口**必须**带 `Authorization: Bearer <访客JWT>`，否则返回 403
// （实测：不带 JWT 403；带 Bearer 200；只放裸 token 500）。

/// 从 JWT 接口的响应体里取出令牌字符串。
///
/// 实测该接口返回的是**带引号的 JSON 字符串**（如 `"eyJraWQiOi…"`），
/// 也可能（未证实）直接返回裸串或 `{"token": "…"}`，三种都兼容。
String parseGuestJwt(Object? data) {
  if (data is String) {
    final t = data.trim();
    if (t.startsWith('"') && t.endsWith('"')) {
      try {
        final decoded = jsonDecode(t);
        if (decoded is String) return decoded.trim();
      } catch (_) {
        // 解析失败则落回原串
      }
    }
    return t;
  }
  if (data is Map && data['token'] is String) {
    return (data['token'] as String).trim();
  }
  return '';
}

/// 判断 JWT 是否已过期（或即将过期）。
///
/// [margin] 为提前刷新余量：剩余寿命不足该值即视为需要刷新。
///
/// **保守策略**：任何解析失败（段数不对、base64 异常、`exp` 非整数）都返回 true，
/// 即「当作过期、重新获取」，以免误用坏令牌。
bool isGuestJwtExpired(
  String token, {
  Duration margin = const Duration(minutes: 5),
  DateTime? now,
}) {
  final parts = token.split('.');
  if (parts.length != 3) return true;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = jsonDecode(payload);
    if (map is! Map) return true;
    final exp = map['exp'];
    if (exp is! int) return true;
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final reference = now ?? DateTime.now();
    return reference.isAfter(expiry.subtract(margin));
  } catch (_) {
    return true;
  }
}

/// 解析 Primo 检索响应（`…/primo-explore/v1/pnxs`）为 [LibrarySearchResult]。
///
/// 容错原则：任何字段缺失/类型不符都退化为 null 或空列表，**绝不抛异常**
/// （图书馆接口字段随资源类型变化很大，例如电子书没有物理馆藏）。
LibrarySearchResult parsePrimoSearch(Map<String, dynamic> json) {
  final info = _asMap(json['info']);
  final docs = _asList(json['docs']);

  // 先解析馆藏索引（来自 rtaResultsLink），再逐条装配
  final holdingsIndex = parseHoldingsIndex(json['rtaResultsLink']);

  final books = <LibraryBook>[];
  for (final raw in docs) {
    final doc = _asMap(raw);
    if (doc == null) continue;
    final pnx = _asMap(doc['pnx']);
    if (pnx == null) continue;
    final book = _parseDoc(doc, pnx, holdingsIndex);
    if (book != null) books.add(book);
  }

  return LibrarySearchResult(
    total: _asInt(info?['total']) ?? books.length,
    count: _asInt(info?['last']) ?? books.length,
    books: books,
  );
}

/// 从 `docs[i]` 组装一本书。
LibraryBook? _parseDoc(
  Map<String, dynamic> doc,
  Map<String, dynamic> pnx,
  Map<String, List<LibraryHolding>> holdingsIndex,
) {
  final search = _asMap(pnx['search']);
  final display = _asMap(pnx['display']);

  // 记录标识：优先 search.recordid，回退 doc['@id']
  final recordIdList = _asStringList(search?['recordid']);
  final id = recordIdList.isNotEmpty
      ? recordIdList.first
      : (_asString(doc['@id']) ?? '');
  if (id.isEmpty) return null;

  // 题名：display.title 已有完整排版，优先；回退 search.title 首个
  final title = _asStringList(display?['title']).firstOrNull ??
      _asStringList(search?['title']).firstOrNull ??
      '';

  final authors = _asStringList(search?['creatorcontrib']);

  final publisher = _asStringList(display?['publisher']).firstOrNull ??
      _asStringList(search?['lsr03']).firstOrNull;

  final publishDate = _asStringList(search?['creationdate']).firstOrNull ??
      _asStringList(display?['creationdate']).firstOrNull;

  final isbns = _asStringList(search?['isbn']);

  final resourceType = _asStringList(search?['rsrctype']).firstOrNull ??
      _asStringList(display?['type']).firstOrNull;

  final format = _asStringList(display?['format']).firstOrNull;

  final subjects = _asStringList(search?['subject']);

  // 馆藏：按 id 的多种形态去索引里找
  final holdings = _lookupHoldings(id, holdingsIndex);

  // 索书号：优先馆藏 $$2（最准确），回退 search.lsr01
  final callNumber = holdings
          .map((h) => h.callNumber)
          .whereType<String>()
          .firstOrNull ??
      _asStringList(search?['lsr01']).firstOrNull;

  // 电子资源判定：源是 SFX（电子资源库）或完全没有物理馆藏
  final isElectronic = id.startsWith('SHTECH_SFX') || holdings.isEmpty;

  return LibraryBook(
    id: id,
    title: title,
    authors: authors,
    publisher: publisher,
    publishDate: publishDate,
    isbns: isbns,
    resourceType: resourceType,
    format: format,
    callNumber: callNumber,
    subjects: subjects,
    holdings: holdings,
    isElectronic: isElectronic,
  );
}

/// 按记录 id 在馆藏索引中查找。
///
/// id 的形态在不同源下不同：
///   - `SHTECH_ALEPH_CNMARC000024487` → 尾段数字 `000024487`
///   - `SHTECH_SFX4100000011808920`   → 尾段数字 `4100000011808920`
/// 索引同时以「尾段数字」与「完整 id」为键，两种都能命中。
List<LibraryHolding> _lookupHoldings(
  String id,
  Map<String, List<LibraryHolding>> index,
) {
  final direct = index[id];
  if (direct != null) return direct;
  final tail = _trailingDigits(id);
  if (tail != null) {
    final byTail = index[tail];
    if (byTail != null) return byTail;
  }
  return const [];
}

/// 取字符串末尾的连续数字（如 `SHTECH_ALEPH_CNMARC000024487` → `000024487`）。
String? _trailingDigits(String s) {
  final m = RegExp(r'(\d+)$').firstMatch(s);
  return m?.group(1);
}

/// 解析 `rtaResultsLink` 里的馆藏编码串，返回「记录键 → 馆藏列表」索引。
///
/// 实测格式（Ex Libris 专有编码，非标准格式，故单独成函数并加断言覆盖）：
/// ```
/// recordInformation=000024487|,|SHTECH_ALEPH_CNMARC|,|SKD01|,|Aleph|,|SHTECH_ALEPH_CNMARC000024487|,|
///   $$ISHTECH$$LMAIN$$1404专业阅览室$$2(TP311.561/34 )$$Savailable$$XSKD50$$YMAIN$$ZF404|,|
///   $$ISHTECH$$Savailable|,|…;4100000011808920|,|SHTECH_SFX|,|…
/// ```
/// - 记录之间用 `;` 分隔（实测部分段以 `|` 开头，需清理）
/// - 一条记录内部字段用 `|,|` 分隔，共 14 个字段
/// - 含 `$$` 的字段是馆藏明细，子字段形如 `$$I值$$L值…`
Map<String, List<LibraryHolding>> parseHoldingsIndex(Object? rtaResultsLink) {
  final index = <String, List<LibraryHolding>>{};
  final link = _asString(rtaResultsLink);
  if (link == null || link.isEmpty) return index;

  final Uri uri;
  try {
    uri = Uri.parse(link);
  } catch (_) {
    return index;
  }
  final recordInfo = uri.queryParameters['recordInformation'];
  if (recordInfo == null || recordInfo.isEmpty) return index;

  for (final rawSeg in recordInfo.split(';')) {
    final seg = rawSeg.replaceAll(RegExp(r'^\|+'), '');
    if (seg.trim().isEmpty) continue;

    final fields = seg.split('|,|');
    if (fields.isEmpty) continue;

    // 字段 0：记录编号（尾段，用于匹配）；字段 4：完整 id
    final recordNo = fields[0].trim();
    final fullId = fields.length > 4 ? fields[4].trim() : '';

    final allHoldings = <LibraryHolding>[];
    for (final f in fields) {
      if (!f.contains(r'$$')) continue;
      final h = _parseHoldingField(f);
      if (h != null) allHoldings.add(h);
    }
    if (allHoldings.isEmpty) continue;

    // 编码串里含 `$$` 的字段有三种，语义不同（实测，见 verify_library.dart 断言）：
    //   ① 有馆藏地（$$1）        → 一册真实馆藏，例如
    //      `$$ISHTECH$$LMAIN$$1404专业阅览室$$2(TP311.561/34 )$$Savailable…`
    //   ② 无地点但有状态（$$S）  → 该记录的**汇总**可借状态，例如 `$$ISHTECH$$Savailable`
    //   ③ 仅类型标记             → 例如 `$$Taleph_holdings`，无地点无状态，应忽略
    final byLocation = allHoldings.where((h) => h.location != null).toList();
    final byStatus = allHoldings
        .where((h) => h.location == null && h.statusCode != null)
        .toList();

    // 真实馆藏以「有地点」的为准（它们是逐册条目，UI 展示这些）。
    //
    // 若一条都没有，则退化为「仅状态」的一条 —— 这样：
    //   - 纯电子资源（无物理馆藏）能显示可借状态，而不是被当成「无馆藏」
    //   - 不会因为缺少 $$1 就把整条记录丢掉（早期版本有这个缺陷）
    // 注意：仅剩类型标记（情形③）时才真正没有可用信息，跳过。
    final List<LibraryHolding> effective;
    if (byLocation.isNotEmpty) {
      effective = byLocation;
    } else if (byStatus.isNotEmpty) {
      effective = [byStatus.first];
    } else {
      continue;
    }

    if (recordNo.isNotEmpty) index[recordNo] = effective;
    if (fullId.isNotEmpty) index[fullId] = effective;
  }
  return index;
}

/// 解析单个馆藏字段，如
/// `$$ISHTECH$$LMAIN$$1404专业阅览室$$2(TP311.561/34 )$$Savailable$$XSKD50$$YMAIN$$ZF404`。
///
/// 子字段含义（实测确认）：
///   `$$I` 机构　`$$L` 分馆　`$$1` 馆藏地　`$$2` 索书号　`$$S` 可借状态
///   `$$X`/`$$Y`/`$$Z` 定位码（当前不用，但保留解析能力）
LibraryHolding? _parseHoldingField(String field) {
  final sub = <String, String>{};
  // 按 $$ 切分：首段为空，其后每段首字符是子字段码
  for (final part in field.split(r'$$')) {
    if (part.isEmpty) continue;
    sub[part[0]] = part.substring(1).trim();
  }
  if (sub.isEmpty) return null;

  // 索书号实测形如 `(TP311.561/34 )`，去掉外层括号与多余空格
  var callNumber = sub['2'];
  if (callNumber != null) {
    callNumber = callNumber.replaceAll(RegExp(r'^[（(]'), '')
        .replaceAll(RegExp(r'[）)]$'), '')
        .trim();
    if (callNumber.isEmpty) callNumber = null;
  }

  return LibraryHolding(
    institution: _nonEmpty(sub['I']),
    libraryCode: _nonEmpty(sub['L']),
    location: _nonEmpty(sub['1']),
    callNumber: callNumber,
    statusCode: _nonEmpty(sub['S']),
  );
}

// ---- 类型安全的小工具（Primo 字段类型不稳定，必须容错） ----

Map<String, dynamic>? _asMap(Object? v) =>
    v is Map<String, dynamic> ? v : (v is Map ? v.cast<String, dynamic>() : null);

List<Object?> _asList(Object? v) => v is List ? v : const [];

/// Primo 的文本字段常是「字符串数组」，也见过单字符串，两种都接受。
List<String> _asStringList(Object? v) {
  if (v == null) return const [];
  if (v is String) return [v];
  if (v is List) {
    return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
  return [v.toString()];
}

String? _asString(Object? v) => v is String ? v : v?.toString();

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

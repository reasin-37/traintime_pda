// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0
//
// 上海科技大学图书馆（Ex Libris Primo）数据模型。
//
// 【设计纪律】本文件**只 import dart:* 与 package:json_annotation**，不 import Flutter，
// 这样可以在沙盒里用纯 Dart 离线跑断言（见 devkit/verify_library.dart）。
//
// 【依据】字段名与语义均取自真实 Primo 响应实测（fixture：
// devkit/fixtures/stc_primo_search.json），不是推测。

/// 检索字段。值即 Primo 的 `q=<field>,contains,<term>` 中的 field。
class PrimoSearchField {
  final String field;
  final String labelKey; // i18n 键
  const PrimoSearchField(this.field, this.labelKey);

  /// Primo 支持的常用检索字段（`any` 为默认的任意词）。
  static const List<PrimoSearchField> all = [
    PrimoSearchField('any', 'library.search_field_keyword_option'),
    PrimoSearchField('title', 'library.search_field_title_option'),
    PrimoSearchField('creator', 'library.search_field_author_option'),
    PrimoSearchField('isbn', 'library.search_field_isbn_option'),
    PrimoSearchField('sub', 'library.search_field_subject_option'),
    PrimoSearchField('lsr01', 'library.search_field_callno_option'),
  ];

  static const PrimoSearchField fallback = PrimoSearchField(
    'any',
    'library.search_field_keyword_option',
  );
}

/// 一条馆藏（一本书可能有多条）。
///
/// 数据来自检索响应 `rtaResultsLink` 中的 Ex Libris 编码串，实测形如：
/// `$$ISHTECH$$LMAIN$$1404专业阅览室$$2(TP311.561/34 )$$Savailable$$XSKD50$$YMAIN$$ZF404`
///
/// 子字段含义（实测确认）：
///   $$I 机构代码   $$L 分馆代码   $$1 馆藏地名称   $$2 索书号
///   $$S 可借状态   $$X/$$Y/$$Z 定位码
class LibraryHolding {
  /// 机构代码（如 SHTECH）
  final String? institution;

  /// 分馆代码（如 MAIN）
  final String? libraryCode;

  /// 馆藏地名称（如「404专业阅览室」）
  final String? location;

  /// 索书号，已去掉外层括号（如 `TP311.561/34`）
  final String? callNumber;

  /// Primo 原始可借状态码（如 `available`）。保留原值以便将来扩展映射。
  final String? statusCode;

  const LibraryHolding({
    this.institution,
    this.libraryCode,
    this.location,
    this.callNumber,
    this.statusCode,
  });

  /// 是否可借。仅在明确拿到 `available` 时为 true；
  /// 拿不到状态时返回 null（**不猜**，由 UI 显示「未知」）。
  bool? get isAvailable {
    if (statusCode == null || statusCode!.isEmpty) return null;
    return statusCode == 'available';
  }

  /// 可借状态对应的 **i18n 键**（模型层不放中文，保持可翻译）。
  ///
  /// 复用上游既有键：`library.avaliable_borrow`（注意上游拼写为 avaliable）、
  /// `library.status_unknown`；`library.not_available` 为本分支新增。
  String get statusKey {
    switch (statusCode) {
      case 'available':
        return 'library.avaliable_borrow';
      case 'unavailable':
        return 'library.not_available';
      default:
        return 'library.status_unknown';
    }
  }
}

/// 检索结果中的一本书。
class LibraryBook {
  /// 记录标识。优先取 `pnx.search.recordid` 首个值（如
  /// `SHTECH_ALEPH_CNMARC000024487`），回退到 docs 项的 `@id`。
  final String id;

  /// 题名。优先取 `pnx.display.title`（已含副题名等排版），回退 `pnx.search.title` 首个。
  final String title;

  /// 责任者（可能多人）。取自 `pnx.search.creatorcontrib`。
  final List<String> authors;

  /// 出版社。优先 `pnx.display.publisher`，回退 `pnx.search.lsr03` 首个。
  final String? publisher;

  /// 出版年。取自 `pnx.search.creationdate` 首个。
  final String? publishDate;

  /// ISBN（可能多个版本/格式）。取自 `pnx.search.isbn`。
  final List<String> isbns;

  /// 资源类型（如 `book`）。取自 `pnx.search.rsrctype` 首个。
  final String? resourceType;

  /// 载体形态（如 `120页 : 图 ; 26cm`）。取自 `pnx.display.format`。
  final String? format;

  /// 索书号。优先馆藏里的 `$$2`，回退 `pnx.search.lsr01` 首个。
  final String? callNumber;

  /// 主题词。取自 `pnx.search.subject`。
  final List<String> subjects;

  /// 馆藏列表（可能为空，如纯电子资源）。
  final List<LibraryHolding> holdings;

  /// 是否为电子资源（无物理馆藏，或 deliveryCategory 含 Remote Search Resource）。
  final bool isElectronic;

  const LibraryBook({
    required this.id,
    required this.title,
    this.authors = const [],
    this.publisher,
    this.publishDate,
    this.isbns = const [],
    this.resourceType,
    this.format,
    this.callNumber,
    this.subjects = const [],
    this.holdings = const [],
    this.isElectronic = false,
  });

  /// 是否至少有一册可借。无馆藏时返回 false。
  bool get hasAvailableCopy => holdings.any((h) => h.isAvailable == true);

  /// 可借册数。
  ///
  /// 命名与语义对齐上游西电版 `BookInfo.availableCount`（`lib/model/xidian_ids/library.dart:224`），
  /// 便于后续若要做「统一图书馆抽象」时两边字段一致。
  int get availableCount => holdings.where((h) => h.isAvailable == true).length;

  /// 状态未知的册数（Primo 未给出可借状态时既不算可借也不算不可借）。
  int get unknownCount => holdings.where((h) => h.isAvailable == null).length;

  /// 馆藏地名称去重后的列表。
  List<String> get locations {
    final seen = <String>{};
    for (final h in holdings) {
      final l = h.location;
      if (l != null && l.isNotEmpty) seen.add(l);
    }
    return seen.toList();
  }
}

/// 一次检索的结果集。
class LibrarySearchResult {
  /// 命中的总记录数（Primo `info.total`）。
  final int total;

  /// 本次返回的条数（Primo `info.last`）。
  final int count;

  final List<LibraryBook> books;

  const LibrarySearchResult({
    required this.total,
    required this.count,
    required this.books,
  });

  static const LibrarySearchResult empty = LibrarySearchResult(
    total: 0,
    count: 0,
    books: [],
  );
}

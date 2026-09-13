// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0
//
// 上海科技大学图书馆（Ex Libris Primo）会话层。
//
// 【与西电版的区别】西电版 `ids_session/library_session.dart`（689 行）走超星/图星协议
// （`mfindxidian.libsp.cn`、馆代码 200755、chaoxing CAS）。上科大用 Ex Libris
// （Alma/Primo），接口形态完全不同，故本文件为**重写**，不复用西电实现。
// 类名加 `Primo` 前缀以区别于西电的 `LibrarySession`，避免同名歧义。
//
// 【鉴权：必须带访客 JWT】实测（devkit 探针，2026-09-13）：
//   - 不带 JWT 直接请求检索 → **403**（响应是 Primo 的 HTML 错误页）
//   - 先 GET `…/rest/v1/guestJwt/SHTECH?isGuest=true` 拿到 JWT，
//     再以 `Authorization: Bearer <jwt>` 请求检索 → **200**
//   - 仅靠 Cookie（先访问站点）或加 `X-Requested-With` 都**无效**（仍 403）
//   - 注意必须是 `Bearer <token>`；只放裸 token 会得到 500
// 故本类会自动获取并缓存 JWT，并在 401/403 时刷新重试一次。
//
// 【实测请求形态】captures/discovery.lib.shanghaitech.edu.cn.har
//   检索：GET /primo_library/libweb/webservices/rest/primo-explore/v1/pnxs
//   参数：inst=SHTECH vid=shtech lang=zh_CN tab=default_tab scope=default_scope
//         mode=basic q=<field>,contains,<term> sort=rank offset=<n> limit=<n>

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:watermeter/model/fetch_result.dart';
import 'package:watermeter/model/shanghaitech/library.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/network_client.dart';
import 'package:watermeter/repository/shanghaitech/library_primo_parser.dart';

/// Primo 访问异常：网络失败、鉴权失败、响应格式异常等。
class PrimoLibraryException implements Exception {
  final String message;
  const PrimoLibraryException(this.message);
  @override
  String toString() => message;
}

class PrimoLibrarySession {
  /// 学校在 Primo 中的机构代码与视图代码（实测）。
  static const institution = 'SHTECH';
  static const viewId = 'shtech';

  static const _host = 'https://discovery.lib.shanghaitech.edu.cn';

  static const _searchUrl =
      '$_host/primo_library/libweb/webservices/rest/primo-explore/v1/pnxs';

  /// 访客 JWT 接口（无需登录）。
  static const _guestJwtUrl =
      '$_host/primo_library/libweb/webservices/rest/v1/guestJwt/$institution'
      '?isGuest=true&lang=zh_CN&viewId=$viewId';

  /// 单页默认条数。
  static const defaultPageSize = 10;

  final Dio dio;

  String? _token;

  /// 允许注入 Dio 以便测试套用模拟适配器；默认用公开无状态客户端
  /// （Primo 检索无需 Cookie，鉴权靠 JWT）。
  PrimoLibrarySession({Dio? dio}) : dio = dio ?? NetworkClients.otherDio;

  /// 检索馆藏。
  ///
  /// [keyword] 检索词；[field] 检索字段（见 [PrimoSearchField]，默认任意词）；
  /// [page] 从 0 开始；[pageSize] 每页条数。
  Future<FetchResult<LibrarySearchResult>> searchBooks(
    String keyword, {
    String field = 'any',
    int page = 0,
    int pageSize = defaultPageSize,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      // 空关键词直接返回空结果，不发请求（Primo 对空 q 会返回全量，无意义且慢）。
      return FetchResult.fresh(
        fetchTime: DateTime.now(),
        data: LibrarySearchResult.empty,
      );
    }

    final query = buildQueryParameters(
      field: field,
      keyword: trimmed,
      page: page,
      pageSize: pageSize,
    );

    // 首次取 token；若被拒（401/403）则强制刷新后重试一次。
    try {
      final json = await _getSearchJson(query);
      return _toResult(json, trimmed);
    } on DioException catch (e, s) {
      if (!_isAuthFailure(e)) {
        log.handle(e, s, '[PrimoLibrarySession][searchBooks] Have issue');
        throw PrimoLibraryException('图书馆检索失败：${e.message ?? e.type.name}');
      }
      log.warning(
        '[PrimoLibrarySession][searchBooks] 鉴权被拒，刷新 JWT 后重试一次',
      );
      try {
        final json = await _getSearchJson(query, forceRefreshToken: true);
        return _toResult(json, trimmed);
      } on DioException catch (e2, s2) {
        log.handle(e2, s2, '[PrimoLibrarySession][searchBooks] 重试仍失败');
        throw PrimoLibraryException(
          '图书馆检索失败（鉴权）：${e2.message ?? e2.type.name}',
        );
      }
    }
  }

  FetchResult<LibrarySearchResult> _toResult(
    Map<String, dynamic> json,
    String keyword,
  ) {
    final result = parsePrimoSearch(json);
    log.info(
      '[PrimoLibrarySession][searchBooks] "$keyword" → '
      'total=${result.total} got=${result.count}',
    );
    return FetchResult.fresh(fetchTime: DateTime.now(), data: result);
  }

  /// 发起检索请求并解析为 JSON。
  Future<Map<String, dynamic>> _getSearchJson(
    Map<String, dynamic> query, {
    bool forceRefreshToken = false,
  }) async {
    final token = await _obtainToken(forceRefresh: forceRefreshToken);
    final response = await dio.get<dynamic>(
      _searchUrl,
      queryParameters: query,
      options: Options(
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    return _asJsonMap(response.data);
  }

  /// 判断是否为鉴权失败（Primo 对缺少/失效 JWT 返回 403）。
  static bool _isAuthFailure(DioException e) {
    final code = e.response?.statusCode;
    return code == 401 || code == 403;
  }

  /// 取得可用 JWT：优先用缓存中未过期的，否则重新获取。
  Future<String> _obtainToken({bool forceRefresh = false}) async {
    final cached = _token;
    if (!forceRefresh && cached != null && !isGuestJwtExpired(cached)) {
      return cached;
    }
    final fresh = await _fetchGuestJwt();
    _token = fresh;
    return fresh;
  }

  /// 获取访客 JWT。
  Future<String> _fetchGuestJwt() async {
    try {
      final response = await dio.get<dynamic>(
        _guestJwtUrl,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final token = parseGuestJwt(response.data);
      if (token.isEmpty) {
        throw const PrimoLibraryException('图书馆访客令牌为空');
      }
      log.info(
        '[PrimoLibrarySession][_fetchGuestJwt] 取得令牌（${token.length} 字符）',
      );
      return token;
    } on DioException catch (e, s) {
      log.handle(e, s, '[PrimoLibrarySession][_fetchGuestJwt] Have issue');
      throw PrimoLibraryException('获取图书馆访客令牌失败：${e.message ?? e.type.name}');
    }
  }

  /// 响应体可能是 Map（Dio 已解析 JSON）也可能是 String。
  static Map<String, dynamic> _asJsonMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    }
    throw const PrimoLibraryException('图书馆返回了无法识别的响应格式');
  }

  /// 组装查询参数。单独抽出以便断言（见 devkit/verify_library_http.dart）。
  ///
  /// 参数集与实测请求保持一致（`captures/discovery...har` 中的 pnxs 请求）。
  static Map<String, dynamic> buildQueryParameters({
    String field = 'any',
    String keyword = '',
    int page = 0,
    int pageSize = defaultPageSize,
  }) {
    return {
      'blendFacetsSeparately': 'false',
      'getMore': '0',
      'inst': institution,
      'lang': 'zh_CN',
      'limit': '$pageSize',
      'mode': 'basic',
      'newspapersActive': 'false',
      'newspapersSearch': 'false',
      'offset': '${page * pageSize}',
      'pcAvailability': 'true',
      'q': '$field,contains,$keyword',
      'qExclude': '',
      'qInclude': '',
      'refEntryActive': 'false',
      'rtaLinks': 'true',
      'scope': 'default_scope',
      'searchInFulltextUserSelection': 'true',
      'skipDelivery': 'Y',
      'sort': 'rank',
      'tab': 'default_tab',
      'vid': viewId,
    };
  }

  /// 检索入口 URL 与访客令牌 URL（供调试与 UI 提供「在浏览器中打开」用）。
  static const searchUrl = _searchUrl;
  static const guestJwtUrl = _guestJwtUrl;
  static const libraryHost = _host;
}

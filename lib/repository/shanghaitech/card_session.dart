// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0
//
// 上海科技大学一卡通（新开普 NewCapec 服务大厅）会话层。
//
// 【实测依据】captures/card_full.har（149 条）：
//   - 入口：`GET /servicehall/casClient/login`（SSO 回跳后的页面）
//     → 该页 HTML 内以隐藏字段渲染 openid：`<input id="openid" value="…" type="hidden">`
//   - 业务接口：`POST /servicehall/business/<method>?openid=<32位hex>`
//     · getCardUserInfoByIdserial  body {"idserial":"<学号>"}
//     · thirdQuerSelfTrade        body {"starttime":…,"endtime":…,"tradetype":"-1",
//                                      "datetype":"1","pageNumber":0,"pageSize":10,"idserial":"<学号>"}
//     · queryCommon               body {"names":"acctype"}
//   - 请求头必须带 `x-requested-with: XMLHttpRequest` 与
//     `Referer: https://card.shanghaitech.edu.cn/servicehall/casClient/login`
//
// 【鉴权：必须走统一认证拿到 SSO 会话】⚠️ 这是实测踩到的坑：
//   一卡通自身**没有账号密码**，它是通过统一认证（CAS）进入的。
//   未认证时直接请求 `/servicehall/casClient/login` 会返回 **302**（指向
//   `ids.shanghaitech.edu.cn/authserver/login?service=…`）且**响应体为空**，
//   因此从该响应里提取 openid 必然失败。
//   App 必须像「学术活动」模块那样：先 `checkAndLogin` 拿 CAS 跳转目标，
//   再 `followIDSRedirects` 用**同一 cookie 容器**落到一卡通域种下会话，
//   之后该页才会带着 openid 正常渲染。
//   参考实现：`ids_session/activity_session.dart:52-57`。
//
// 【与解析层的关系】本文件负责 I/O；解密与解析在 `card_parser.dart`
// （那个文件不 import Flutter/Dio，可离线断言）。

import 'package:dio/dio.dart';
import 'package:watermeter/model/fetch_result.dart';
import 'package:watermeter/model/shanghaitech/card.dart';
import 'package:watermeter/repository/ids_session/ids_session.dart';
import 'package:watermeter/repository/ids_session/slider_captcha_client.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/shanghaitech/card_parser.dart';

/// 一卡通访问异常（网络失败、未登录、拿不到 openid、响应异常等）。
class CardSessionException implements Exception {
  final String message;

  /// 是否属于「需要先登录统一认证」的情形。
  final bool needsLogin;

  const CardSessionException(this.message, {this.needsLogin = false});
  @override
  String toString() => message;
}

class CardSession extends IDSSession {
  static const _host = 'https://card.shanghaitech.edu.cn';
  static const _basePath = '/servicehall';

  /// CAS service / 一卡通入口（SSO 回跳落点）。
  static const loginPageUrl = '$_host$_basePath/casClient/login';

  /// 业务接口前缀。
  static const businessBaseUrl = '$_host$_basePath/business';

  /// 默认每页条数（与实测请求一致）。
  static const defaultPageSize = 10;

  /// 缓存的 openid（首次取到后复用）。
  String? _openId;

  /// 缓存的 CAS 跳转目标（`checkAndLogin` 的返回值，含 ticket）。
  String? _pendingLocation;

  CardSession();

  /// 清空会话状态（登出或会话失效时调用）。
  void clearSession() {
    _openId = null;
    _pendingLocation = null;
  }

  /// 确保已完成统一认证并取得 openid。
  ///
  /// 流程（与 `activity_session.dart` 同构）：
  ///   1. `checkAndLogin(target: 一卡通入口)` → 拿到含 ticket 的 CAS 跳转目标
  ///   2. `followIDSRedirects` 用同一 cookie 容器跳过去，在一卡通域种下会话
  ///   3. 再次请求入口页，从 HTML 的隐藏字段提取 openid
  ///
  /// [sliderCaptcha] 为滑块验证码求解器；默认用自动求解（与其它 IDS 业务一致）。
  Future<String> ensureOpenId({
    bool forceRefresh = false,
    Future<void> Function(String cookieStr)? sliderCaptcha,
  }) async {
    final cached = _openId;
    if (!forceRefresh && cached != null && cached.isNotEmpty) return cached;

    final solve = sliderCaptcha ??
        (String cookieStr) =>
            SliderCaptchaClientProvider(cookie: cookieStr).solve();

    // 1) 完成统一认证，取得 CAS 跳转目标
    try {
      _pendingLocation ??= await checkAndLogin(
        target: loginPageUrl,
        sliderCaptcha: solve,
      );
    } on LoginFailedException catch (e) {
      _pendingLocation = null;
      throw CardSessionException(
        '一卡通需要统一认证登录：${e.msg}',
        needsLogin: true,
      );
    } catch (e, s) {
      _pendingLocation = null;
      log.handle(e, s, '[CardSession][ensureOpenId] checkAndLogin 失败');
      throw CardSessionException(
        '一卡通登录前置失败：$e',
        needsLogin: true,
      );
    }

    // 2) 跟随跳转落到一卡通域（同一 cookie 容器）
    try {
      await followIDSRedirects(
        initialLocation: _pendingLocation!,
        client: dio,
      );
    } catch (e, s) {
      _pendingLocation = null;
      log.handle(e, s, '[CardSession][ensureOpenId] followIDSRedirects 失败');
      throw CardSessionException('一卡通 SSO 跳转失败：$e', needsLogin: true);
    }

    // 3) 取入口页并提取 openid
    try {
      final response = await dio.get<dynamic>(
        loginPageUrl,
        options: Options(
          headers: {
            'Accept': 'text/html,application/xhtml+xml',
            'Referer': '$_host$_basePath/index',
          },
          responseType: ResponseType.plain,
        ),
      );
      final html = response.data?.toString() ?? '';

      // 先尝试从「最终落点 URL」拿 openid（部分实现会把 openid 放在查询串里）
      final fromUrl = extractOpenIdFromHtml(response.realUri.toString());
      final openId = fromUrl ?? extractOpenIdFromHtml(html);

      if (openId == null) {
        // 区分「未登录」与「其它异常」：认证页含 pwdEncryptSalt / saltPassword
        final looksLikeAuthPage = html.contains('pwdEncryptSalt') ||
            html.contains('saltPassword') ||
            html.contains('authserver/login');
        throw CardSessionException(
          looksLikeAuthPage
              ? '一卡通需要先完成统一认证登录（当前落在认证页）'
              : '未能从一卡通页面提取 openid（页面结构可能已变更）',
          needsLogin: looksLikeAuthPage,
        );
      }

      _openId = openId;
      log.info('[CardSession][ensureOpenId] 取得 openid（${openId.length} 字符）');
      return openId;
    } on DioException catch (e, s) {
      log.handle(e, s, '[CardSession][ensureOpenId] 取入口页失败');
      throw CardSessionException('访问一卡通页面失败：${e.message ?? e.type.name}');
    }
  }

  /// 发起一次业务 POST 并解密解析。
  ///
  /// [method] 为接口名（如 `getCardUserInfoByIdserial`）；[body] 为请求体（明文 JSON）。
  Future<CardEnvelope> _post(String method, Map<String, dynamic> body) async {
    final openId = await ensureOpenId();
    try {
      final response = await dio.post<dynamic>(
        '$businessBaseUrl/$method',
        queryParameters: {'openid': openId},
        data: body,
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'x-requested-with': 'XMLHttpRequest',
            'Referer': loginPageUrl,
            'Origin': _host,
          },
        ),
      );
      return parseCardEnvelope(response.data);
    } on DioException catch (e, s) {
      log.handle(e, s, '[CardSession][$method] Have issue');
      // 会话可能失效：清掉缓存，下次调用会重新走一遍 SSO
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        clearSession();
      }
      throw CardSessionException('一卡通接口 $method 调用失败：${e.message ?? e.type.name}');
    }
  }

  /// 查询账户与卡片信息。需要 [idserial]（学号）。
  Future<FetchResult<CardAccount>> fetchAccount(String idserial) async {
    final envelope = await _post('getCardUserInfoByIdserial', {
      'idserial': idserial,
    });
    final account = parseCardAccount(envelope);
    if (account == null) {
      throw const CardSessionException('一卡通响应里没有账户信息（accountinfo）');
    }
    return FetchResult.fresh(fetchTime: DateTime.now(), data: account);
  }

  /// 查询账户下的卡片列表（与 [fetchAccount] 同一接口）。
  Future<List<CardInfo>> fetchCardInfos(String idserial) async {
    final envelope = await _post('getCardUserInfoByIdserial', {
      'idserial': idserial,
    });
    return parseCardInfos(envelope);
  }

  /// 查询交易流水。[startDate]/[endDate] 形如 `2026-09-06`；[page] 从 0 开始。
  Future<FetchResult<CardTransactionPage>> fetchTransactions(
    String idserial, {
    required String startDate,
    required String endDate,
    int page = 0,
    int pageSize = defaultPageSize,
  }) async {
    final envelope = await _post('thirdQuerSelfTrade', {
      'starttime': startDate,
      'endtime': endDate,
      'tradetype': '-1',
      'datetype': '1',
      'pageNumber': page,
      'pageSize': pageSize,
      'idserial': idserial,
    });
    return FetchResult.fresh(
      fetchTime: DateTime.now(),
      data: parseCardTransactions(envelope),
    );
  }

  /// 查询字典（如 `acctype` = 账户类型）。
  Future<List<CardDictionaryItem>> fetchDictionary(String names) async {
    final envelope = await _post('queryCommon', {'names': names});
    return parseCardDictionary(envelope, names);
  }
}

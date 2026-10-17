// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:catcher_2/catcher_2.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

final log = TalkerFlutter.init();

/// 含个人敏感信息的 host：这些 host 的**请求与响应都不允许写日志**。
///
/// 逐条说明：
/// - `ids.shanghaitech.edu.cn`：统一认证，含登录凭据与 CAS ticket
/// - `card.shanghaitech.edu.cn`：一卡通服务大厅。其业务响应经 AES 解密后含
///   **余额、学号、身份证号、手机号、银行卡号、消费流水**（见
///   `lib/repository/shanghaitech/card_parser.dart`）；且其页面 HTML 内联了
///   会话凭据 `openid`（隐藏字段），URL 与 Referer 里也会带上它。
///   因该 host 下**全部**流量都与此类信息相关，故整站屏蔽日志。
/// - `graduate.shanghaitech.edu.cn`：研究生门户。响应含姓名/院系/生日，且
///   成绩、考试、课表接口把**学号**放在 URL（`exam_session.dart` 的
///   `querySetting`）或请求体（`{'XH': 学号}`）里，故整站屏蔽。
/// - `discovery.lib.shanghaitech.edu.cn`：Primo 检索，其
///   `guestJwt` 接口的**响应体就是令牌**（`primo_library_session.dart`）。
/// - 西电遗留域（`ehall` / `zfw` / `w` / `tybjxgl` / `ignypt` / `xxcapp` /
///   `v8scan` / `ids.xidian.edu.cn`）：请求体或响应体含**学号、姓名、余额、
///   会话 token**（见 `schoolnet_session.dart`、`xidian_sport_session.dart`、
///   `energy_session.dart`）。这些模块虽已从界面移除，但代码仍可被调用，
///   故一并屏蔽。
/// - `mfindxidian.libsp.cn` / `tyrzfw.chaoxing.com`：西电图书馆 OPAC 与超星
///   CAS，请求头携带 OPAC JWT、查询串携带 CAS 断言数据
///   （`library_session.dart` 的 `jwtOpacAuth` 头与 `jwt=` 参数）。
///
/// ⚠️ **这是黑名单，新增域名必须同步登记**；漏登记即等于把该域全部流量
/// 写进可导出的日志。新增接口时请先在这里加一行。
const Set<String> _sensitiveHosts = {
  'ids.shanghaitech.edu.cn',
  'card.shanghaitech.edu.cn',
  'graduate.shanghaitech.edu.cn',
  'discovery.lib.shanghaitech.edu.cn',
  'ehall.xidian.edu.cn',
  'zfw.xidian.edu.cn',
  'w.xidian.edu.cn',
  'tybjxgl.xidian.edu.cn',
  'ignypt.xidian.edu.cn',
  'xxcapp.xidian.edu.cn',
  'v8scan.xidian.edu.cn',
  'ids.xidian.edu.cn',
  'mfindxidian.libsp.cn',
  'tyrzfw.chaoxing.com',
};

/// URL 查询参数中出现即视为敏感的键（小写比较）。
///
/// `openid` 是一卡通的**唯一会话凭据**（实测全程无 Cookie），等价于密码。
const Set<String> _sensitiveQueryKeys = {
  'ticket',
  'password',
  'dynamiccode',
  'authorization',
  'bfp',
  'openid',
};

/// 请求头中值可能含敏感信息的键（小写比较）。
///
/// `referer` 需要特别处理：一卡通业务请求的 Referer 形如
/// `…/servicehall/casClient/login?openid=<凭据>`，**值里带会话凭据**。
/// Talker 的 `hiddenHeaders` 只匹配头名，无法按值过滤，故只能整头屏蔽。
///
/// `jwtopacauth` / `jwt` / `token` 是各图书馆 / 体育系统把会话令牌放在
/// **自定义头**里的键名（如 `library_session.dart` 的 `jwtOpacAuth: _token`），
/// 不登记就会被原样打印。
const Set<String> _sensitiveHeaderNames = {
  'authorization',
  'cookie',
  'set-cookie',
  'proxy-authorization',
  'referer',
  'referrer',
  'jwtopacauth',
  'jwt',
  'token',
  'x-csrf-token',
};

bool _isSensitiveNetworkRequest(Uri uri) {
  if (_sensitiveHosts.contains(uri.host)) return true;
  final lowerQuery = uri.query.toLowerCase();
  return uri.queryParameters.keys.any(
        (key) => _sensitiveQueryKeys.contains(key.toLowerCase()),
      ) ||
      lowerQuery.contains('ticket=st-');
}

final logDioAdapter = TalkerDioLogger(
  talker: log,
  settings: TalkerDioLoggerSettings(
    printRequestHeaders: true,
    // ⚠️ 响应头**必须关**：talker_dio_logger 5.1.20 只在打印**请求**头时调用
    // `_replaceHiddenHeaders`，打印响应头（`dio_logs.dart` 的 DioResponseLog /
    // DioErrorLog）是**直接照抄**的，`hiddenHeaders` 里的 `set-cookie` 对响应头
    // 完全无效。开启即等于把各站的 `Set-Cookie`（会话凭据）写进日志。
    // 参考：`dio_logs.dart:59-62, 75-89`（请求头有脱敏）对比 `:146-148, 216-218`（响应头无）。
    printResponseHeaders: false,
    printErrorHeaders: false,
    printResponseMessage: true,
    hiddenHeaders: _sensitiveHeaderNames,
    requestFilter: (request) => !_isSensitiveNetworkRequest(request.uri),
    responseFilter: (response) {
      // 1. 忽略特定 URL
      final url = response.requestOptions.uri.toString();
      if (_isSensitiveNetworkRequest(response.requestOptions.uri) ||
          url.contains('openSliderCaptcha.htl')) {
        return false;
      }

      // 2. 忽略二进制文件 (Uint8List)
      // 通常通过检查 response.data 的类型或 Content-Type 头部
      if (response.data is List<int> || response.data is Uint8List) {
        return false;
      }

      return true;
    },
    errorFilter: (error) =>
        !_isSensitiveNetworkRequest(error.requestOptions.uri),
  ),
);

class PDACatcher2Logger extends Catcher2Logger {
  @override
  void info(String message) {
    log.info('Custom Catcher2 Logger | Info | $message');
  }

  @override
  void fine(String message) {
    log.info('Custom Catcher2 Logger | Fine | $message');
  }

  @override
  void warning(String message) {
    log.warning('Custom Catcher2 Logger | Warning | $message');
  }

  @override
  void severe(String message) {
    log.error('Custom Catcher2 Logger | Servere | $message');
  }
}

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
const Set<String> _sensitiveHosts = {
  'ids.shanghaitech.edu.cn',
  'card.shanghaitech.edu.cn',
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
const Set<String> _sensitiveHeaderNames = {
  'authorization',
  'cookie',
  'set-cookie',
  'proxy-authorization',
  'referer',
  'referrer',
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
    printResponseHeaders: true,
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

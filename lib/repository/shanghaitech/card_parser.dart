// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0
//
// 上海科技大学一卡通（新开普 NewCapec 服务大厅）响应解密与解析。
//
// 【设计纪律】只 import dart:* 与 encrypter_plus（纯 Dart 密码库）+ 本目录模型，
// **不 import Flutter**，可在沙盒内离线断言。
//
// 【解密方案：实测确认，非推测】
// 前端 `servicehall/js/common/my-encryption.js` 定义了 `aesUtil`（AES-ECB + Pkcs7），
// 而真正的「密钥从哪来」在 `servicehall/js/common/dkywwachat.js:367`：
//
//     tempFunction(aesUtil.decrypt(response.data.substr(16), response.data.substr(0, 16)));
//
// 即：**`data` 的前 16 个字符就是 AES 密钥（UTF-8），其余部分是 base64 密文。**
// 该行位于 `dkyw.tool.wrapperSuccess`（注释「默认的成功方法处理」），
// 是所有 dkyw 请求的通用成功回调，故**每一个**业务响应都按此规则解密。
//
// 已用 Node 的 crypto 独立复算验证：能解出 `{"message":"成功","resultData":{…}}`。

import 'dart:convert';

import 'package:encrypter_plus/encrypter_plus.dart' as encrypt;
import 'package:watermeter/model/shanghaitech/card.dart';

/// AES 密钥长度（字符数）。
const int cardAesKeyLength = 16;

/// 按「前 16 字符为密钥、其余为密文」的规则解密一卡通响应。
///
/// [data] 即响应体 `{"data":"…"}` 中的 `data` 字段。
///
/// 失败时抛 [CardDecryptException]（**不返回空串**，避免把解密失败伪装成空数据）。
String decryptCardPayload(String data) {
  if (data.length <= cardAesKeyLength) {
    throw const CardDecryptException('一卡通响应过短，无法取出密钥与密文');
  }
  final keyStr = data.substring(0, cardAesKeyLength);
  final cipherB64 = data.substring(cardAesKeyLength);

  try {
    final key = encrypt.Key.fromUtf8(keyStr);
    final cipherBytes = base64.decode(cipherB64);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.ecb),
    );
    return encrypter.decrypt(encrypt.Encrypted(cipherBytes));
  } catch (e) {
    throw CardDecryptException('一卡通响应解密失败：$e');
  }
}

/// 解析一卡通接口的原始响应体为统一外壳 [CardEnvelope]。
///
/// [rawBody] 可以是 Map（Dio 已解析 JSON）或 String。
/// 内部会完成：取 `data` → 解密 → 解析 `resultData`。
CardEnvelope parseCardEnvelope(Object? rawBody) {
  final map = _asJsonMap(rawBody);
  final data = map['data'];

  // 有些接口（如失败时）可能直接返回明文结构，此时按明文处理。
  if (data is! String || data.isEmpty) {
    return CardEnvelope(
      success: map['success'] == true,
      message: map['message']?.toString(),
      resultData: _asMap(map['resultData']),
    );
  }

  final plain = decryptCardPayload(data);
  final decoded = jsonDecode(plain);
  if (decoded is! Map) {
    throw const CardDecryptException('一卡通解密结果不是 JSON 对象');
  }
  final obj = decoded.cast<String, dynamic>();
  return CardEnvelope(
    success: obj['success'] == true,
    message: obj['message']?.toString(),
    resultData: _asMap(obj['resultData']),
  );
}

/// 解析账户信息（`getCardUserInfoByIdserial`）。
///
/// 实测路径：`resultData.accountinfo`。
/// 金额字段（`balance` / `overdrafttotal`）单位是**分**，故用 [_int] 取整数分值。
CardAccount? parseCardAccount(CardEnvelope envelope) {
  final accountInfo = _asMap(envelope.resultData?['accountinfo']);
  if (accountInfo == null) return null;
  return CardAccount(
    accStatus: _str(accountInfo['accstatus']),
    balanceCents: _int(accountInfo['balance']),
    overdraftTotalCents: _int(accountInfo['overdrafttotal']),
    lastTxDate: _str(accountInfo['lasttxdate']),
    createDate: _str(accountInfo['createdate']),
  );
}

/// 解析卡片列表（`resultData.cardinfos[]`）。金额单位同为**分**。
List<CardInfo> parseCardInfos(CardEnvelope envelope) {
  final list = envelope.resultData?['cardinfos'];
  if (list is! List) return const [];
  final result = <CardInfo>[];
  for (final raw in list) {
    final m = _asMap(raw);
    if (m == null) continue;
    result.add(
      CardInfo(
        maxConsumeAmountCents: _int(m['maxconsamt']),
        maxConsumeTotalAmountCents: _int(m['maxconstolamt']),
        consumedAmountCents: _int(m['consamt']),
        lineCreditCents: _int(m['linecredit']),
        allowConsume: _str(m['allowconsume']),
        effectDate: _str(m['effectdate']),
      ),
    );
  }
  return result;
}

/// 解析交易流水分页（`thirdQuerSelfTrade`）。
///
/// 实测路径：`resultData.rows[]`，分页字段 `total` / `totalpage` / `currentPage` / `size`。
/// 金额字段（`txamt` / `balance`）单位是**分**。
CardTransactionPage parseCardTransactions(CardEnvelope envelope) {
  final data = envelope.resultData;
  if (data == null) return CardTransactionPage.empty;

  final rowsRaw = data['rows'];
  final rows = <CardTransaction>[];
  if (rowsRaw is List) {
    for (final raw in rowsRaw) {
      final m = _asMap(raw);
      if (m == null) continue;
      rows.add(
        CardTransaction(
          amountCents: _int(m['txamt']),
          summary: _str(m['summary']),
          time: _millisToDateTime(m['txdate']),
          balanceAfterCents: _int(m['balance']),
          txCode: _str(m['txcode']),
        ),
      );
    }
  }

  return CardTransactionPage(
    total: _int(data['total']) ?? rows.length,
    totalPage: _int(data['totalpage']) ?? 0,
    rows: rows,
  );
}

/// 解析字典查询（`queryCommon`）。
///
/// 实测：`resultData.<names>` 为数组，元素含 `<前缀>code` / `<前缀>name`
/// （如 `acctype` → `acctypecode` / `acctypename`）。
List<CardDictionaryItem> parseCardDictionary(
  CardEnvelope envelope,
  String names,
) {
  final list = envelope.resultData?[names];
  if (list is! List) return const [];
  final result = <CardDictionaryItem>[];
  for (final raw in list) {
    final m = _asMap(raw);
    if (m == null) continue;
    // 码/名的键名带前缀（acctypecode / acctypename），故按后缀匹配
    String? code;
    String? name;
    for (final entry in m.entries) {
      final k = entry.key.toLowerCase();
      if (k.endsWith('code')) code ??= entry.value?.toString();
      if (k.endsWith('name')) name ??= entry.value?.toString();
    }
    if (code != null || name != null) {
      result.add(CardDictionaryItem(code: code, name: name));
    }
  }
  return result;
}

/// 从一卡通页面 HTML 中提取 `openid`。
///
/// 【为什么需要它】实测 SSO 回跳后的页面（`GET /servicehall/casClient/login`）里
/// 以**隐藏字段**的形式渲染了 openid：
/// ```html
/// <input id="openid" value="ED8093D2A6DEA25E5C4E9C9B62A922AA" type="hidden">
/// ```
/// 之后**每个业务接口**都要把它作为查询参数（`?openid=…`）。全流程**不使用 Cookie**
/// （实测所有请求均无 Cookie 头），故 openid 就是唯一的会话凭据。
///
/// 提取失败返回 `null`（**不抛异常**，由调用方决定如何提示）。
String? extractOpenIdFromHtml(String html) {
  if (html.isEmpty) return null;

  // ① 隐藏字段形式（实测）：<input id="openid" value="…" type="hidden">
  final byInput = RegExp(
    r'''id\s*=\s*["']openid["'][^>]*?value\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(html);
  if (byInput != null) return _cleanOpenId(byInput.group(1));

  // ② 若 value 在 id 之前（属性顺序不保证），反过来再试一次
  final byInputReversed = RegExp(
    r'''value\s*=\s*["']([^"']+)["'][^>]*?id\s*=\s*["']openid["']''',
    caseSensitive: false,
  ).firstMatch(html);
  if (byInputReversed != null) return _cleanOpenId(byInputReversed.group(1));

  // ③ JS 变量形式（未在实测中出现，但同类系统常见，作为兜底）
  final byJs = RegExp(
    r'''openid\s*[:=]\s*["']([A-Za-z0-9]{16,})["']''',
    caseSensitive: false,
  ).firstMatch(html);
  if (byJs != null) return _cleanOpenId(byJs.group(1));

  // ④ 链接参数形式：?openid=…
  final byUrl = RegExp(
    r'''[?&]openid=([A-Za-z0-9]{16,})''',
    caseSensitive: false,
  ).firstMatch(html);
  if (byUrl != null) return _cleanOpenId(byUrl.group(1));

  return null;
}

String? _cleanOpenId(String? raw) {
  if (raw == null) return null;
  final v = raw.trim();
  // 实测为 32 位 hex；放宽到 16 位以上纯字母数字，避免误判
  if (v.length < 16) return null;
  if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(v)) return null;
  return v;
}

// ---- 容错工具 ----

Map<String, dynamic>? _asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  return null;
}

Map<String, dynamic> _asJsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.cast<String, dynamic>();
  if (raw is String && raw.isNotEmpty) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
  }
  throw const CardDecryptException('一卡通响应不是合法的 JSON 对象');
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// 毫秒时间戳 → [DateTime]（实测 `txdate` 形如 `1789270515000`）。
DateTime? _millisToDateTime(Object? v) {
  final ms = _int(v);
  if (ms == null || ms <= 0) return null;
  // 防御：过小的值不可能是毫秒时间戳
  if (ms < 1000000000000) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms);
}

// Copyright 2026 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// 学术活动 / 听报告登记 数据源（上海科技大学 jzxxtjapp · tbgdj 模块）。
//
// 接口依据（实测抓包，见 captures/graduate.shanghaitech.edu.cn.har 与 02.har）：
//   入口   GET  https://graduate.shanghaitech.edu.cn/gsapp/sys/jzxxtjapp/*default/index.do#/tbgdj
//   列表   POST .../modules/tbgdj/tbgdj_lbcx.do   body: querySetting=[]&pageSize=..&pageNumber=..
//   响应   {"code":"0","datas":{"tbgdj_lbcx":{"totalSize":n,"pageNumber":1,"pageSize":..,"rows":[...]}}}
//
// 浏览器实际发送的请求头（抓包原文）里包含 X-Requested-With / Referer / Origin / Accept，
// 金智 emap 后端据此区分 AJAX 请求；缺少时可能返回登录页或错误页，故此处显式补上。
//
// 写入类接口（新建/删除/撤销）本次未实现，留待下一阶段：
//   POST .../jzxxtjapp/tbgdj/save.do    body: paramJson=<URL 编码 JSON>   响应 {"code":200,"success":true}
//   POST .../jzxxtjapp/tbgdj/delete.do  body: wid=<WID>
//   POST .../jzxxtjapp/tbgdj/cxtbg.do   （撤销）

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:watermeter/model/fetch_result.dart';
import 'package:watermeter/model/jzxxtj/activity_report.dart';
import 'package:watermeter/repository/ids_session/ids_session.dart';
import 'package:watermeter/repository/ids_session/slider_captcha_client.dart';
import 'package:watermeter/repository/single_flight.dart';

class ActivitySession extends IDSSession {
  static const String baseUrl =
      "https://graduate.shanghaitech.edu.cn/gsapp/sys/jzxxtjapp";

  /// CAS service 用该应用的入口地址（与课表/成绩/考试同一套做法）。
  static const String entryUrl = "$baseUrl/*default/index.do#/tbgdj";

  /// Referer 不带 #fragment（浏览器也不会把 fragment 放进 Referer）。
  static const String _referer = "$baseUrl/*default/index.do";

  /// 列表查询接口。
  static const String listUrl = "$baseUrl/modules/tbgdj/tbgdj_lbcx.do";

  /// 一次取足够多的记录；网页端默认每页 10 条。
  static const int _pageSize = 200;

  final _listFlight = SingleFlight<FetchResult<List<ActivityReport>>>();

  /// 取当前用户的听报告登记记录。并发调用会被 [SingleFlight] 合并为一次请求。
  Future<FetchResult<List<ActivityReport>>> getActivityReports() =>
      _listFlight.run(_getActivityReportsOnce);

  Future<FetchResult<List<ActivityReport>>> _getActivityReportsOnce() async {
    // 与其它 IDS 业务一致：先确保已登录，再跟随 CAS 重定向落到业务域。
    final location = await checkAndLogin(
      target: entryUrl,
      sliderCaptcha: (String cookieStr) =>
          SliderCaptchaClientProvider(cookie: cookieStr).solve(),
    );
    await followIDSRedirects(initialLocation: location, client: dio);

    // dio 的 BaseOptions 已设为 form-urlencoded，因此这里的 Map 会编码成
    // querySetting=%5B%5D&pageSize=..&pageNumber=..
    final response = await dio.post(
      listUrl,
      data: <String, String>{
        'querySetting': '[]',
        'pageSize': _pageSize.toString(),
        'pageNumber': '1',
      },
      options: Options(
        headers: <String, String>{
          HttpHeaders.acceptHeader:
              'application/json, text/javascript, */*; q=0.01',
          'X-Requested-With': 'XMLHttpRequest',
          HttpHeaders.refererHeader: _referer,
          'Origin': 'https://graduate.shanghaitech.edu.cn',
        },
      ),
    );

    final body = response.data;
    if (body is! Map) {
      // 把服务端实际返回的片段带进异常，方便在界面上直接看出是登录页、
      // 错误页还是别的格式。
      final raw = body?.toString() ?? '(空正文)';
      final snippet = raw.length > 160 ? '${raw.substring(0, 160)}…' : raw;
      throw ActivityFetchException(
        '听报告登记返回了非预期的数据格式（HTTP ${response.statusCode}）：$snippet',
      );
    }
    return FetchResult.fresh(
      fetchTime: DateTime.now(),
      data: ActivityReport.listFromResponse(body.cast<String, dynamic>()),
    );
  }
}

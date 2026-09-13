// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';
import 'package:watermeter/model/toolbox_addresses.dart';
import 'package:watermeter/page/toolbox/webview_list_tile.dart';

class ToolBoxPage extends StatefulWidget {
  const ToolBoxPage({super.key});

  @override
  State<ToolBoxPage> createState() => _ToolBoxPageState();
}

class _ToolBoxPageState extends State<ToolBoxPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: I18nText("toolbox.title")),
      body: ListView(
        children: [
          // 上海科技大学：研究生系统的直达入口。门户里还有培养方案、学期/学年考核、
          // 论文开题、预答辩、毕业审查、研究生选课等应用，日常使用频率不高，
          // 故不再逐个适配，统一由此跳转（未登录时会自动跳转统一认证）。
          WebViewAddresses(
            name: FlutterI18n.translate(context, "toolbox.graduate"),
            url:
                "https://graduate.shanghaitech.edu.cn/gsapp/sys/yjsemaphome/portal/index.do",
            description: FlutterI18n.translate(
              context,
              "toolbox.graduate_description",
            ),
            iconData: MingCuteIcons.mgc_school_line,
          ),
          WebViewAddresses(
            name: FlutterI18n.translate(context, "toolbox.payment"),
            url:
                "https://xxcapp.xidian.edu.cn/uc/api/oauth/index?redirect=https://ignypt.xidian.edu.cn/revenueH5/login?opcode=MPAY&appid=200260318155520600&state=1231231231",
            description: FlutterI18n.translate(
              context,
              "toolbox.payment_description",
            ),
            iconData: MingCuteIcons.mgc_exchange_cny_line,
          ),
          WebViewAddresses(
            name: FlutterI18n.translate(context, "toolbox.drinkingwater"),
            url: "https://order.xidian.edu.cn/mobile/thirdoauth/oauth2Xidian/1",
            description: FlutterI18n.translate(
              context,
              "toolbox.drinkingwater_description",
            ),
            iconData: MingCuteIcons.mgc_drop_line,
          ),
          WebViewAddresses(
            name: FlutterI18n.translate(context, "toolbox.repair"),
            url:
                "https://ids.xidian.edu.cn/authserver/login?service="
                "https%3A%2F%2Fids.xidian.edu.cn%2Fauthserver%2Foauth2.0%2F"
                "callbackAuthorize%3Fclient_id%3D869608421533880320%26"
                "redirect_uri%3Dhttp%253A%252F%252Frepair.xidian.edu.cn%252F"
                "appsys%252FxidianCasLogin%252FoauthLogin%26response_type%3D"
                "code%26state%3Dhome%26client_name%3DCasOAuthClient",
            description: FlutterI18n.translate(
              context,
              "toolbox.repair_description",
            ),
            iconData: MingCuteIcons.mgc_tool_line,
          ),
          WebViewAddresses(
            name: FlutterI18n.translate(context, "toolbox.reserve"),
            url: "http://libspace.xidian.edu.cn",
            description: FlutterI18n.translate(
              context,
              "toolbox.reserve_description",
            ),
            iconData: MingCuteIcons.mgc_building_4_line,
          ),
          WebViewAddresses(
            name: FlutterI18n.translate(context, "toolbox.network"),
            url: "https://zfw.xidian.edu.cn",
            description: FlutterI18n.translate(
              context,
              "toolbox.network_description",
            ),
            iconData: MingCuteIcons.mgc_wifi_line,
          ),
          WebViewAddresses(
            name: FlutterI18n.translate(context, "toolbox.physics"),
            url: "https://experiment-helper.wizzstudio.com/#/",
            description: FlutterI18n.translate(
              context,
              "toolbox.physics_description",
            ),
            iconData: MingCuteIcons.mgc_counter_2_line,
          ),
        ].map((e) => WebViewListTile(data: e)).toList(),
      ),
    );
  }
}

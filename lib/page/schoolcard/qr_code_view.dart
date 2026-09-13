// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

// 校园卡二维码视图。
//
// 【本分支说明】原先调用西电 session 的 `getQRCode()`（`v8scan.xidian.edu.cn`）。
// 上海科技大学的一卡通（新开普服务大厅）**尚未适配二维码接口**：
//   - `getCardUserInfoByIdserial` 响应里的 `qrcodeinfo` 字段实测**不是二维码图片**，
//     而是「卡片信息」对象（含 `consamt` / `maxconsamt` / `allowidentity` 等）。
//   - 真正的二维码入口在页面 HTML 里指向 `/servicehall/virtualcard/openQrcodeQuotaModify`，
//     该接口与返回的二维码数据**均未在现有抓包中出现**，故无从实现。
//
// 因此这里做**优雅降级**：给出明确说明并提供「打开校园卡网页」的出口，
// 而不是留下一个必然失败的调用。
// 后续若抓到虚拟卡二维码接口，只需替换本视图的数据来源即可。
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:watermeter/repository/shanghaitech/card_session.dart';

class QRCodeView extends StatelessWidget {
  const QRCodeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(FlutterI18n.translate(context, "school_card_window.qr_code")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_2,
            size: 72,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            FlutterI18n.translate(context, "school_card_window.qr_code_unsupported"),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => launchUrlString(
            CardSession.loginPageUrl,
            mode: LaunchMode.externalApplication,
          ),
          child: Text(
            FlutterI18n.translate(context, "school_card_window.open_card_site"),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(FlutterI18n.translate(context, "confirm")),
        ),
      ],
    );
  }
}

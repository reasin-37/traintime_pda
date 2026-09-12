// Copyright 2026 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// 单条听报告登记记录卡片，沿用考试卡片的 ReXCard 视觉。
//
// 注意：`.flexible()` 会包一层 Flexible，只能出现在 Flex/Row/Column 里。
// 因为 bottomRow 是 Wrap（不是 Flex），所以可伸缩的那几个信息必须再包一层
// Flex 才能用 .flexible()——这正是 exam_info_card.dart 的做法。

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:watermeter/model/jzxxtj/activity_report.dart';
import 'package:watermeter/page/public_widget/public_widget.dart';
import 'package:watermeter/page/public_widget/re_x_card.dart';

class ActivityReportCard extends StatelessWidget {
  final ActivityReport toUse;

  const ActivityReportCard({super.key, required this.toUse});

  @override
  Widget build(BuildContext context) {
    return ReXCard(
      title: Text(
        toUse.name.isEmpty
            ? FlutterI18n.translate(context, "activity.unnamed_report")
            : toUse.name,
      ),
      // 右侧显示审核状态：接口返回 SHZT_DISPLAY（如「草稿」）时优先用它。
      remaining: [
        ReXCardRemaining(
          toUse.statusText.isEmpty
              ? FlutterI18n.translate(context, "activity.status_unknown")
              : toUse.statusText,
          isBold: toUse.isEditable,
        ),
      ],
      bottomRow: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          InformationWithIcon(
            icon: Icons.access_time_filled_rounded,
            text: toUse.date,
          ),
          Flex(
            direction: Axis.horizontal,
            children: [
              InformationWithIcon(
                icon: Icons.room,
                text: toUse.place,
              ).flexible(),
              InformationWithIcon(
                icon: Icons.person,
                text: toUse.speaker,
              ).flexible(),
              if (toUse.semester.isNotEmpty)
                InformationWithIcon(
                  icon: Icons.event_note,
                  text: toUse.semester,
                ).flexible(),
            ],
          ),
          if (toUse.hasAttachment)
            InformationWithIcon(
              icon: Icons.attach_file,
              text: FlutterI18n.translate(context, "activity.has_attachment"),
            ),
        ],
      ),
    );
  }
}

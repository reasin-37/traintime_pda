// Copyright 2026 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// 学术活动（听报告登记）首页小卡片，与 ExamCard 同款。

import 'package:flutter/material.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';
import 'package:watermeter/page/homepage/small_function_card.dart';
import 'package:watermeter/page/public_widget/context_extension.dart';
import 'package:watermeter/routing/routes.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SmallFunctionCard(
      onPressed: () => context.pushReplacementNamed(Routes.activity),
      icon: MingCuteIcons.mgc_award_line,
      nameKey: "homepage.toolbox.activity",
    );
  }
}

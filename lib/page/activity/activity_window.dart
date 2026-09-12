// Copyright 2026 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// 学术活动 / 听报告登记 页面。
// 结构照搬 ExamInfoWindow：SignalBuilder + 刷新按钮 + 缓存提示 + 加载遮罩 + 错误重载。

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:signals/signals_flutter.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:watermeter/controller/activity_controller.dart';
import 'package:watermeter/page/activity/activity_report_card.dart';
import 'package:watermeter/page/public_widget/cache_alerter.dart';
import 'package:watermeter/page/public_widget/empty_list_view.dart';
import 'package:watermeter/page/public_widget/loading_alerter.dart';
import 'package:watermeter/page/public_widget/public_widget.dart';

class ActivityWindow extends StatefulWidget {
  const ActivityWindow({super.key});

  @override
  State<ActivityWindow> createState() => _ActivityWindowState();
}

class _ActivityWindowState extends State<ActivityWindow> {
  @override
  void initState() {
    super.initState();
    // 进入页面即拉取一次；重复进入时由 SingleFlight 合并请求。
    ActivityController.i.reloadActivityReports();
  }

  @override
  Widget build(BuildContext context) {
    final c = ActivityController.i;

    return SignalBuilder(
      builder: (context) {
        final state = c.activityStateSignal.value;
        final hasValidReports = c.hasValidReports.value;
        final reports = c.reports.value;
        final isFromCache = c.isFromCache.value;
        final fetchTime = c.fetchTime.value;
        final cacheHintKey = c.cacheHintKey.value;

        return Scaffold(
          appBar: AppBar(
            title: Text(FlutterI18n.translate(context, "activity.title")),
            actions: [
              if (hasValidReports)
                IconButton(
                  icon: const Icon(Icons.update),
                  onPressed: () => c.reloadActivityReports(),
                ),
            ],
          ),
          body: Builder(
            builder: (context) {
              if (hasValidReports) {
                final content = reports.isEmpty
                    ? EmptyListView(
                        type: EmptyListViewType.defaultimg,
                        text: FlutterI18n.translate(
                          context,
                          "activity.no_report",
                        ),
                      )
                    : ListView(
                        children: reports
                            .map((e) => ActivityReportCard(toUse: e))
                            .toList(),
                      );

                final body = Column(
                  children: [
                    if (isFromCache && fetchTime != null)
                      CacheAlerter(
                        dataType: FlutterI18n.translate(context, "activity.title"),
                        hint: FlutterI18n.translate(
                          context,
                          cacheHintKey == null ||
                                  cacheHintKey == "local_cache_hint"
                              ? "cache_reason_default"
                              : cacheHintKey,
                        ),
                        placeOfCache: PlaceOfCache.device,
                        fetchTime: fetchTime,
                      ),
                    Expanded(child: content),
                  ],
                );

                if (!state.isLoading) return body;

                return Stack(
                  children: [
                    Column(
                      children: [
                        AnimatedContainer(
                          height: kTextTabBarHeight,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        Expanded(child: body),
                      ],
                    ),
                    LoadingAlerter(
                      isLoading: true,
                      hint: FlutterI18n.translate(
                        context,
                        "activity.fetching_hint",
                      ),
                      opacity: 0.15,
                      showOverlay: true,
                    ),
                  ],
                );
              } else if (state is AsyncError) {
                return ReloadWidget(
                  function: () => c.reloadActivityReports(),
                  errorStatus: state.error,
                  stackTrace: state.stackTrace,
                ).center();
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        );
      },
    );
  }
}

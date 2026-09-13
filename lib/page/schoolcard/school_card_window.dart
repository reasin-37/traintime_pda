// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// School card log list.
//
// 【本分支改动】原先使用西电模型 `xidian_ids/paid_record.dart` 与
// 西电 session 的 `getPaidStatus()`。上海科技大学的一卡通响应对应到
// `model/shanghaitech/card.dart` 的 `CardTransaction`（摘要 / 金额 / 时间），
// 数据来自 `controller/card_controller.dart`。页面结构与 i18n 键保持不变。
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:intl/intl.dart';
import 'package:signals/signals_flutter.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:time/time.dart';
import 'package:watermeter/controller/card_controller.dart';
import 'package:watermeter/model/shanghaitech/card.dart';
import 'package:watermeter/page/public_widget/empty_list_view.dart';
import 'package:watermeter/page/public_widget/public_widget.dart';

class SchoolCardWindow extends StatefulWidget {
  const SchoolCardWindow({super.key});

  @override
  State<SchoolCardWindow> createState() => _SchoolCardWindowState();
}

class _SchoolCardWindowState extends State<SchoolCardWindow> {
  List<DateTime?> timeRange = [];
  final DateFormat formatter = DateFormat("yyyy-MM-dd");
  final DateFormat timeFormatter = DateFormat("MM-dd HH:mm");

  /// 汇总区间内的收支。
  ///
  /// 一卡通接口的 `txamt` **单位为分、负数为消费**（见
  /// `model/shanghaitech/card.dart` 的说明），故这里用 [CardTransaction.amountYuan]。
  String moneySunUp(List<CardTransaction> theRecord) {
    double sumUp = 0;
    for (final element in theRecord) {
      sumUp += element.amountYuan ?? 0;
    }
    if (sumUp < 0) {
      return FlutterI18n.translate(
        context,
        "school_card_window.expense",
        translationParams: {"expense": (sumUp * -1).toStringAsFixed(2)},
      );
    } else {
      return FlutterI18n.translate(
        context,
        "school_card_window.income",
        translationParams: {"income": sumUp.toStringAsFixed(2)},
      );
    }
  }

  void refreshPaidStatus() {
    if (timeRange.length < 2 || timeRange[0] == null || timeRange[1] == null) {
      return;
    }
    setState(() {
      CardController.i.reloadTransactionsRange(
        startDate: formatter.format(timeRange[0]!),
        endDate: formatter.format(timeRange[1]!),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    timeRange = [now.firstDayOfMonth, now];
    refreshPaidStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "school_card_window.title")),
      ),
      body: Column(
        children: [
          FilledButton(
            child: Text(
              FlutterI18n.translate(
                context,
                "school_card_window.select_range",
                translationParams: {
                  "startDay": formatter.format(timeRange[0]!),
                  "endDay": formatter.format(timeRange[1]!),
                },
              ),
            ),
            onPressed: () async {
              await showCalendarDatePicker2Dialog(
                context: context,
                config: CalendarDatePicker2WithActionButtonsConfig(
                  calendarType: CalendarDatePicker2Type.range,
                  selectedDayHighlightColor:
                      Theme.of(context).colorScheme.primary,
                ),
                dialogSize: const Size(324, 400),
                value: timeRange,
                borderRadius: BorderRadius.circular(16),
              ).then((value) {
                if (value?.length == 1) {
                  timeRange = [value?[0], value?[0]];
                  refreshPaidStatus();
                } else if (value?.length == 2) {
                  timeRange = [value?[0], value?[1]];
                  refreshPaidStatus();
                }
              });
            },
          ).padding(horizontal: 16, vertical: 8),
          SignalBuilder(
            builder: (context) {
              final state = CardController.i.transactionsStateSignal.value;
              return state.map(
                data: (page) => _buildTable(page),
                loading: () => const CircularProgressIndicator().center(),
                refreshing: () => const CircularProgressIndicator().center(),
                reloading: () => const CircularProgressIndicator().center(),
                error: (err, stack) => ReloadWidget(
                  errorStatus: err,
                  stackTrace: stack,
                  function: () async => refreshPaidStatus(),
                ).center(),
              );
            },
          ).expanded(),
        ],
      ),
    );
  }

  Widget _buildTable(CardTransactionPage page) {
    final records = page.rows;
    if (records.isEmpty) {
      return EmptyListView(
        type: EmptyListViewType.singing,
        text: FlutterI18n.translate(context, "school_card_window.no_record"),
      );
    }

    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
    );
    final cellStyle = theme.textTheme.bodyMedium;

    final headerRow = [
      Text(
        FlutterI18n.translate(context, "school_card_window.store_name"),
        style: headerStyle,
        textAlign: TextAlign.center,
      ).expanded(flex: 3),
      Text(
        FlutterI18n.translate(context, "school_card_window.balance"),
        style: headerStyle,
        textAlign: TextAlign.center,
      ).expanded(flex: 2),
      Text(
        FlutterI18n.translate(
          context,
          "school_card_window.time_with_sum",
          translationParams: {"sum": moneySunUp(records)},
        ),
        style: headerStyle,
        textAlign: TextAlign.center,
      ).expanded(flex: 4),
    ].toRow().padding(vertical: 10);

    final dataRows = List<Widget>.generate(records.length, (index) {
      final record = records[index];
      return [
        if (index != 0)
          const Divider(height: 1).constrained(width: sheetMaxWidth),
        [
          Text(
            // 摘要（如「离线码在线消费」）；旧西电模型这里是商户名
            record.summary ?? '',
            style: cellStyle,
            textAlign: TextAlign.center,
          ).expanded(flex: 3),
          Text(
            // 金额（元，两位小数，负数为消费）
            record.amountText,
            style: cellStyle,
            textAlign: TextAlign.center,
          ).expanded(flex: 2),
          Text(
            record.time == null ? '' : timeFormatter.format(record.time!),
            style: cellStyle,
            textAlign: TextAlign.center,
          ).expanded(flex: 4),
        ]
            .toRow()
            .padding(vertical: 10)
            .constrained(width: sheetMaxWidth),
      ].toColumn().width(double.infinity);
    });

    return Column(
      children: [
        headerRow.constrained(width: sheetMaxWidth),
        const Divider(height: 1).constrained(width: sheetMaxWidth),
        Expanded(child: ListView(children: dataRows)),
      ],
    );
  }
}

// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// Library Window.
//
// 【上海科技大学】检索 Tab 已改为 Ex Libris Primo 实现（`primo_search_window.dart`）。
// 借阅 Tab 暂时降级为提示 + 「打开图书馆网站」：
// 借阅记录需登录态，而当前抓包是访客态，尚未拿到借阅接口（详见
// reports/har_analysis_2026-09-13.md §4）。

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:watermeter/page/library/primo_search_window.dart';

/// 图书馆发现系统地址（与 `PrimoLibrarySession` 使用的机构一致）。
const _librarySiteUrl = 'https://discovery.lib.shanghaitech.edu.cn/';

class LibraryWindow extends StatelessWidget {
  const LibraryWindow({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(FlutterI18n.translate(context, "library.title")),
          bottom: TabBar(
            tabs: [
              Tab(
                text: FlutterI18n.translate(
                  context,
                  "library.borrow_state_title",
                ),
              ),
              Tab(
                text: FlutterI18n.translate(
                  context,
                  "library.search_book_title",
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_BorrowUnavailableView(), PrimoSearchWindow()],
        ),
      ),
    );
  }
}

/// 借阅记录的占位视图。
///
/// 说明：上科大图书馆的借阅接口需要登录态，本次抓包为访客态，
/// 因此暂不实现；此处给出明确说明与「打开图书馆网站」的出口，
/// 而不是让用户看到一个请求失败的报错页。
class _BorrowUnavailableView extends StatelessWidget {
  const _BorrowUnavailableView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_library_outlined,
              size: 96,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              FlutterI18n.translate(context, "library.borrow_unavailable"),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () =>
                  launchUrlString(_librarySiteUrl, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: Text(
                FlutterI18n.translate(context, "library.open_library_site"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

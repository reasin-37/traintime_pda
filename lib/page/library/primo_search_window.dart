// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0
//
// 上海科技大学图书馆检索页（Ex Libris Primo）。
//
// 【样式】沿用上游西电版检索页的分页网格与卡片风格（`search_book_window.dart`、
// `book_info_card.dart`），不引入新样式。

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:watermeter/model/shanghaitech/library.dart';
import 'package:watermeter/page/public_widget/public_widget.dart';
import 'package:watermeter/page/public_widget/safe_scroll_padding.dart';
import 'package:watermeter/repository/shanghaitech/primo_library_session.dart';

/// 结果卡片的最小宽度（与西电版 `search_book_constant.dart` 同值语义）。
const double primoResultCardMaxWidth = 320;

class PrimoSearchWindow extends StatefulWidget {
  const PrimoSearchWindow({super.key});

  @override
  State<PrimoSearchWindow> createState() => _PrimoSearchWindowState();
}

class _PrimoSearchWindowState extends State<PrimoSearchWindow>
    with AutomaticKeepAliveClientMixin {
  final _keywordController = TextEditingController();
  final _session = PrimoLibrarySession();

  PrimoSearchField _field = PrimoSearchField.fallback;
  bool _hasSearched = false;

  /// 当前选中的馆藏地过滤条件（null = 不过滤）。
  ///
  /// 【为什么是客户端过滤】馆藏地来自每条记录自身（解析 `rtaResultsLink` 得到的
  /// `holdings[].location`），**不是 Primo 的分面维度**——实测响应里的分面只有
  /// `library`（分馆，值如 MAIN）、`rtype`、`lang` 等，没有 sub-location；
  /// 且 `facet=` / `qInclude=` 参数实测对结果无任何影响（total 不变）。
  /// 因此这里对**已加载的结果**做过滤。
  ///
  /// ⚠️ 局限：Primo 按页返回（每页 10 条），故过滤只作用于已加载的页；
  /// 未加载的页需要继续滚动加载后才会纳入过滤范围。UI 中已提示这一点。
  String? _locationFilter;

  late final PagingController<int, LibraryBook> _pagingController =
      PagingController<int, LibraryBook>(
        getNextPageKey: (state) =>
            state.lastPageIsEmpty ? null : state.nextIntPageKey,
        fetchPage: _fetchPage,
      );

  /// 已加载结果里出现过的馆藏地（去重、保序）。
  List<String> get _availableLocations {
    final list = _pagingController.value.items ?? const <LibraryBook>[];
    final seen = <String>{};
    for (final b in list) {
      for (final l in b.locations) {
        if (l.isNotEmpty) seen.add(l);
      }
    }
    return seen.toList()..sort();
  }

  /// 按当前过滤条件筛选已加载的结果。
  ///
  /// 过滤开启时，**没有馆藏地的记录（如纯电子资源）不显示**——
  /// 因为用户明确要看「某个馆藏地」的书。
  List<LibraryBook> _filteredBooks(List<LibraryBook> source) {
    final filter = _locationFilter;
    if (filter == null) return source;
    return source.where((b) => b.locations.contains(filter)).toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _keywordController.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  Future<List<LibraryBook>> _fetchPage(int pageKey) async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return const [];

    final result = await _session.searchBooks(
      keyword,
      field: _field.field,
      page: pageKey,
    );
    final data = result.data;
    // 页首提示用：命中总数 + 已显示条数
    final shown = _shown + data.books.length;
    if ((data.total != _total || shown != _shown) && mounted) {
      setState(() {
        _total = data.total;
        _shown = shown;
      });
    }
    return data.books;
  }

  int _total = 0;
  int _shown = 0;

  void _submitSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _hasSearched = true;
      _total = 0;
      _shown = 0;
      _locationFilter = null; // 新搜索时清掉上一轮的馆藏地过滤
    });
    _pagingController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildSearchBar(context),
        if (_hasSearched && _total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                FlutterI18n.translate(
                  context,
                  "library.result_total",
                  translationParams: {
                    'total': _total.toString(),
                    'shown': _shown.toString(),
                  },
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        if (_hasSearched) _buildLocationFilter(context),
        if (_hasSearched) Expanded(child: _buildResultList()),
      ],
    );
  }

  /// 馆藏地过滤条（仅当已加载结果里出现 ≥1 个馆藏地时才显示）。
  Widget _buildLocationFilter(BuildContext context) {
    final locations = _availableLocations;
    if (locations.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
            child: Center(
              child: Text(
                FlutterI18n.translate(context, "library.filter_by_location"),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          FilterChip(
            label: Text(FlutterI18n.translate(context, "library.filter_clear")),
            selected: _locationFilter == null,
            onSelected: (_) => setState(() => _locationFilter = null),
          ),
          for (final loc in locations)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilterChip(
                label: Text(loc),
                selected: _locationFilter == loc,
                onSelected: (_) => setState(
                  () => _locationFilter = _locationFilter == loc ? null : loc,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitSearch(),
                  decoration: InputDecoration(
                    hintText: FlutterI18n.translate(
                      context,
                      "library.search_here",
                    ),
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submitSearch,
                child: Text(FlutterI18n.translate(context, "library.search")),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                FlutterI18n.translate(context, "library.search_field_title"),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<PrimoSearchField>(
                  initialValue: _field,
                  isDense: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final f in PrimoSearchField.all)
                      DropdownMenuItem(
                        value: f,
                        child: Text(FlutterI18n.translate(context, f.labelKey)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _field = v);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 按当前过滤条件生成新的分页状态（保留分页元信息，只替换 pages 内容）。
  ///
  /// `PagedMasonryGridView` 从 `state.pages` 取数据、且不接受 `items` 参数，
  /// 故这里用 `copyWith` 换掉 pages；`keys` / `hasNextPage` / `isLoading` 等保持不变，
  /// 因此「继续加载下一页」的行为不受影响。
  PagingState<int, LibraryBook> _filteredState(
    PagingState<int, LibraryBook> state,
  ) {
    if (_locationFilter == null) return state;
    final pages = state.pages;
    if (pages == null) return state;
    return state.copyWith(
      pages: [for (final p in pages) _filteredBooks(p)],
    );
  }

  Widget _buildResultList() {
    return PagingListener(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) => LayoutBuilder(
        builder: (context, constraints) {
          return PagedMasonryGridView<int, LibraryBook>.count(
            state: _filteredState(state),
            fetchNextPage: fetchNextPage,
            padding: const EdgeInsets.all(4).withSafeBottom(context),
            crossAxisCount: max(
              1,
              constraints.maxWidth ~/ primoResultCardMaxWidth,
            ),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            builderDelegate: PagedChildBuilderDelegate<LibraryBook>(
              itemBuilder: (context, item, index) => _PrimoBookCard(book: item),
              firstPageProgressIndicatorBuilder: (context) =>
                  const Center(child: CircularProgressIndicator()),
              firstPageErrorIndicatorBuilder: (context) => ReloadWidget(
                function: () async => _pagingController.refresh(),
                errorStatus: _pagingController.error,
              ),
              noItemsFoundIndicatorBuilder: (context) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, size: 96.0),
                      const SizedBox(height: 16),
                      Text(
                        FlutterI18n.translate(context, "library.no_result"),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              noMoreItemsIndicatorBuilder: (context) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    FlutterI18n.translate(context, "library.no_more_data"),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 单条检索结果卡片。
///
/// 展示字段取自 Primo 实测可用的部分（题名/责任者/出版社/年份/索书号/馆藏地与可借状态），
/// 与上游 `book_info_card.dart` 的信息口径一致。
class _PrimoBookCard extends StatelessWidget {
  final LibraryBook book;
  const _PrimoBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locations = book.locations;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              book.title.isEmpty
                  ? FlutterI18n.translate(context, "library.not_provided")
                  : book.title,
              style: theme.textTheme.titleMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (book.authors.isNotEmpty)
              Text(
                FlutterI18n.translate(context, "library.author") +
                    book.authors.join('、'),
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (book.publisher != null)
              Text(
                FlutterI18n.translate(context, "library.publish_house") +
                    book.publisher!,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (book.publishDate != null)
              Text(
                FlutterI18n.translate(context, "library.publish_date") +
                    book.publishDate!,
                style: theme.textTheme.bodySmall,
              ),
            if (book.callNumber != null)
              Text(
                FlutterI18n.translate(context, "library.call_number") +
                    book.callNumber!,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 6),
            _buildStatus(context, theme, locations),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(
    BuildContext context,
    ThemeData theme,
    List<String> locations,
  ) {
    // 电子资源：无物理馆藏
    if (book.isElectronic && book.holdings.isEmpty) {
      return Text(
        FlutterI18n.translate(context, "library.subject"),
        style: theme.textTheme.labelSmall,
      );
    }

    final holding = book.holdings.isNotEmpty ? book.holdings.first : null;
    final statusText = holding == null
        ? FlutterI18n.translate(context, "library.status_unknown")
        : FlutterI18n.translate(context, holding.statusKey);

    final available = book.hasAvailableCopy;
    return Row(
      children: [
        Icon(
          available ? Icons.check_circle_outline : Icons.info_outline,
          size: 16,
          color: available
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            locations.isEmpty ? statusText : '${locations.first} · $statusText',
            style: theme.textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

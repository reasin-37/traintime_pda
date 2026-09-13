// Copyright 2025 Hazuki Keatsu.
// SPDX-License-Identifier: MPL-2.0

/// Score recognition result
///
/// 说明：物理实验成绩图片识别（依赖西电实验报告系统与本地 tflite /
/// 图片哈希素材）已随西电专有系统一并下架，识别服务已移除。
/// 此处只保留 [ExperimentData] 序列化所需的纯数据类，使
/// `model/xidian_ids/experiment.dart` 与 `experiment.g.dart` 不受影响。
class RecognitionResult {
  final String label;
  final bool found;
  final String rawUrl;

  const RecognitionResult({
    required this.label,
    required this.found,
    required this.rawUrl,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) =>
      RecognitionResult(
        label: json['label'] as String,
        found: json['found'] as bool,
        rawUrl: json['rawUrl'] as String,
      );

  Map<String, dynamic> toJson() => {
    'label': label,
    'found': found,
    'rawUrl': rawUrl,
  };

  @override
  String toString() =>
      'RecognitionResult(label: $label, found: $found, rawUrl: $rawUrl)';
}

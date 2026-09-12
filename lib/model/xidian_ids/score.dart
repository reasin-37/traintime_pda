// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// ignore_for_file: non_constant_identifier_names

import 'package:json_annotation/json_annotation.dart';

part 'score.g.dart';

@JsonSerializable(explicitToJson: true)
class Score {
  int mark; // 编号，用于某种计算，从 0 开始
  String name; // 学科名称
  double? score; // 分数
  String semesterCode; // 学年
  double credit; // 学分
  String classStatus; // 课程性质，必修，选修等，
  String classType; // 课程类别
  // DJCJLXDM 01 三级成绩 02 五级成绩 03 两级成绩
  String scoreStatus; // 修读类型类型，重修重考等
  int scoreTypeCode; // 评分方式
  String? level; // 等级
  String? isPassedStr; //是否及格，null 没出分，1 通过 0 没有
  String? classID; // 教学班序列号

  Score({
    required this.mark,
    required this.name,
    required this.score,
    required this.semesterCode,
    required this.credit,
    required this.classStatus,
    required this.isPassedStr,
    required this.scoreTypeCode,
    required this.classType,
    required this.scoreStatus,
    this.level,
    this.classID,
  });

  bool? get isPassed {
    if (isPassedStr == null || isPassedStr == "null") return null;
    return isPassedStr == "1";
  }

  String get scoreStr {
    if (score != null) {
      switch (scoreTypeCode) {
        case 1:
        case 3:
        case 2:
          return level.toString();
        default:
          return score!.toInt().toString();
      }
    } else if (isPassedStr == null) {
      return "暂无";
    } else if (isPassedStr!.contains('0')) {
      return "暂无但未及格";
    } else {
      return "暂无但及格";
    }
  }

  bool get isFinish => isPassed != null && score != null;

  /// 上海科技大学：采用通过制（P/NP）的课程不计入 GPA。
  ///
  /// 判定依据是等级字段 [level]（来自金智 `CJXSZ`）为 `P` 或 `NP`。
  bool get isPassFailCourse {
    final grade = level?.trim().toUpperCase();
    return grade == "P" || grade == "NP";
  }

  /// 上海科技大学绩点（4.0 制，等级制）。
  ///
  /// 校方规则：A+/A = 4.0、A- = 3.7、B+ = 3.3、B = 3.0、B- = 2.7、
  /// C+ = 2.3、C = 2.0、C- = 1.7、F = 0；采用通过制（P/NP）的课程不计入 GPA。
  ///
  /// 原实现是西电的换算表（"优秀/良好/中等/及格"五级制 + 另一套百分制分段），
  /// 与上科大不通用，故整体替换。下面的百分制分段取自校方给出的"仅供参考"列，
  /// 仅用于响应里只带数值分数（[level] 为空）时的回退换算。
  double get gpa {
    if (!isFinish) {
      return 0.0;
    }

    // 优先按字母等级换算
    switch (level?.trim().toUpperCase()) {
      case "A+":
      case "A":
        return 4.0;
      case "A-":
        return 3.7;
      case "B+":
        return 3.3;
      case "B":
        return 3.0;
      case "B-":
        return 2.7;
      case "C+":
        return 2.3;
      case "C":
        return 2.0;
      case "C-":
        return 1.7;
      case "F":
        return 0.0;
      // 通过制课程不计入 GPA（同时由 ScoreState._evalCount 整体排除）
      case "P":
      case "NP":
        return 0.0;
    }

    // 回退：只有百分制分数时，按上科大等级制的分数段换算
    final mark = score;
    if (mark == null) {
      return 0.0;
    }
    if (mark >= 90) {
      return 4.0; // A+ / A
    } else if (mark >= 85) {
      return 3.7; // A-
    } else if (mark >= 80) {
      return 3.3; // B+
    } else if (mark >= 75) {
      return 3.0; // B
    } else if (mark >= 70) {
      return 2.7; // B-
    } else if (mark >= 67) {
      return 2.3; // C+
    } else if (mark >= 63) {
      return 2.0; // C
    } else if (mark >= 60) {
      return 1.7; // C-
    }
    return 0.0; // F
  }

  factory Score.fromJson(Map<String, dynamic> json) => _$ScoreFromJson(json);

  Map<String, dynamic> toJson() => _$ScoreToJson(this);
}

class ComposeDetail {
  String content;
  String ratio;
  String score;
  ComposeDetail({
    required this.content,
    required this.ratio,
    required this.score,
  });
}

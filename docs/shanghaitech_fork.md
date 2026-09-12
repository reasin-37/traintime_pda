# 上海科技大学适配分支说明（非官方）

> 本文件是本分支**新增**的说明文档，用于记录相对上游的全部修改，便于原作者与使用者核对。
> 依据：上游 `docs/faq.md` 中作者关于"将该软件适配到您学校"的说明，以及 MPL-2.0 §3.1/§3.2 的分发义务。

---

## 一、这是什么

- **上游项目**：[BenderBlog/traintime_pda](https://github.com/BenderBlog/traintime_pda)（XDYou / Traintime PDA，作者 **BenderBlog Rodriguez** 及贡献者）
- **本分支**：把该 App 的数据来源从**西安电子科技大学**换成**上海科技大学**的**个人自用**适配分支
- **基准版本**：上游 tag **`v1.6.6`**（`pubspec.yaml` 中 `version: 1.6.6+50`）
  - 已验证：上游 `v1.6.6` 标签与 `main` 分支在该时点内容完全一致
- **非官方声明**：本分支与上海科技大学官方**无任何关系**，不是学校发布的软件

## 二、授权

- 上游代码按 **Mozilla Public License 2.0** 授权（见 `LICENSE`）。部分文件另有 MIT / Apache-2.0 授权，标注在各文件头部的 `SPDX-License-Identifier`。
- **本分支对文件的修改，同样以 MPL-2.0 公开**（符合 MPL-2.0 §3.1/§3.2 对分发修改版的要求）。
- **未删除或修改任何文件原有的 `SPDX-License-Identifier` 许可头**（可逐文件核对）。
- 未使用上游 `assets/README.MD` 中标注"版权所有，作者保留一切权利"的素材来标识本分支的编译产物；本分支**不发布任何二进制版本**。
- 上游 `docs/xdyou_eula.md` 明确"仅对 iOS 或 Mac **签名**版本有效"且"从代码编译而**没有签名**的产物不受该协议约束"，故本分支（Windows 未签名构建）不涉及该 EULA。

## 三、改动清单（相对 `v1.6.6`）

**共 16 个文件**：15 个修改 + `README.md` 顶部新增分支声明 + 本文件（新增）。
除此之外**其余文件与 `v1.6.6` 逐字节一致**；**没有任何上游文件被删除**。

> 核对方式：`git diff v1.6.6 --stat`（若本仓库保留了上游历史）。

### 3.1 认证层（统一认证 / IDS）

| 文件 | 改动 |
|---|---|
| `lib/repository/ids_session/ids_session.dart` | ① 统一认证域名 `ids.xidian.edu.cn` → `ids.shanghaitech.edu.cn`；② **登录密码加密改用金智通用方案**（`network_client.dart` 的 `aesEncrypt`）——原实现是西电私有变体（固定 IV `xidianscriptsxdu` + 固定 64 字节前缀），对本校无效；③ `checkWhetherPostgraduate()` 的目标改为上科大研究生门户 |
| `lib/repository/ids_session/ids_auth_protocol.dart` | SSO origin 与 host 判断 |
| `lib/repository/ids_session/ids_reauth_client.dart` | 二次认证相关 URL 的 host |
| `lib/repository/ids_session/slider_captcha_client.dart` | ① host；② **滑块验证码几何参数**：`280×155 / 44×155` → `500×332 / 85×331`（本校实测） |
| `lib/repository/logger.dart` | 敏感 host 白名单（否则新校 SSO 的 ticket 会写入日志） |

### 3.2 登录后功能可用性的关键修复

| 文件 | 改动 |
|---|---|
| `lib/controller/homepage_controller.dart` | `_comboLogin()` 的 CAS `service` 由西电 ehall（`ehall.xidian.edu.cn`）改为上科大研究生门户地址。**原代码会导致**：拿不到 ticket → `loginState` 被置为 `fail` → 全局离线守卫拦截所有请求，表现为"课表/成绩/考试全部无法查看且不发出任何请求" |

### 3.3 三大功能（课表 / 成绩 / 考试）数据源

| 文件 | 改动 |
|---|---|
| `lib/repository/ids_session/semester_session.dart` | 学期信息接口 host；CAS target 改用本校已注册的门户地址 |
| `lib/repository/ids_session/classtable_session.dart` | 课表模块 `sys/wdkbapp/` → `sys/wdkbappshtech/`（本校定制模块名）；其余 host |
| `lib/repository/ids_session/score_session.dart` | 成绩接口 host |
| `lib/repository/ids_session/exam_session.dart` | 考试接口 host |

### 3.4 本校规则替换

| 文件 | 改动 |
|---|---|
| `lib/model/time_list.dart` | 作息表：西电 **11 节**（08:30–21:25）→ 上科大 **13 节**（08:15–09:00 … 20:45–21:30） |
| `lib/model/xidian_ids/score.dart` | 绩点换算：西电规则 → **上科大 4.0 等级制**（A+/A=4.0、A-=3.7、B+=3.3、B=3.0、B-=2.7、C+=2.3、C=2.0、C-=1.7、F=0），并新增 `isPassFailCourse` 识别通过制（P/NP） |
| `lib/page/score/score_state.dart` | 均分/GPA 统计排除通过制（P/NP）课程（落实"采用通过制的课程不计入 GPA"） |

### 3.5 其它

| 文件 | 改动 |
|---|---|
| `lib/model/xidian_ids/classtable.dart` | 移除多余的 `package:flutter/foundation.dart` 依赖（该文件仅用到 `listEquals`，已本地实现），使课表模型可在纯 Dart 下做离线解析测试。语义不变 |
| `lib/repository/notification/notification_service.dart` | 补上 `WindowsInitializationSettings`：上游在 Windows 上初始化通知会抛 `Windows settings must be set when targeting Windows platform` |
| `README.md` | 顶部新增"非官方分支"声明 |
| `docs/shanghaitech_fork.md` | 本文件（新增） |

## 四、已知限制（未适配的部分）

以下功能连接的是**西电专有系统**，在本校对上海科技大学**不可用**，界面上仍会显示并报错：

电费、校园卡、图书馆、校园网、物理实验/实验报告、空教室、考勤、睿思论坛、XDU Planet、体育。

已适配并验证可用：**统一认证登录、课表、成绩、考试**（研究生）。

## 五、构建说明

- Flutter：**stable 3.47.x**（本分支实测 3.47.4 / Dart 3.13.3）
- **Windows 桌面**额外需要：
  - Visual Studio（**不是** VS Code）的「使用 C++ 的桌面开发」工作负载，含 Windows SDK 与 C++ CMake 工具；
  - **C++ ATL** 组件（`flutter_local_notifications_windows` 需要 `atlbase.h`）；
  - 系统「开发人员模式」已开启（插件符号链接需要）。
- 常用命令：`flutter pub get` → `flutter analyze` → `flutter run -d windows`

## 六、致谢

- 上游作者 **BenderBlog Rodriguez** 及全部贡献者（名单见 `lib/page/setting/about_page/about_page.dart` 的 `getDevelopers`）。
- 本分支的适配工作基于上游代码完成，未改变上游的授权方式。

> 如原作者对本分支的任何改动有异议，请通过 Issue 联系，我会立即调整或撤下。

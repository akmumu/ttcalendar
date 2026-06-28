# 自定义特殊日期功能

## 功能概述

新增自定义特殊日期功能，允许用户在主 App 中添加、编辑和管理重要日期（生日、会议、纪念日等），这些日期会在小组件中以特殊样式显示，并支持倒计时。

## 主要特性

### 1. 日期类型
- **生日** - 默认标记"生"
- **会议** - 默认标记"会"
- **纪念日** - 默认标记"念"
- **自定义** - 默认标记"特"

### 2. 显示效果
- **浅紫色背景** (Color.purple.opacity(0.14)) - 区别于其他特殊日期
- **右上角单字标记** - 用户可自定义显示的字符
- **紫色文字** - 日期数字和副标题均为紫色

### 3. 倒计时功能
- 小组件会优先显示最近的特殊日期倒计时
- 在超大型组件中，如果有自定义特殊日期，会替换"今天"信息显示倒计时
- 使用紫色主题色和星形图标

### 4. 数据持久化
- 使用 App Group 共享存储 (group.akmumu.ttcalendar)
- 主 App 和小组件共享数据
- 支持每年重复选项

## 实现细节

### 新增文件

1. **Shared/CustomSpecialDate.swift**
   - `CustomSpecialDate` 数据模型
   - `CustomSpecialDateStore` 存储管理器
   - 支持 CRUD 操作

2. **ttcalendar/CustomDateManagementView.swift**
   - 日期列表展示
   - 添加/编辑界面
   - 实时预览效果

### 修改文件

1. **Shared/CalendarContent.swift**
   - `CalendarDay` 添加 `customSpecialDate` 和 `isCustomSpecialDate` 属性
   - `upcomingHighlights` 方法支持自定义日期的倒计时计算
   - 在生成日历时查询自定义日期

2. **CalendarWidget/CalendarWidget.swift**
   - `WidgetDayCell` 支持显示自定义标记
   - 自定义日期使用紫色背景和文字
   - 修改 `ExtraLargeBottomRow` 和 `ExtraLargeInfoBar` 支持自定义日期倒计时
   - 添加 `isCustomSpecialDay` 辅助方法判断是否为自定义日期

3. **ttcalendar/ContentView.swift**
   - 添加"自定义特殊日期"管理区域
   - 集成 `CustomDateManagementView`

## 使用方法

1. 打开"抬头日历"主 App
2. 找到"自定义特殊日期"区域
3. 点击"添加"按钮
4. 填写以下信息：
   - 名称（最多三个字，如"妈生日"）
   - 类型（生日/会议/纪念日/自定义）
   - 月份和日期
   - 是否每年重复
   - 右上角显示字符（一个字）
5. 点击"保存"
6. 小组件会自动刷新显示

## 视觉设计

### 颜色方案
- **紫色主题**: 与现有的红色（节假日）、橙色（调休）、粉色（休息日）形成区分
- **背景色**: `Color.purple.opacity(0.14)`
- **文字色**: `.purple`
- **图标**: `star.fill` (星形)

### 布局
- 日历格子: 浅紫色背景，右上角显示自定义标记
- 倒计时栏: 紫色边框，星形图标
- 超大型组件: 替换"今天"信息为自定义日期倒计时

## 注意事项

1. 名称限制为最多三个字，右上角自定义标记限制为单个字符
2. 数据存储在 App Group 中，卸载应用会丢失数据
3. 小组件会在添加/编辑/删除后自动刷新
4. 如果同一天有多个特殊标记，自定义日期会优先显示在日历格子的副标题中
5. 倒计时优先显示最近的特殊日期（包括自定义日期）

## 技术栈

- SwiftUI
- WidgetKit
- App Groups (数据共享)
- UserDefaults (持久化存储)
- Codable (序列化)

## 未来优化建议

1. 支持更多日期类型和图标
2. 支持农历日期
3. 支持提醒通知
4. 支持导入/导出功能
5. 支持 iCloud 同步
6. 支持自定义颜色主题
7. 支持倒计时完成后的庆祝动画

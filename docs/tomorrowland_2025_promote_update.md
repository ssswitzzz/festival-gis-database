# Tomorrowland 2025 Official Lineup Promotion Update

更新时间：2026-06-21

## 本次完成内容

已执行 `sql/12_promote_tomorrowland_2025_official_lineup.sql`，将 `stg_tomorrowland_2025_*` staging 表中的官方 lineup/timetable 数据提升到核心业务表。

## 执行结果

| 操作 | 结果 |
| :--- | ---: |
| 更新 Tomorrowland 2025 届次日期 | 1 |
| 重命名复用 seed 舞台 | 3 |
| 新增官方舞台 | 14 |
| 新增官方艺人 | 721 |
| 删除 Tomorrowland seed 演出 | 4 |
| 插入官方演出记录 | 864 |

说明：staging 中官方 performance block 为 809 条；其中 806 条满足 `end_time > start_time`，3 条为开始和结束时间相同的 MC/host 标注，未进入正式 `performances`。

## 当前核心表状态

| 指标 | 数值 |
| :--- | ---: |
| Tomorrowland 2025 官方舞台 | 17 |
| `artists` 总数 | 731 |
| Tomorrowland 2025 正式 performance block | 806 |
| Tomorrowland 2025 performance-artist 关联 | 864 |

官方时刻表覆盖范围：

```text
first_start: 2025-07-17 13:00:00
last_end:    2025-07-28 00:00:00
```

`festival_editions` 中 Tomorrowland 2025 的日期已经由原 seed 范围 `2025-07-18` 至 `2025-07-27` 更新为官方 timetable 覆盖范围 `2025-07-17` 至 `2025-07-28`。

## 已更新导出文件

已重新导出：

- `exports/tomorrowland_2025_timetable.csv`

该文件现在来自 `v_tomorrowland_2025_timetable`，共 864 行。视图按艺人展开，因此多人合作演出会出现多行；底层 `performances` 表保留 806 个有效官方节目块。

## 多对多模型更新

已新增并启用 `performance_artists` 多对多表：

- `performances`：表示一个演出节目块，保存舞台、官方节目 ID、节目名、开始时间、结束时间和估计观众数。
- `performance_artists`：表示节目块与艺人的关联，支持一个节目块对应多个艺人，并通过 `artist_order` 保留艺人在官方字段中的顺序。

相关迁移脚本：

- `sql/13_add_performance_artists_model.sql`

相关基础脚本也已同步：

- `sql/01_schema.sql`
- `sql/02_seed_data.sql`
- `sql/03_analysis_queries.sql`
- `sql/05_views.sql`
- `sql/12_promote_tomorrowland_2025_official_lineup.sql`

## 后续建议

1. 为 Tomorrowland 增加按日期、舞台统计演出数量的报告视图。
2. 继续寻找 Tomorrowland 2025 票价、观众规模来源，用于补齐 `ticket_types` 和 `festival_editions.expected_attendance` 的数据真实性说明。

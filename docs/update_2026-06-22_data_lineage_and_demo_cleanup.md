# 数据血缘审计与演示样本清理记录

日期：2026-06-22

## 背景

检查数据库时发现若干表存在“前几行字段较完整，后续行字段为空”的现象。这不是导入错误，而是项目早期为了验证 schema、空间分析和查询流程，先写入了一批演示/种子数据；随后又逐步导入了官方页面、OpenStreetMap、EEA Natura 2000、OurAirports 等公开数据。

因此，同一张表中会混合出现：

- `manual_seed`：早期手工样本或估算值；
- `official_wayback`：Wayback 中保存的官方结构化页面数据；
- `openstreetmap`：OSM/Overpass 导入的数据；
- `eea_natura2000`：EEA Natura 2000 导入的数据；
- `ourairports`：OurAirports 机场数据；
- `not_provided`：源数据没有提供该字段，数据库保留为空。

## 字段缺失原因

| 表/字段 | 当前现象 | 原因 | 处理 |
| --- | --- | --- | --- |
| `artists.country` | 731 个艺人中只有 10 个有国家 | 前 10 个来自 seed；Tomorrowland 官方 lineup JSON 不提供艺人国家 | 不删除艺人；保留空值，文档说明 |
| `stages.capacity` | 22 个舞台中 8 个有容量 | seed 舞台带估算容量；官方 lineup 只提供舞台名和演出安排 | 不删除舞台；容量为空表示源数据未提供 |
| `performances.estimated_crowd` | 813 条演出中只有少数有估计人数 | seed 演出带估计人数；官方 timetable 不提供单场观众数 | 不删除官方演出；估计人数为空 |
| `candidate_sites` | 前 5 个手工候选与后 45 个 OSM 候选不同 | 前 5 个是早期工作流样本；后续已导入 OSM 候选地 | 删除 5 个手工候选 |
| `ecological_protected_areas` | 前 3 个手工保护区与后 498 个 EEA 数据不同 | 前 3 个是简化样本；后续已导入 EEA Natura 2000 | 删除 3 个手工保护区 |
| `noise_sensitive_facilities.city/country` | 前 6 个有城市和国家，后续多为空 | 前 6 个是手工敏感点；OSM POI 没有做行政区反查 | 删除 6 个手工敏感点；保留 OSM 点位 |
| `transport_hubs.city/country/daily_capacity` | 前 6 个较完整，后续多为空 | 前 6 个是早期交通枢纽样本；后续为 OSM/OurAirports 导入 | 删除 6 个早期样本；保留公开数据 |
| `ticket_types.quota` | 部分配额仍为估算 | 官网票价页面提供价格，不提供 quota | 保留为模拟字段；官方价格进入 `ticket_price_offers` |

## 已清理的演示样本

清理脚本：`sql/17_remove_replaced_demo_samples.sql`

本次删除范围：

| 表 | 删除条件 | 原因 |
| --- | --- | --- |
| `candidate_sites` | `is_manual_sample = true` | OSM 候选地已替代手工候选 |
| `ecological_protected_areas` | `data_source LIKE 'Manual simplified polygon%'` | EEA Natura 2000 已替代简化保护区 |
| `noise_sensitive_facilities` | `data_source ILIKE '%Manual%' OR data_source ILIKE '%approximated%'` | OSM 敏感点已替代手工点 |
| `transport_hubs` | 早期 `OurAirports / public airport coordinates` 与 `Public railway station coordinates` | OSM/OurAirports 正式导入已替代 |

注意：`site_evaluations` 对 `candidate_sites` 是 `ON DELETE CASCADE`，因此删除 5 个手工 candidate site 时，对应 5 条早期手工评分也会一起删除。

## 暂不删除的数据

以下数据虽然含有空字段，但不是“无用演示样本”，不能直接删除：

| 表 | 暂不删除原因 |
| --- | --- |
| `artists` | 官方 Tomorrowland 2025 lineup 已关联大量艺人；国家为空是源数据未提供 |
| `stages` | Tomorrowland 官方演出已关联舞台；容量为空是源数据未提供 |
| `performances` | 官方 timetable 的核心成果，不能因 `estimated_crowd` 为空删除 |
| `ticket_types` | 部分票种仍作为业务实体和报价明细 FK 使用；quota 模拟需文档说明 |
| Defqon.1 / Awakenings 的 seed 业务数据 | 这两个节日尚未完成与 Tomorrowland 同等深度的官方业务抓取，暂时作为跨节日 schema 示例保留 |

## 后续建议

1. 增加统一 `source_evidence` 或 `data_quality_flags` 表，给字段级来源做规范化标注。
2. 对 OSM 点位补做行政区反查，填充 `city`、`country`。
3. 如果继续深入 Defqon.1 / Awakenings，也应像 Tomorrowland 一样用官方/Wayback 数据替换早期 seed。
4. 在最终报告中明确：空值不是错误，而是“源数据未提供”，比继续编造字段更可信。

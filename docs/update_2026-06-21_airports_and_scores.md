# 2026-06-21 数据更新：机场数据与候选地评分

## 本轮完成内容

本轮基于用户下载的 `data/raw/airports.csv`，完成了 OurAirports 机场数据导入，并用当前真实空间数据重算了候选地评分。

## 新增文件

| 文件 | 作用 |
| :--- | :--- |
| `scripts/import_ourairports.ps1` | 将 `data/raw/airports.csv` 导入暂存表 `stg_ourairports_airports` |
| `sql/08_normalize_ourairports.sql` | 筛选 Belgium/Netherlands 代表性机场并合并到 `transport_hubs` |
| `sql/09_recalculate_site_scores.sql` | 基于真实空间数据重新计算 `site_evaluations` |

## OurAirports 导入规则

为了避免直升机场、私人小机场和已关闭机场影响“机场可达性”评分，正式表只导入：

- `iso_country IN ('BE', 'NL')`
- `type IN ('large_airport', 'medium_airport')`
- 或 `type = 'small_airport' AND scheduled_service = 'yes'`
- 排除 2 km 内已有机场点或同名机场，避免与 OSM 机场重复

导入结果：

| 指标 | 数量 |
| :--- | ---: |
| OurAirports 新增机场 | 18 |
| `transport_hubs` 当前机场总数 | 33 |
| `transport_hubs` 当前总数 | 353 |

## 评分重算结果

旧的 `site_evaluations` 只有 5 条演示评分。本轮已替换为 50 条真实空间评分，覆盖全部候选地。

评分使用的数据：

- 最近机场距离：`transport_hubs`
- 25 km 周边加权人口：`population_grids`
- 最近 Natura 2000 距离：`ecological_protected_areas`
- 最近高敏感设施距离：`noise_sensitive_facilities`

评分汇总：

| 指标 | 数值 |
| :--- | ---: |
| 评分记录数 | 50 |
| 最低总分 | 29.41 |
| 最高总分 | 58.71 |
| 平均总分 | 43.07 |

当前 Top 5：

| 排名 | 候选地 | 总分 |
| ---: | :--- | ---: |
| 1 | Kempen rural recreation candidate | 58.71 |
| 2 | Flevoland open grassland candidate | 58.41 |
| 3 | Molecaten Parc Flevostrand | 53.92 |
| 4 | Tivolipark | 51.72 |
| 5 | Boom recreation candidate near De Schorre | 49.13 |

## 性能调整

真实 Eurostat/GISCO 人口格网导入后，原 `v_dynamic_site_scores` 使用 50 km 人口范围现场计算，查询较慢。本轮已优化为：

- 使用 LATERAL 最近邻查询计算最近机场、保护区和敏感设施
- 人口覆盖半径调整为 25 km
- 人口查询增加空间索引预筛选：`geom_polygon && ST_Expand(...)`

优化后 `v_dynamic_site_scores` 可以在真实数据量下正常返回 50 条候选地评分。

## 当前核心表规模

| 表 | 行数 |
| :--- | ---: |
| `candidate_sites` | 50 |
| `ecological_protected_areas` | 501 |
| `noise_sensitive_facilities` | 304 |
| `population_grids` | 69,938 |
| `site_evaluations` | 50 |
| `transport_hubs` | 353 |

## 下一步建议

1. 已在 2026-06-22 增加 `v_site_score_explanation`，把每个候选地的原始距离、人口覆盖、敏感设施风险展示出来。
2. 已导出新的候选地评分解释 CSV 和动态评分 Top20，用于报告和 QGIS 制图。
3. 后续仍建议用 OSM 边界替换 `venues.geom_polygon` 的近似矩形，优先处理 De Schorre。

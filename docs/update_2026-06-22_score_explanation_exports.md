# 2026-06-22 数据更新：评分解释视图与最新导出

## 本轮完成内容

本轮在已有候选地评分结果基础上，新增了面向报告解释和 QGIS 展示的评分解释视图，并重新导出最新空间分析 CSV。

## 新增/更新对象

| 对象 | 作用 |
| :--- | :--- |
| `v_site_score_explanation` | 展开每个候选地的评分、最近机场、25 km 人口覆盖、最近保护区、最近噪声敏感设施和敏感设施数量 |
| `exports/site_score_explanation.csv` | 评分解释导出表，共 50 条候选地记录 |
| `exports/dynamic_site_scores_top20.csv` | 最新动态评分 Top 20 |
| `exports/affected_population_5km.csv` | 基于当前真实人口网格刷新的 5 km 影响人口估算 |
| `exports/real_venue_match_validation.csv` | 基于当前评分刷新的真实场地匹配验证 |

## 评分解释视图字段

`v_site_score_explanation` 保留候选地几何字段 `geom_polygon`，可直接供 QGIS 使用。报告导出 CSV 中去掉了几何字段，保留以下解释字段：

- 候选地基本信息：`site_id`、`name`、`terrain_type`、`area_sqm`、`is_manual_sample`
- 分项评分：`airport_score`、`population_score`、`ecology_safety_score`、`noise_safety_score`、`total_score`
- 机场解释：最近机场名称、城市、国家、距离、80 km 内机场数量
- 人口解释：25 km 原始人口、25 km 加权人口、参与统计的人口网格数量
- 生态解释：最近保护区名称、类型、距离、是否与保护区相交
- 噪声解释：最近高敏感设施名称、类型、敏感等级、距离、3 km / 5 km 高敏感设施数量
- 原始方法备注：`method_note`

## 当前 Top 5 候选地

| 排名 | 候选地 | 总分 | 最近机场 | 机场距离 km | 25 km 人口 | 最近敏感设施 km |
| ---: | :--- | ---: | :--- | ---: | ---: | ---: |
| 1 | Kempen rural recreation candidate | 58.71 | Vliegveld Weelde | 9.17 | 744,732 | 16.94 |
| 2 | Flevoland open grassland candidate | 58.41 | Lelystad Airport | 1.11 | 692,552 | 8.67 |
| 3 | Molecaten Parc Flevostrand | 53.92 | Lelystad Airport | 10.79 | 579,113 | 8.84 |
| 4 | Tivolipark | 51.72 | Grimbergen Lint | 12.10 | 2,881,039 | 0.04 |
| 5 | Boom recreation candidate near De Schorre | 49.13 | Internationale Luchthaven Antwerpen | 10.78 | 2,577,444 | 0.00 |

## 分析说明

评分解释视图让候选地排名的原因更加清楚。例如：

- `Kempen rural recreation candidate` 和 `Flevoland open grassland candidate` 排名靠前，主要因为机场可达性较好，且周边高敏感设施距离较远。
- `Tivolipark` 和 `Boom recreation candidate near De Schorre` 虽然人口覆盖很强，但距离高敏感设施过近，噪声安全项明显拉低总分。
- De Schorre 相关候选地能用于说明真实音乐节场地与模型之间的张力：现实成熟场地并不一定在所有安全约束下得分最高。

## 当前业务表状态补充

Tomorrowland 2025 官方 lineup/timetable 已提升到正式表，并使用 `performance_artists` 表表达多人合作演出：

| 音乐节 | performance block | performance-artist 关联 |
| :--- | ---: | ---: |
| Tomorrowland 2025 | 806 | 864 |
| Defqon.1 2025 | 4 | 4 |
| Awakenings Summer Festival 2025 | 3 | 3 |

## 后续建议

1. 用 `v_site_score_explanation` 在 QGIS 中制作候选地评分分级图。
2. 在最终报告中加入 Top 5 或 Top 10 的评分解释表。
3. 对 De Schorre、Walibi Holland、Beekse Bergen 三个真实场地做单独对比，解释现实选址与模型分数之间的差异。

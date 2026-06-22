# 当前阶段成果总结与下一阶段计划

更新时间：2026-06-22  
项目主题：Benelux 电子音乐节数据库与 PostGIS 选址分析  
当前数据库：PostgreSQL/PostGIS，数据库名 `festival_gis`  
GitHub 仓库：https://github.com/ssswitzzz/festival-gis-database

## 1. 项目目标回顾

本项目的目标是构建一个面向 Benelux 电子音乐节的综合数据库系统，既能管理音乐节业务数据，也能进行候选场地的空间选址分析。

项目围绕三个代表性音乐节展开：

| 音乐节 | 年份 | 国家/城市 | 场地 |
| :--- | ---: | :--- | :--- |
| Tomorrowland | 2025 | Belgium / Boom | De Schorre |
| Defqon.1 | 2025 | Netherlands / Biddinghuizen | Walibi Holland event grounds |
| Awakenings Summer Festival | 2025 | Netherlands / Hilvarenbeek | Beekse Bergen |

当前阶段的工作重点有两条主线：

1. **空间分析数据线**：导入真实公开 GIS 数据，并基于 PostGIS 建立候选地评分模型。
2. **音乐节业务数据线**：以 Tomorrowland 2025 为样板，将官方 lineup/timetable 从网页归档抓取、解析、入库，并提升到正式业务表。

## 2. 当前阶段核心成果

### 2.1 数据库结构已经形成

当前数据库已经包含课程项目需要的主要关系表和空间表：

- 音乐节业务表：`organizers`、`festivals`、`venues`、`festival_editions`
- 演出业务表：`stages`、`artists`、`genres`、`artist_genres`、`performances`、`performance_artists`、`ticket_types`
- GIS 分析表：`candidate_sites`、`transport_hubs`、`population_grids`、`ecological_protected_areas`、`noise_sensitive_facilities`、`site_evaluations`
- 业务抓取 staging 表：`stg_business_*`、`stg_tomorrowland_2025_*`

其中 `performance_artists` 是当前阶段新增的重要结构，用于解决多人合作演出、b2b 演出和一个节目块对应多个艺人的建模问题。

### 2.2 真实空间数据已经入库

项目已经从早期 seed 示例推进到真实空间数据驱动阶段。当前核心空间数据规模如下：

| 表 | 行数 | 数据来源/说明 |
| :--- | ---: | :--- |
| `candidate_sites` | 50 | OSM 候选场地 + 少量手工样例 |
| `transport_hubs` | 353 | OSM 交通节点 + OurAirports 机场 |
| `population_grids` | 69,938 | Eurostat/GISCO Census Grid 2021 V3 |
| `ecological_protected_areas` | 501 | Natura 2000 / EEA 生态保护区 |
| `noise_sensitive_facilities` | 304 | OSM 学校、医院、居住区等高敏感设施 |
| `site_evaluations` | 50 | 基于真实空间数据重算的候选地评分 |

这些数据使项目能够展示真正的 PostGIS 空间分析能力，而不是只依赖手工构造的演示数据。

### 2.3 候选地评分模型已经可解释

当前评分模型综合考虑：

- 最近机场距离
- 25 km 范围内 Eurostat/GISCO 人口覆盖
- 最近 Natura 2000 / 生态保护区距离
- 最近高敏感噪声设施距离

本阶段新增了 `v_site_score_explanation` 视图，用于解释每个候选地的得分来源。该视图展开了最近机场、人口覆盖、生态保护区、噪声敏感设施数量等原始指标，便于报告和 QGIS 制图使用。

当前 Top 5 候选地如下：

| 排名 | 候选地 | 总分 | 最近机场 | 机场距离 km | 25 km 人口 | 最近敏感设施 km |
| ---: | :--- | ---: | :--- | ---: | ---: | ---: |
| 1 | Kempen rural recreation candidate | 58.71 | Vliegveld Weelde | 9.17 | 744,732 | 16.94 |
| 2 | Flevoland open grassland candidate | 58.41 | Lelystad Airport | 1.11 | 692,552 | 8.67 |
| 3 | Molecaten Parc Flevostrand | 53.92 | Lelystad Airport | 10.79 | 579,113 | 8.84 |
| 4 | Tivolipark | 51.72 | Grimbergen Lint | 12.10 | 2,881,039 | 0.04 |
| 5 | Boom recreation candidate near De Schorre | 49.13 | Internationale Luchthaven Antwerpen | 10.78 | 2,577,444 | 0.00 |

分析上可以看到：人口覆盖强的候选地不一定得分最高，因为噪声敏感设施距离过近会显著拉低安全评分。这一点可以作为最终报告的重要讨论点。

### 2.4 Tomorrowland 官方业务数据链路已经跑通

业务数据线以 Tomorrowland 2025 作为样板，已经完成以下流程：

1. 使用 Wayback Machine 抓取 2025 官方页面归档。
2. 从官方 CDN JSON 中识别 `TLBE25` 数据。
3. 解析出官方 weekend、stage、artist、performance 数据。
4. 导入 `stg_tomorrowland_2025_*` staging 表。
5. 将通过审核的数据提升到正式业务表。
6. 使用 `performance_artists` 多对多表表达合作演出。

当前正式业务表中演出数据统计如下：

| 音乐节 | performance block | performance-artist 关联 | 当前状态 |
| :--- | ---: | ---: | :--- |
| Tomorrowland 2025 | 806 | 864 | 官方 lineup/timetable 已入正式表 |
| Defqon.1 2025 | 4 | 4 | 仍为 seed 演示数据 |
| Awakenings Summer Festival 2025 | 3 | 3 | 仍为 seed 演示数据 |

说明：Tomorrowland staging 中共有 809 条官方 performance 记录，其中 3 条 MC/host 标注开始时间等于结束时间，不满足 `end_time > start_time` 约束，因此正式表保留 806 条有效节目块。按艺人展开后的 timetable 为 864 行。

### 2.5 报告用导出结果已经更新

当前阶段已生成或刷新以下报告用 CSV：

| 文件 | 内容 |
| :--- | :--- |
| `exports/site_score_explanation.csv` | 50 个候选地的评分解释表 |
| `exports/dynamic_site_scores_top20.csv` | 最新候选地评分 Top 20 |
| `exports/affected_population_5km.csv` | 候选地 5 km 噪声缓冲区影响人口估算 |
| `exports/real_venue_match_validation.csv` | 高分候选地与真实音乐节场地匹配验证 |
| `exports/tomorrowland_2025_timetable.csv` | Tomorrowland 2025 官方 timetable，按艺人展开 |

这些文件可以直接用于最终报告中的表格、截图和分析说明。

### 2.6 GitHub 仓库已经建立

项目已经整理为独立 Git 仓库，并推送到 GitHub：

```text
https://github.com/ssswitzzz/festival-gis-database
```

仓库中已加入：

- `README.md`
- `.gitignore`
- SQL 建表、导入、迁移和视图脚本
- Python / PowerShell 数据抓取与处理脚本
- 文档和阶段性更新记录
- 关键处理后 CSV 与报告导出结果

大型可重建原始数据、数据库中间 SQL dump、浏览器抓包缓存等已经通过 `.gitignore` 排除，避免仓库过重。

## 3. 当前数据真实性分层

当前项目中的数据可以分为四类：

| 类型 | 示例 | 当前状态 |
| :--- | :--- | :--- |
| 真实公开空间数据 | OSM、Natura 2000、Eurostat/GISCO、OurAirports | 已入库并用于评分 |
| 官方抓取业务数据 | Tomorrowland 2025 lineup/timetable | 已入 staging 并提升到正式表 |
| 近似公开资料 | 场地中心点、活动日期、预期观众规模 | 部分仍需来源说明 |
| 模拟/课程演示数据 | 票价、quota、舞台容量、estimated crowd、部分 seed 演出 | 后续报告中需明确标注 |

最终报告中应明确说明哪些字段是真实数据，哪些字段是估计或模拟数据，避免把课程演示字段误写成权威事实。

## 4. 当前阶段结论

当前阶段已经完成项目的核心闭环：

1. 数据库 schema 已可支撑音乐节业务数据和空间分析数据。
2. 真实 GIS 数据已经入库，并用于候选地评分。
3. PostGIS 评分模型已经从“只给总分”升级为“可解释评分”。
4. Tomorrowland 2025 官方 lineup/timetable 已完成从抓取到正式表入库的完整链路。
5. 多人合作演出的多对多建模已经完成。
6. 报告用 CSV 和 GitHub 仓库已经准备好。

这意味着项目已经具备较完整的课程展示基础。接下来的重点不应只是继续扩大数据量，而应围绕最终报告、地图可视化和少量关键数据补强来收束。

## 5. 下一阶段计划

### 5.1 报告与展示优先任务

1. **制作 QGIS 地图截图**
   - 候选场地分布图
   - 候选地评分分级图
   - Natura 2000 保护区与候选地叠加图
   - 噪声敏感设施及 3 km / 5 km 缓冲区图
   - 三个真实音乐节场地位置图

2. **整理最终报告结构**
   - 项目背景与研究问题
   - 数据来源与真实性说明
   - ER 图与关系模式说明
   - PostgreSQL/PostGIS 表结构与约束
   - 数据导入与治理流程
   - 候选地评分模型
   - 评分解释结果与 Top-N 候选地分析
   - Tomorrowland 官方 timetable 入库案例
   - 总结、不足与后续优化

3. **准备核心 SQL 截图或代码片段**
   - `v_dynamic_site_scores`
   - `v_site_score_explanation`
   - `v_tomorrowland_2025_timetable`
   - `v_affected_population_5km`
   - `v_real_venue_match_validation`

### 5.2 数据补强任务

1. **补充真实场地边界**
   - 优先处理 De Schorre
   - 尽量用 OSM 边界或 QGIS 手工矢量化替换当前近似矩形

2. **补充票价与观众规模证据**
   - Tomorrowland 2025 ticket / sales / passes 页面
   - Defqon.1 和 Awakenings 的官方或媒体观众规模资料
   - 若无法找到权威来源，应保留模拟字段并在报告中说明

3. **继续尝试 Defqon.1 与 Awakenings 官方数据抓取**
   - 优先寻找 2025 Wayback 快照
   - 如果能找到结构化 JSON/API，则复制 Tomorrowland 的 staging -> promote 流程
   - 如果时间不足，可将两者作为空间对比对象，业务数据维持 seed 状态并明确说明

### 5.3 模型优化任务

1. **评分权重敏感性分析**
   - 尝试不同权重组合
   - 观察 Top 候选地是否稳定

2. **交通可达性细化**
   - 当前主要使用最近机场距离
   - 后续可加入火车站/公交总站数量、距离或容量

3. **风险解释增强**
   - 对生态保护区相交候选地给出硬约束标记
   - 对 3 km 内高敏感设施过多的候选地给出风险等级

## 6. 建议下一步执行顺序

如果时间有限，建议按以下顺序推进：

| 顺序 | 任务 | 价值 |
| ---: | :--- | :--- |
| 1 | 用 QGIS 生成评分地图和保护区/敏感设施叠加图 | 最直接提升报告展示效果 |
| 2 | 写最终报告正文和 ER 图 | 课程交付核心 |
| 3 | 用 `site_score_explanation.csv` 做 Top 10 解释表 | 强化模型可解释性 |
| 4 | 补 De Schorre 真实边界 | 提升空间数据可信度 |
| 5 | 查票价和观众规模来源 | 补足业务数据真实性 |
| 6 | 尝试 Defqon.1 / Awakenings 官方 lineup | 锦上添花 |

## 7. 当前可直接用于报告的材料

| 材料 | 路径 |
| :--- | :--- |
| 项目 README | `README.md` |
| 当前阶段进度 | `docs/current_phase_progress_report.md` |
| Tomorrowland promote 更新 | `docs/tomorrowland_2025_promote_update.md` |
| 评分解释更新 | `docs/update_2026-06-22_score_explanation_exports.md` |
| 评分解释 CSV | `exports/site_score_explanation.csv` |
| 候选地 Top20 | `exports/dynamic_site_scores_top20.csv` |
| 影响人口估算 | `exports/affected_population_5km.csv` |
| Tomorrowland timetable | `exports/tomorrowland_2025_timetable.csv` |
| 核心视图 SQL | `sql/05_views.sql` |
| 数据库 schema | `sql/01_schema.sql` |

## 8. 阶段性判断

当前项目已经达到“可完成最终课程报告”的基础要求，并且有两个比较突出的亮点：

1. **真实空间数据驱动的 PostGIS 候选地评分模型**  
   这部分体现数据库课程中的空间扩展、索引、距离分析、缓冲区分析和多表联合查询能力。

2. **Tomorrowland 官方 lineup/timetable 的可追溯入库流程**  
   从 Wayback 抓取、官方 CDN JSON 解析、staging 表、正式表提升到多对多演出建模，形成了完整的数据治理案例。

下一阶段应重点转向最终报告表达和地图可视化，把已经完成的数据和模型讲清楚、展示好。

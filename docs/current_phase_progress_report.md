# 当前阶段进度报告

更新时间：2026-06-21  
项目主题：Benelux 电子音乐节数据库与 GIS 选址分析  
当前数据库：PostgreSQL/PostGIS，数据库名 `festival_gis`

## 1. 阶段目标

本阶段的核心目标是把课程项目从“模拟样例数据库”推进到“可追溯的真实数据驱动数据库”。目前工作重点分为两条线：

1. 空间分析数据线：为候选音乐节场地选址模型准备真实 GIS 数据，包括候选场地、交通节点、人口网格、生态保护区、噪声敏感设施，并用 PostGIS 重新计算选址评分。
2. 音乐节业务数据线：从官方或官方归档页面抓取音乐节业务数据，优先补齐真实日期、lineup、timetable、票价、观众规模等字段。

本项目的业务对象不是只筛选 Tomorrowland，而是围绕三个代表性 Benelux 电子音乐节展开：

- Tomorrowland 2025，Belgium / Boom / De Schorre
- Defqon.1 2025，Netherlands / Biddinghuizen / Walibi Holland event grounds
- Awakenings Summer Festival 2025，Netherlands / Hilvarenbeek / Beekse Bergen

目前空间分析数据线已经进入可用状态；业务数据线先以 Tomorrowland 2025 作为样板，成功跑通了“官方页面归档抓包 -> raw JSON -> clean CSV -> staging 表”的流程。Defqon.1 和 Awakenings 还需要按同一流程继续补齐。

## 2. 已完成工作概览

### 2.1 数据库基础建设

已完成 PostgreSQL/PostGIS 数据库初始化，核心 schema 已建立。

主要对象包括：

- 节日业务表：`organizers`、`festivals`、`venues`、`festival_editions`
- 演出业务表：`stages`、`artists`、`genres`、`artist_genres`、`performances`、`ticket_types`
- GIS 分析表：`candidate_sites`、`transport_hubs`、`population_grids`、`ecological_protected_areas`、`noise_sensitive_facilities`、`site_evaluations`
- 业务抓取 staging 表：`stg_business_*`
- Tomorrowland 2025 官方 lineup staging 表：`stg_tomorrowland_2025_*`

基础脚本：

- `sql/01_schema.sql`：建表和空间索引
- `sql/02_seed_data.sql`：初始样例数据
- `sql/03_analysis_queries.sql`：分析查询
- `sql/05_views.sql`：分析视图

### 2.2 真实空间数据导入

已经导入和规范化的真实/准真实空间数据包括：

| 数据类型 | 表 | 当前数量 | 说明 |
|---|---:|---:|---|
| 候选场地 | `candidate_sites` | 50 | 45 条来自 OSM，5 条早期手工样例 |
| 生态保护区 | `ecological_protected_areas` | 501 | 主要来自 Natura 2000 / EEA 数据，保留 3 条早期样例 |
| 噪声敏感设施 | `noise_sensitive_facilities` | 304 | 主要来自 OSM 学校、医院等 POI，保留少量样例 |
| 人口网格 | `population_grids` | 69,938 | Eurostat/GISCO Census Grid 2021 V3，已替换原模拟人口网格 |
| 交通节点 | `transport_hubs` | 353 | OSM 火车站/公交节点 + OurAirports 机场 |
| 场地评分 | `site_evaluations` | 50 | 已基于真实空间数据重新计算 |

交通节点分类：

| 类型 | 数量 |
---|---:|
| airport | 33 |
| train_station | 270 |
| bus_terminal | 50 |

噪声敏感设施分类：

| 类型 | 数量 |
---|---:|
| hospital | 10 |
| residential | 3 |
| school | 291 |

人口网格当前已经全部为真实导入数据：

| 是否模拟 | 行数 | 总人口 |
|---|---:|---:|
| false | 69,938 | 29,173,226 |

相关脚本：

- `scripts/download_public_data.ps1`
- `scripts/import_public_data.ps1`
- `scripts/import_population_grid.ps1`
- `scripts/import_ourairports.ps1`
- `scripts/convert_overpass_to_geojson.py`
- `scripts/convert_overpass_to_geojson.ps1`
- `sql/06_normalize_public_data.sql`
- `sql/07_normalize_population_grid.sql`
- `sql/08_normalize_ourairports.sql`
- `sql/09_recalculate_site_scores.sql`

### 2.3 选址评分模型进展

已经使用 PostGIS 空间计算重新生成了 `site_evaluations`。

当前评分考虑的指标包括：

- 最近机场距离
- 25 km 范围内 Eurostat/GISCO 加权人口
- 最近 Natura 2000 / 生态保护区距离
- 最近高敏感噪声设施距离

当前 Top 5 候选场地：

| 排名 | 场地 | 总分 |
---:|---|---:|
| 1 | Kempen rural recreation candidate | 58.71 |
| 2 | Flevoland open grassland candidate | 58.41 |
| 3 | Molecaten Parc Flevostrand | 53.92 |
| 4 | Tivolipark | 51.72 |
| 5 | Boom recreation candidate near De Schorre | 49.13 |

说明：评分模型已经可用于展示数据库空间分析能力，但仍有优化空间，例如权重敏感性分析、交通承载力更精细化、真实场地面积/边界质量提升等。

## 3. 业务数据抓取进展

### 3.1 总体策略

业务数据不是只服务于 Tomorrowland，而是要最终覆盖三个节日。当前采用的策略是：

1. 先用 Tomorrowland 跑通完整技术链路，因为它的官方页面和 CDN JSON 比较适合验证抓包流程。
2. 将 Tomorrowland 的方法沉淀为通用工作流，包括浏览器抓包、raw 文件留存、结构化解析、staging 入库和人工审核。
3. 对 Defqon.1 和 Awakenings 重复该流程，优先寻找 2025 官方页面或 Wayback 快照。
4. 三个节日的数据都先进入 staging 表，确认质量后再提升到正式表，避免真实数据和 seed 样例混杂。

### 3.2 Tomorrowland 2025 官方业务数据进展

#### 抓取方式

由于 Tomorrowland 官方当前页面已经可能展示 2026 内容，我们采用 Wayback Machine 的 2025 页面快照进行抓包。

用户提供并运行的页面：

```text
https://web.archive.org/web/20250720000355/https://belgium.tomorrowland.com/en/line-up/
```

抓包脚本：

- `scripts/capture_festival_network.py`

抓包结果文件：

- `data/processed/business_network_responses.csv`
- `data/processed/business_network_fact_candidates.csv`
- `data/raw/festival_network_capture/`

#### 确认抓到的是 2025 数据

抓包中发现了 Tomorrowland 官方 CDN 的 2025 JSON：

- `config-TLBE25-...json`
- `stages-TLBE25-...json`
- `TLBE25-W1-...json`
- `TLBE25-W2-...json`

其中 `TLBE25` 明确表示 Tomorrowland Belgium 2025。

官方配置中的 weekend 时间：

| 周次 | 开始时间 | 结束时间 |
|---|---|---|
| W1 | 2025-07-17 12:00 | 2025-07-21 01:00 |
| W2 | 2025-07-24 12:00 | 2025-07-28 01:00 |

这说明官方 timetable 覆盖了 The Gathering / DreamVille 相关日期，因此比原始 seed 数据中的 `2025-07-18` 到 `2025-07-27` 更完整。

#### 已解析出的官方 CSV

新增解析脚本：

- `scripts/parse_tomorrowland_lineup_capture.py`

生成文件：

| 文件 | 内容 | 行数 |
|---|---|---:|
| `data/processed/tomorrowland_2025_weekends_official.csv` | 官方 weekend 时间 | 2 |
| `data/processed/tomorrowland_2025_stages_official.csv` | 官方舞台 | 17 |
| `data/processed/tomorrowland_2025_artists_official.csv` | 官方艺人 | 731 |
| `data/processed/tomorrowland_2025_performances_official.csv` | 官方演出时刻表 | 809 |

官方舞台包括：

- MAINSTAGE
- FREEDOM BY BUD
- THE ROSE GARDEN
- ELIXIR
- CAGE
- THE RAVE CAVE
- PLANAXIS
- RISE BY COCA-COLA
- ATMOSPHERE
- CORE
- CRYSTAL GARDEN
- THE GREAT LIBRARY
- MELODIA BY CORONA
- HOUSE OF FORTUNE BY JBL
- MOOSEBAR
- THE GATHERING
- THE GATHERING - STAGE II

#### 已导入数据库 staging 表

导入脚本：

- `sql/11_import_tomorrowland_2025_lineup.sql`

当前 staging 表数量：

| 表 | 行数 |
|---|---:|
| `stg_tomorrowland_2025_weekends` | 2 |
| `stg_tomorrowland_2025_stages` | 17 |
| `stg_tomorrowland_2025_artists` | 731 |
| `stg_tomorrowland_2025_performances` | 809 |

官方 performance 时间范围：

```text
first_date: 2025-07-17
last_date:  2025-07-27
last_end:   2025-07-28 00:00:00+02:00
```

示例：2025-07-19 MAINSTAGE 包含 Charlotte de Witte、Fedde Le Grand、Alan Walker、Anyma、Dimitri Vegas & Like Mike 等真实官方时刻表数据。

### 3.3 Defqon.1 2025 业务数据状态

Defqon.1 当前仍主要停留在 seed 样例阶段，正式表中已有基础节日、场地、日期、舞台和少量演出数据，但 lineup/timetable、真实票价、真实观众规模仍未完成官方抓取替换。

当前正式表中的 Defqon.1 信息：

- festival：Defqon.1
- year：2025
- venue：Walibi Holland event grounds
- date：2025-06-26 至 2025-06-29
- seed stages：RED、BLUE、BLACK
- seed performances：少量演示数据

后续需要寻找的数据：

- 2025 官方 lineup 页面或 timetable 页面
- 2025 ticket / sales / pass 页面
- 官方 visitor / attendance / capacity 说明
- 如官网已更新到新年份，则优先寻找 Wayback Machine 的 2025 快照

计划流程：

1. 找到 Defqon.1 2025 官方页面或 Wayback URL。
2. 使用 `scripts/capture_festival_network.py` 抓取网络响应。
3. 检查是否存在官方 JSON / API 数据。
4. 如果有结构化 JSON，则编写类似 `parse_tomorrowland_lineup_capture.py` 的解析脚本。
5. 生成 `defqon_2025_*_official.csv`。
6. 导入 `stg_defqon_2025_*` staging 表。
7. 审核后再提升到正式 `stages`、`artists`、`performances`、`ticket_types`。

### 3.4 Awakenings Summer Festival 2025 业务数据状态

Awakenings 当前也仍主要停留在 seed 样例阶段。正式表中已有基础节日、场地、日期、舞台和少量演出数据，但尚未导入官方 lineup/timetable、真实票价、真实观众规模。

当前正式表中的 Awakenings 信息：

- festival：Awakenings Summer Festival
- year：2025
- venue：Beekse Bergen
- date：2025-07-11 至 2025-07-13
- seed stages：Area V、Area W
- seed performances：少量演示数据

后续需要寻找的数据：

- 2025 官方 lineup 页面
- 2025 timetable / program 页面
- ticket 页面或 archived ticket information
- 官方或可靠媒体的 attendance / capacity 数据

计划流程：

1. 找到 Awakenings Summer Festival 2025 官方页面或 Wayback URL。
2. 使用 `scripts/capture_festival_network.py` 抓取页面网络响应。
3. 检查是否存在官方 API、JSON、Next.js 数据或嵌入式页面数据。
4. 编写 Awakenings 专用解析脚本或抽象出通用解析框架。
5. 生成 `awakenings_2025_*_official.csv`。
6. 导入 `stg_awakenings_2025_*` staging 表。
7. 审核后再提升到正式业务表。

## 4. 当前正式表状态

需要特别说明：当前只有 Tomorrowland 2025 官方数据已经进入 staging 表，但还没有正式替换核心业务表。Defqon.1 和 Awakenings 目前还没有完成官方业务数据抓取入库。

正式业务表仍保持 seed 阶段状态：

| 表 | 行数 |
|---|---:|
| `organizers` | 3 |
| `festivals` | 3 |
| `venues` | 3 |
| `festival_editions` | 3 |
| `stages` | 8 |
| `artists` | 10 |
| `performances` | 11 |
| `ticket_types` | 8 |

Tomorrowland 2025 在正式表中的日期仍为：

```text
2025-07-18 至 2025-07-27
```

而官方 staging 数据显示完整 timetable 范围应覆盖：

```text
2025-07-17 至 2025-07-28
```

Defqon.1 和 Awakenings 在正式表中也仍是 seed 演示数据，需要后续用官方抓取结果替换或补充。

## 5. 已准备但尚未执行的脚本

刚刚已经新增了一个 Tomorrowland 专用的下一步脚本：

- `sql/12_promote_tomorrowland_2025_official_lineup.sql`

该脚本的作用是把 `stg_tomorrowland_2025_*` 中的官方数据提升到正式表：

- 更新 Tomorrowland 2025 edition 日期为官方 timetable 覆盖范围
- 将原 seed 舞台名称对齐到官方名称
- 插入缺失的官方舞台
- 插入缺失的官方艺人
- 删除 Tomorrowland 2025 原 seed 演出
- 按官方 timetable 插入正式 `performances`

重要：该脚本目前只是写入文件，尚未执行。数据库正式表还没有被该脚本改动。

Defqon.1 和 Awakenings 目前还没有对应的 promote 脚本。原因是这两个节日的官方 staging 数据尚未建立。等抓取和解析完成后，应分别新增：

- `sql/13_import_defqon_2025_lineup.sql`
- `sql/14_promote_defqon_2025_official_lineup.sql`
- `sql/15_import_awakenings_2025_lineup.sql`
- `sql/16_promote_awakenings_2025_official_lineup.sql`

## 6. 当前数据真实性分层

### 6.1 已经是真实数据或官方数据

| 数据 | 状态 |
|---|---|
| Eurostat/GISCO 人口网格 | 真实数据，已入库 |
| Natura 2000 / EEA 生态保护区 | 真实数据，已入库 |
| OSM 候选场地 | 真实开放数据，已入库 |
| OSM 学校/医院/交通节点 | 真实开放数据，已入库 |
| OurAirports 机场 | 真实开放数据，已入库 |
| Tomorrowland 2025 lineup/timetable | 官方 CDN JSON，经 Wayback 抓取，已入 staging |

### 6.2 仍为模拟或近似数据

| 数据 | 当前状态 | 后续处理 |
|---|---|---|
| 节日票价 | seed 模拟 | 需要官方票务页、Wayback 快照或 PDF/截图 |
| ticket quota | seed 模拟 | 一般很难获取，可保留为假设并说明 |
| stage capacity | seed 模拟或为空 | 若无官方资料，可作为估计参数 |
| expected_attendance | 近似值 | 可用官方新闻稿/媒体报道替换 |
| venue polygon | 初始近似边界 | 可用 OSM/官方地图进一步细化 |
| artist country / genre | seed 少量样例 | 可补 MusicBrainz/Wikidata，但不一定是本课程重点 |
| performance estimated_crowd | 模拟 | 可按舞台容量和时间段估算，标记为 derived/simulated |

### 6.3 三个节日业务数据完成度

| 节日 | 基础信息 | 官方 lineup/timetable | 真实票价 | 观众规模 | 当前状态 |
|---|---|---|---|---|---|
| Tomorrowland 2025 | 已有 | 已抓取并入 staging | 未完成 | 近似值 | 样板流程已跑通 |
| Defqon.1 2025 | 已有 seed | 未完成 | 未完成 | 近似值 | 等待官方页面/Wayback 抓取 |
| Awakenings 2025 | 已有 seed | 未完成 | 未完成 | 近似值 | 等待官方页面/Wayback 抓取 |

结论：当前不是只研究 Tomorrowland。Tomorrowland 是第一条完整样板链路；Defqon.1 和 Awakenings 是下一阶段需要重点补齐的业务数据对象。

## 7. 当前工作流程总结

整体流程已经形成：

1. 建立 PostgreSQL/PostGIS schema
2. 插入最小 seed 数据，保证数据库可运行、可演示
3. 下载并导入真实空间数据
4. 将外部 GIS 数据规范化到项目表结构
5. 用 PostGIS 重新计算选址评分
6. 为业务网页抓取建立静态抓取和浏览器抓包脚本
7. 对 Wayback 官方页面进行网络响应抓包
8. 从 raw JSON 中解析结构化官方数据
9. 导入 staging 表，保留 source URL、source file、capture timestamp
10. 在确认质量后，再决定是否提升到正式业务表

这个流程的优点是：数据来源可追溯、真实数据和模拟数据不混在一起、正式表变更可以被审查后再执行。

## 8. 下一步建议

### 8.1 短期优先事项

1. 审查并执行 `sql/12_promote_tomorrowland_2025_official_lineup.sql`
   - 目标：把 Tomorrowland 2025 官方 lineup/timetable 写入正式 `stages`、`artists`、`performances`
   - 注意：执行前建议先备份或确认 seed 演出可以被替换

2. 为 Defqon.1 2025 寻找官方页面或 Wayback 快照
   - 优先 lineup / timetable / tickets 页面
   - 找到 URL 后用浏览器抓包脚本保存 raw 数据

3. 为 Awakenings Summer Festival 2025 寻找官方页面或 Wayback 快照
   - 优先 lineup / timetable / tickets 页面
   - 找到 URL 后重复 Tomorrowland 的 staging 流程

4. 补 Tomorrowland 2025 票价数据
   - 优先找 Wayback 中的 sales info、passes、tickets 页面
   - 如果页面动态加载票价，需要继续用 `capture_festival_network.py` 抓包
   - 如果只有截图/PDF，也可以人工录入 staging 表，并保留证据路径

5. 补三个节日的观众规模证据
   - 当前 `expected_attendance = 400000` 是近似值
   - Defqon.1 和 Awakenings 也使用近似值
   - 可寻找官方新闻稿、年报、媒体报道进行替换或注释

6. 为 Defqon.1 和 Awakenings 建立对应 staging 和 promote 脚本
   - 解析 JSON 或页面结构
   - 导入 staging
   - 审核后提升正式表

### 8.2 中期优化事项

1. 增加统一的 `data_sources` 或 `source_evidence` 表
   - 记录每个导入批次的来源、URL、文件、抓取时间、可信度

2. 改进正式表结构以容纳官方 ID
   - 例如 `artists` 增加 `external_source`、`external_id`
   - `performances` 增加 `official_performance_id`
   - 避免只靠 name 匹配导致同名或大小写问题

3. 处理合作演出的建模问题
   - 当前正式表 `performances` 是单 artist_id 模型
   - 官方数据中有 b2b、多人合作演出
   - 更规范的做法是新增 `performance_artists` 多对多表

4. 给 staging 数据增加质量检查 SQL
   - 检查重复 performance
   - 检查 end_time 是否晚于 start_time
   - 检查 stage 是否都能映射
   - 检查 artist 是否都能映射

5. 增加报告用视图
   - 官方演出每日数量
   - 各舞台演出数量
   - 艺人重复出现次数
   - 两个 weekend 的节目密度对比

### 8.3 展示与论文优化

1. 数据真实性说明
   - 把真实数据、模拟数据、推导数据分层说明
   - 明确票价、容量、观众规模哪些仍是估计

2. ER 图和流程图
   - 展示业务数据与 GIS 数据如何结合
   - 展示 staging 到 core tables 的数据治理流程

3. SQL 查询案例
   - 空间选址 Top-N 查询
   - 某候选场地周边人口与噪声敏感设施查询
   - Tomorrowland 官方 timetable 查询
   - 按舞台/日期统计演出密度

4. 可视化输出
   - 候选场地评分地图
   - Natura 2000 与候选场地叠加图
   - 交通节点距离分析
   - Tomorrowland 各舞台演出数量柱状图

## 9. 当前结论

当前项目已经从单纯 seed 示例进入真实数据整合阶段。空间分析部分已经具备较完整的真实数据基础，Tomorrowland 2025 官方 lineup/timetable 也已经成功抓取、解析并进入 staging 表。

下一步最关键的工作有两类：第一，决定是否执行 `sql/12_promote_tomorrowland_2025_official_lineup.sql`，将 Tomorrowland 2025 官方业务数据正式替换原 seed 演出数据；第二，继续为 Defqon.1 2025 和 Awakenings Summer Festival 2025 寻找官方页面或 Wayback 快照，并复制 Tomorrowland 的抓取、解析、staging、审核、提升流程。

最终目标是让三个节日都拥有尽可能真实的官方业务数据，而不是只完成 Tomorrowland。

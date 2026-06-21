# 数据获取状态与下一步下载计划

更新时间：2026-06-20

## 当前结论

目前项目需要的核心空间真实数据，主要渠道都已经找到，并且大部分已经入库。现在最关键的一步已经完成：`population_grids` 已由 Eurostat/GISCO Census Grid 2021 真实 1 km 人口格网替换，不再使用原来的 5 条合成样例。

以后遇到大文件，优先由你手动下载，我只提供官方链接、建议保存路径和后续导入脚本。

## 已经真实入库的数据

| 数据表 | 当前数量 | 真实数据来源 | 当前状态 |
| :--- | ---: | :--- | :--- |
| `candidate_sites` | 50 | OpenStreetMap / Overpass API + 少量初始样例 | 已入库，OSM 部分可追溯 |
| `noise_sensitive_facilities` | 304 | OpenStreetMap / Overpass API | 已入库 |
| `transport_hubs` | 335 | OpenStreetMap / Overpass API + 初始样例 | 已入库 |
| `ecological_protected_areas` | 501 | EEA Natura 2000 ArcGIS REST | 已入库 |
| `population_grids` | 69,938 | Eurostat/GISCO Census Grid 2021 V3 | 已入库，模拟人口格网已删除 |

`population_grids` 当前核查结果：

| 指标 | 数值 |
| :--- | ---: |
| 真实人口格网行数 | 69,938 |
| 合成人口格网行数 | 0 |
| BE/NL 格网总人口 | 29,173,226 |
| 单格最大人口 | 28,991 |

## 已新增的导入文件

| 文件 | 用途 |
| :--- | :--- |
| `scripts/import_population_grid.ps1` | 从 `data/raw/Eurostat_Census-GRID_2021_V3/ESTAT_Census_2021_V3.gpkg` 抽取 BE/NL 格网并导入暂存表 |
| `sql/07_normalize_population_grid.sql` | 将暂存表写入正式 `population_grids`，替换合成人口样例 |

重建人口格网时执行：

```powershell
$env:PGPASSWORD='<your_postgres_password>'
powershell -ExecutionPolicy Bypass -File scripts\import_population_grid.ps1
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -v ON_ERROR_STOP=1 -f sql\07_normalize_population_grid.sql
```

## 可自动下载的数据

| 数据 | 渠道 | 是否已做脚本 | 说明 |
| :--- | :--- | :--- | :--- |
| OSM 候选场地 | Overpass API | 是 | 查询文件在 `data/queries/` |
| OSM 敏感设施 | Overpass API | 是 | 医院、学校、幼儿园等 |
| OSM 交通枢纽 | Overpass API | 是 | 机场、火车站、公交总站等 |
| Natura 2000 | EEA ArcGIS REST | 是 | 已筛选 Belgium + Netherlands |
| Eurostat/GISCO 人口格网 | 官方 ZIP/GPKG | 半自动 | 大文件由你下载，我负责导入 |

## 之后建议你手动下载的数据

### 1. Eurostat/GISCO 人口格网

当前已下载并导入，无需重复下载。若以后要重建原始数据：

- 官方页面：https://ec.europa.eu/eurostat/web/gisco/geodata/population-distribution/population-grids
- 当前使用版本：Census Grid 2021 Version 3
- 直链：https://gisco-services.ec.europa.eu/census/2021/Eurostat_Census-GRID_2021_V3.zip
- 建议解压位置：`data/raw/Eurostat_Census-GRID_2021_V3/`

### 2. OurAirports 机场数据

这是可选增强项，用来补充 `transport_hubs` 中机场信息，比 OSM 更适合做机场清单校验。

- CSV 链接：https://davidmegginson.github.io/ourairports-data/airports.csv
- 建议保存为：`data/raw/ourairports_airports.csv`
- 后续处理：筛选 `iso_country IN ('BE','NL')`，转换经纬度为 EPSG:3035，合并到 `transport_hubs`

### 3. 官方音乐节业务数据

这部分通常需要人工整理，不适合完全自动下载入库，因为网页动态变化较多，而且票价、lineup、timetable 经常更新。

| 数据 | 推荐来源 | 自动化程度 |
| :--- | :--- | :--- |
| 音乐节日期 | 官方网站、新闻稿 | 可人工整理后入库 |
| 艺人阵容 | 官方 lineup 页面、festival app、海报 | 建议手动整理 |
| timetable | 官方 timetable 页面、app 截图 | 建议手动整理 |
| 票价 | 官方 ticket 页面、历史票价截图 | 建议手动整理 |
| 观众规模 | 官方新闻稿、媒体报道、Wikipedia 辅助校验 | 半自动，需要人工确认 |

## 仍然模拟或近似的数据

| 数据项 | 当前状态 | 可否用真实数据替换 |
| :--- | :--- | :--- |
| `ticket_types.price_eur` | 部分模拟 | 可替换，但需要人工查官方票价 |
| `ticket_types.quota` | 模拟 | 多数不公开，建议保留模拟并说明 |
| `stages.capacity` | 模拟/估计 | 部分可从场地图或报道估计 |
| `performances.estimated_crowd` | 模拟 | 通常不公开，建议保留模拟 |
| `candidate_sites.daily_cost` | 模拟 | 场地租金通常不公开，建议保留模拟 |
| `population_grids.edm_fan_index` | 模拟偏好指数 | 可以优化为基于年龄/城市/历史活动的模型，但不会是直接公开数据 |
| `venues.geom_polygon` | 近似边界 | 可用 OSM 边界或 QGIS 手工矢量化替换 |
| `site_evaluations` | 旧的演示评分 | 应用真实空间数据重新计算 |

## 下一步优先级

1. 重算 `site_evaluations`，用真实 OSM、Natura 2000、Eurostat 人口格网生成新评分。
2. 用 OSM 边界替换 `venues.geom_polygon` 中的近似矩形，优先处理 De Schorre。
3. 增加 `v_site_score_explanation`，让每个候选地的得分原因可解释。
4. 可选导入 OurAirports，补全机场数据。
5. 人工整理音乐节官方业务数据，优先补日期、观众规模、真实票价，lineup/timetable 视时间决定。

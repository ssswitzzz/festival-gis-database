# 数据来源与当前构建状态

本项目已经按照 `implementation_plan.md` 建立 PostgreSQL + PostGIS 数据库脚本，并放入第一批可运行样例数据。

## 已完成文件

| 文件 | 作用 |
| :--- | :--- |
| `sql/01_schema.sql` | 创建 16 张核心表、主外键、检查约束和 GiST 空间索引 |
| `sql/02_seed_data.sql` | 插入音乐节业务数据、真实场地点位、候选地样例、交通枢纽、人口网格样例、保护区样例和敏感设施 |
| `sql/03_analysis_queries.sql` | 放置报告可用的关系查询、空间筛选、噪声影响人口估算、真实场地匹配和动态评分查询 |
| `sql/04_import_templates.sql` | 从 OSM、Natura 2000、Eurostat/GISCO 暂存表导入正式空间数据的 SQL 模板 |
| `sql/05_views.sql` | 将核心查询固化成视图，便于 pgAdmin、QGIS 和后续报告反复查看 |
| `sql/06_normalize_public_data.sql` | 将下载后的 OSM 与 EEA 暂存表规范化导入正式空间表 |
| `docs/overpass_queries.md` | Overpass Turbo 查询模板，可直接提取候选地、敏感设施和交通枢纽 |

## 真实公开信息整理

当前种子数据中，以下字段采用公开资料整理或公开坐标近似：

| 类别 | 当前内容 | 说明 |
| :--- | :--- | :--- |
| 音乐节品牌 | Tomorrowland、Defqon.1、Awakenings Summer Festival | 品牌名、主办方、举办国家来自官方/公开资料 |
| 真实场地 | De Schorre、Walibi Holland event grounds、Beekse Bergen | 城市和中心点为公开资料整理，边界为课程演示近似矩形 |
| 年度届次 | 2025 年 Tomorrowland、Defqon.1、Awakenings Summer Festival | 日期采用公开活动日程整理，后续报告可补充截图或引用 |
| 交通枢纽 | Brussels Airport、Schiphol、Eindhoven Airport 等 | 坐标采用公开机场/车站位置近似 |
| 艺人和流派 | Armin van Buuren、Charlotte de Witte、Martin Garrix 等 | 用于构造多对多关系和演出安排样例 |

## 已下载公开空间数据

| 文件 | 来源 | 说明 |
| :--- | :--- | :--- |
| `data/raw/osm_candidate_sites.json` | Overpass API / OpenStreetMap | Boom、Biddinghuizen、Hilvarenbeek-Tilburg 样区的公园、露营地和活动场地 |
| `data/raw/osm_sensitive_facilities.json` | Overpass API / OpenStreetMap | 样区内医院、学校、幼儿园 |
| `data/raw/osm_transport_hubs.json` | Overpass API / OpenStreetMap | 样区及附近机场、火车站、公交总站 |
| `data/raw/natura2000_be_nl.geojson` | EEA ArcGIS REST service | 比利时和荷兰 Natura 2000 保护区 |
| `data/raw/eurostat_population_grid_source.txt` | Eurostat/GISCO | 人口网格数据源说明；正式大文件后续手动或脚本补充 |

## 模拟或简化字段

以下字段目前用于课程演示，不应写成权威事实：

| 字段 | 原因 |
| :--- | :--- |
| `ticket_types.price_eur`、`quota` | 真实票价和配额经常变化，当前用于演示票种关系 |
| `stages.capacity`、`performances.estimated_crowd` | 舞台容量和人群规模难以完整公开获取 |
| `candidate_sites.daily_cost` | 场地租金/运营成本通常不是公开数据 |
| `population_grids.population`、`edm_fan_index` | 当前为粗粒度合成网格；正式版应替换为 Eurostat/GISCO 人口网格 |
| `ecological_protected_areas.geom_polygon` | 当前为简化样例；正式版应替换为 EEA Natura 2000 边界 |
| 候选地边界 | 当前用手工矩形模拟 OSM 候选地；正式版应从 OSM/Geofabrik 过滤导入 |

## 推荐正式数据源

| 数据 | 推荐来源 | 用途 |
| :--- | :--- | :--- |
| OSM 道路、POI、候选场地 | Geofabrik Belgium/Netherlands Shapefile 或 Overpass API | 提取 `leisure=park`、`tourism=camp_site`、医院、学校、交通节点 |
| 生态保护区 | EEA Natura 2000 spatial dataset | 替换 `ecological_protected_areas` 样例表 |
| 人口网格 | Eurostat/GISCO population grid | 替换 `population_grids` 样例表 |
| 机场 | OurAirports CSV 或 OSM | 补全 `transport_hubs` 中机场数据 |
| 音乐节业务数据 | 官方网站、新闻稿、Wikipedia 辅助校验 | 补全届次、场地、艺人、票种和观众规模 |

## 建库方式

安装 PostgreSQL 和 PostGIS 后，在目标数据库中依次执行：

```powershell
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -f sql/01_schema.sql
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -f sql/02_seed_data.sql
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -f sql/03_analysis_queries.sql
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -f sql/05_views.sql
```

如果数据库尚未创建，可先执行：

```powershell
E:\PostgreSQL\18\bin\createdb.exe -U postgres festival_gis
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -c "CREATE EXTENSION IF NOT EXISTS postgis;"
```

本机已确认 `E:\PostgreSQL\18\bin` 中存在 `psql.exe`、`ogr2ogr.exe`、`shp2pgsql.exe` 和 PostGIS 组件。如果命令提示输入密码，请输入安装 PostgreSQL 时为 `postgres` 用户设置的密码。

## 下一步建议

1. 使用 QGIS 或 `ogr2ogr` 将 OSM、Natura 2000、Eurostat/GISCO 数据裁剪到比利时 + 荷兰。
2. 将正式空间数据统一转换为 EPSG:3035。
3. 用正式图层替换当前样例表中的候选地、保护区、人口网格和敏感设施。
4. 运行 `sql/03_analysis_queries.sql`，输出查询结果表和地图截图用于报告。

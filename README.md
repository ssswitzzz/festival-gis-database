# Benelux Electronic Music Festival GIS Database

课程项目：基于 PostgreSQL/PostGIS 的 Benelux 电子音乐节业务数据库与候选场地空间选址分析。

## 项目目标

本项目围绕三个代表性 Benelux 电子音乐节建立关系型数据库，并结合真实 GIS 数据进行候选场地评价：

- Tomorrowland 2025, Boom, Belgium
- Defqon.1 2025, Biddinghuizen, Netherlands
- Awakenings Summer Festival 2025, Hilvarenbeek, Netherlands

数据库覆盖音乐节、主办方、场地、届次、舞台、艺人、演出时刻表、票种，以及候选场地、交通节点、人口网格、生态保护区和噪声敏感设施等空间数据。

## 当前状态

- 已建立 PostgreSQL/PostGIS schema 和核心分析视图。
- 已导入 OSM、Natura 2000、Eurostat/GISCO Census Grid 2021、OurAirports 等真实/公开空间数据。
- 已基于真实空间数据重算候选地评分。
- 已从 Wayback + Tomorrowland 官方 CDN JSON 解析 Tomorrowland 2025 官方 lineup/timetable。
- 已将 Tomorrowland 2025 官方数据提升到核心业务表，并使用 `performance_artists` 多对多表表达合作演出。

## 目录结构

```text
sql/       建表、导入、规范化、评分重算和迁移脚本
scripts/   数据下载、转换、抓取和解析脚本
docs/      数据来源、阶段进度和工作流说明
data/      原始数据与处理后数据
exports/   报告可用查询结果 CSV
```

## 数据库初始化

示例执行顺序：

```powershell
E:\PostgreSQL\18\bin\createdb.exe -U postgres festival_gis
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -c "CREATE EXTENSION IF NOT EXISTS postgis;"
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -v ON_ERROR_STOP=1 -f sql\01_schema.sql
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -v ON_ERROR_STOP=1 -f sql\02_seed_data.sql
E:\PostgreSQL\18\bin\psql.exe -U postgres -d festival_gis -v ON_ERROR_STOP=1 -f sql\05_views.sql
```

公开空间数据和 Tomorrowland 官方 lineup 的详细导入流程见 `docs/`。

## 主要文档

- `docs/current_phase_progress_report.md`
- `docs/data_acquisition_status.md`
- `docs/business_scraping_workflow.md`
- `docs/tomorrowland_2025_promote_update.md`
- `docs/update_2026-06-21_airports_and_scores.md`

## 说明

部分票价、配额、舞台容量和预计观众数仍为课程演示或近似数据。最终报告中应明确区分真实公开数据、官方抓取数据、推导数据和模拟数据。

# 当前数据库构建与查询结果

更新时间：2026-06-19

## 1. 数据库构建状态

已在本机 PostgreSQL 18 数据库 `festival_gis` 中完成：

| 类型 | 数量 |
| :--- | ---: |
| 主办方 | 3 |
| 音乐节品牌 | 3 |
| 真实场地 | 3 |
| 年度届次 | 3 |
| 候选场地 | 50 |
| 候选地评分 | 5 |
| 噪声敏感设施 | 304 |
| 交通枢纽 | 335 |
| 生态保护区 | 501 |

已创建 16 张核心表、PostGIS 几何字段、主外键约束、检查约束和 GiST 空间索引。

## 1.1 公开空间数据导入状态

已直接下载并导入以下公开数据：

| 数据 | 来源 | 当前入库 |
| :--- | :--- | ---: |
| OSM 候选场地 | Overpass API，Boom / Biddinghuizen / Hilvarenbeek-Tilburg 样区 | 45 |
| OSM 噪声敏感设施 | Overpass API，医院、学校、幼儿园 | 298 |
| OSM 交通枢纽 | Overpass API，机场、火车站、公交总站 | 329 |
| Natura 2000 保护区 | EEA ArcGIS REST service，Belgium + Netherlands | 498 |

这些数据先进入 `stg_*` 暂存表，再通过 `sql/06_normalize_public_data.sql` 导入正式表。

## 2. 已导出查询结果

查询结果已导出到 `exports/`：

| 文件 | 内容 |
| :--- | :--- |
| `tomorrowland_2025_timetable.csv` | Tomorrowland 2025 样例演出时间表 |
| `performance_count_by_genre.csv` | 各音乐节不同流派演出次数 |
| `multicriteria_candidate_sites.csv` | 多准则筛选通过的候选地 |
| `affected_population_5km.csv` | 候选地 5 km 噪声缓冲区影响人口估算 |
| `real_venue_match_validation.csv` | 高分候选地与真实音乐节场地匹配 |
| `venue_scale_risk_summary.csv` | 真实场地运营规模与 5 km 高敏感设施数量 |
| `public_candidate_sites_top20.csv` | 公开 OSM 候选地面积 Top20 |
| `public_multicriteria_candidate_sites.csv` | 加入公开数据后的多准则筛选结果 |
| `public_transport_hub_counts.csv` | 公开交通枢纽类型统计 |
| `public_sensitive_facility_counts.csv` | 公开敏感设施类型统计 |

## 3. 关键结果

### 3.1 多准则筛选

在面积不低于 100,000 平方米、80 km 内有机场、不与保护区相交、3 km 内没有高敏感设施的严格条件下，目前通过筛选的候选地为：

| site_id | 候选地 | 面积 |
| ---: | :--- | ---: |
| 4 | Flevoland open grassland candidate | 760,000 m2 |
| 7 | De Edelkarper | 302,819 m2 |
| 6 | De Schulp | 194,438 m2 |
| 23 | Molecaten Parc Flevostrand | 190,615 m2 |
| 21 | Camping/Jachthaven "de Oude Pol" | 176,786 m2 |

这个结果适合作为“严格约束筛选”的示例。加入公开数据后，模型不再只依赖手工样例，而能从 OSM 候选地中筛出真实存在的公园和露营地。

### 3.1.1 公开候选地面积 Top10

| 候选地 | 类型 | 面积 |
| :--- | :--- | ---: |
| Oude Warande | park | 856,273 m2 |
| Provinciaal Domein De Schorre | park | 696,475 m2 |
| Reeshofbos | park | 391,947 m2 |
| Wandelgebied Moerenburg | park | 336,030 m2 |
| Drijflanen | park | 313,906 m2 |
| Krombeemden | park | 310,085 m2 |
| Wandelbos | park | 303,888 m2 |
| De Edelkarper | park | 302,819 m2 |
| Het Leijpark | park | 299,392 m2 |
| Provinciaal Groendomein d'Ursel | park | 297,320 m2 |

### 3.2 噪声影响人口估算

按 5 km 缓冲区与人口网格相交面积估算，当前样例结果为：

| 候选地 | 估算受影响人口 |
| :--- | ---: |
| Hilvarenbeek lake recreation candidate | 75,579 |
| Kempen rural recreation candidate | 65,479 |
| Biddinghuizen event-field candidate | 55,930 |
| Flevoland open grassland candidate | 55,021 |
| Boom recreation candidate near De Schorre | 54,887 |

当前人口网格仍是合成样例，正式报告中应注明：该结果用于验证 SQL 和空间计算流程，后续可用 Eurostat/GISCO 人口网格替换。

### 3.3 真实音乐节场地匹配验证

高分候选地与真实音乐节场地在 10 km 范围内匹配结果如下：

| 候选地 | 总分 | 真实场地 | 音乐节 | 距离 |
| :--- | ---: | :--- | :--- | ---: |
| Hilvarenbeek lake recreation candidate | 83.15 | Beekse Bergen | Awakenings Summer Festival | 0 m |
| Boom recreation candidate near De Schorre | 78.10 | De Schorre | Tomorrowland | 0 m |
| Biddinghuizen event-field candidate | 73.85 | Walibi Holland event grounds | Defqon.1 | 0 m |

由于当前候选地为围绕真实场地构造的课程样例矩形，因此距离为 0 m。这一结果证明数据库和空间匹配流程已经打通。后续替换为真实 OSM 候选地后，可检验模型是否仍然筛出接近现实选址的区域。

### 3.4 场地运营规模与空间风险

| 真实场地 | 样例届次数 | 最大预期观众规模 | 5 km 高敏感设施数量 |
| :--- | ---: | ---: | ---: |
| De Schorre | 1 | 400,000 | 2 |
| Walibi Holland event grounds | 1 | 250,000 | 1 |
| Beekse Bergen | 1 | 100,000 | 2 |

该查询适合作为“业务运营数据 + 空间风险数据联合分析”的展示。

## 4. 数据库视图

已创建以下视图，便于 pgAdmin 或 QGIS 直接查看：

| 视图 | 内容 |
| :--- | :--- |
| `v_tomorrowland_2025_timetable` | Tomorrowland 2025 时间表 |
| `v_performance_count_by_genre` | 流派演出次数统计 |
| `v_multicriteria_candidate_sites` | 多准则候选地 |
| `v_affected_population_5km` | 5 km 影响人口估算 |
| `v_real_venue_match_validation` | 真实场地匹配验证 |
| `v_venue_scale_risk_summary` | 场地规模与敏感设施风险 |
| `v_dynamic_site_scores` | 动态候选地评分 |

## 5. 下一步

1. 使用 Eurostat/GISCO population grid 替换合成人口网格。
2. 在 QGIS 中连接 `festival_gis`，加载 `candidate_sites`、`venues`、`ecological_protected_areas`、`noise_sensitive_facilities` 等图层并截图。
3. 基于公开数据重新计算 `site_evaluations`，生成新的候选地评分排名。
4. 将本文件中的结果表与地图截图合并进最终课程报告。

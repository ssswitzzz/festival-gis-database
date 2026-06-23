# 2026-06-22 数据更新：真实场地边界修正

## 本轮完成内容

本轮优先修正了 Tomorrowland 2025 举办场地 `De Schorre` 的真实场地边界。原 `venues.geom_polygon` 为课程演示用近似矩形，面积明显偏大；现已使用 OSM 候选地中的 `Provinciaal Domein De Schorre` 边界替换。

## 更新对象

| 表 | 记录 | 字段 |
| :--- | :--- | :--- |
| `venues` | `De Schorre` | `geom_polygon`、`area_sqm`、`data_source` |

## 来源边界

| 来源表 | 来源记录 | 数据来源 |
| :--- | :--- | :--- |
| `candidate_sites` | `Provinciaal Domein De Schorre` | OpenStreetMap Overpass API |

## 更新前后对比

| 指标 | 更新前 | 更新后 |
| :--- | ---: | ---: |
| `venues.area_sqm` | 750,000 | 696,474.52 |
| `ST_Area(venues.geom_polygon)` | 3,986,715 | 696,475 |
| 边界类型 | 手工近似矩形 | OSM 公园/场地边界 |

更新后，`venues.De Schorre` 与 `candidate_sites.Provinciaal Domein De Schorre` 的几何距离为 0 m，面积一致。

## 重要说明

该边界表示 OSM 中的 `Provinciaal Domein De Schorre` 公园/场地边界，可作为 De Schorre 真实场地边界的公开数据近似。

它不等同于 Tomorrowland 官方活动运营红线，因为音乐节实际使用范围可能包括临时舞台区、入口、后台、DreamVille 或其他临时设施，也可能只使用公园边界内的一部分。最终报告中建议表述为：

> De Schorre 的场地边界使用 OpenStreetMap 中 `Provinciaal Domein De Schorre` 的公开边界替换原近似矩形；该边界代表公园/场地范围，不代表 Tomorrowland 官方活动运营边界。

## 新增脚本

| 文件 | 作用 |
| :--- | :--- |
| `sql/14_update_real_venue_boundaries.sql` | 将 De Schorre 的 `venues.geom_polygon` 更新为 OSM 边界 |

## QGIS 工程状态

已保存 QGIS 工程：

```text
qgis-project/festival_gis_site_analysis.qgz
```

工程中的 `venues_real_festival_sites` 图层已经能够读取更新后的 De Schorre 面积和数据来源。

## 后续建议

1. 使用同样方法检查 `Walibi Holland event grounds` 是否能匹配到合适的 OSM 边界。
2. 使用同样方法检查 `Beekse Bergen` 是否能匹配到合适的 OSM 边界。
3. 如果 OSM 边界不够贴近音乐节实际使用范围，可在 QGIS 中基于官方地图或卫星图手工矢量化活动运营范围，并在 `data_source` 中明确说明。

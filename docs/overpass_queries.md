# Overpass 查询模板

如果不下载完整 Geofabrik Shapefile，可以用 Overpass Turbo 提取小范围 OSM 数据，再导出 GeoJSON 导入 PostGIS。下面模板使用经纬度范围覆盖比利时和荷兰附近，正式使用时可以缩小范围以提升速度。

## 候选场地

```text
[out:json][timeout:180];
(
  way["leisure"~"^(park|recreation_ground)$"](49.4,2.4,53.8,7.3);
  relation["leisure"~"^(park|recreation_ground)$"](49.4,2.4,53.8,7.3);
  way["tourism"="camp_site"](49.4,2.4,53.8,7.3);
  relation["tourism"="camp_site"](49.4,2.4,53.8,7.3);
  way["landuse"~"^(grass|recreation_ground)$"](49.4,2.4,53.8,7.3);
  relation["landuse"~"^(grass|recreation_ground)$"](49.4,2.4,53.8,7.3);
  way["amenity"="events_venue"](49.4,2.4,53.8,7.3);
  relation["amenity"="events_venue"](49.4,2.4,53.8,7.3);
);
out body;
>;
out skel qt;
```

## 噪声敏感设施

```text
[out:json][timeout:180];
(
  node["amenity"~"^(hospital|school|kindergarten|college|university)$"](49.4,2.4,53.8,7.3);
  way["amenity"~"^(hospital|school|kindergarten|college|university)$"](49.4,2.4,53.8,7.3);
  relation["amenity"~"^(hospital|school|kindergarten|college|university)$"](49.4,2.4,53.8,7.3);
);
out center;
```

## 交通枢纽

```text
[out:json][timeout:180];
(
  node["aeroway"="aerodrome"](49.4,2.4,53.8,7.3);
  way["aeroway"="aerodrome"](49.4,2.4,53.8,7.3);
  node["railway"="station"](49.4,2.4,53.8,7.3);
  node["amenity"="bus_station"](49.4,2.4,53.8,7.3);
);
out center;
```

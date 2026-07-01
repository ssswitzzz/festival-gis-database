import os
from qgis.core import *
from qgis.gui import *
from qgis.PyQt.QtCore import QSize, QTimer
from qgis.PyQt.QtGui import QColor
import processing

def run():
    project = QgsProject.instance()
    root = project.layerTreeRoot()
    
    # 1. 查找现有图层
    layers = project.mapLayers()
    candidate_sites_layer = None
    noise_layer = None
    eco_layer = None
    base_layer = None
    ref_layer = None
    osm_layer = None
    
    for l in layers.values():
        if l.name() == 'candidate_sites':
            candidate_sites_layer = l
        elif l.name() == 'noise_sensitive_facilities':
            noise_layer = l
        elif l.name() == 'ecological_protected_areas':
            eco_layer = l
        elif l.name() == 'Light_Gray_Canvas_Base':
            base_layer = l
        elif l.name() == 'Light_Gray_Canvas_Reference':
            ref_layer = l
        elif l.name() == 'OpenStreetMap':
            osm_layer = l

    if not candidate_sites_layer or not noise_layer:
        print("错误: 项目中未找到 candidate_sites 或 noise_sensitive_facilities 图层！")
        return
        
    print("成功找到候选地(candidate_sites)与噪声敏感设施(noise_sensitive_facilities)图层。")
    
    # 2. 从PostgreSQL加载人口网格(population_grids)图层（如果不存在）
    pop_layer = None
    for l in layers.values():
        if l.name() == 'population_grids':
            pop_layer = l
            break
            
    if not pop_layer:
        print("正在从PostgreSQL加载人口网格(population_grids)图层...")
        uri = QgsDataSourceUri()
        uri.setConnection("localhost", "5432", "festival_gis", "postgres", "Bling0Bling")
        uri.setDataSource("public", "population_grids", "geom_polygon", "", "grid_id")
        pop_layer = QgsVectorLayer(uri.uri(), "population_grids", "postgres")
        if not pop_layer.isValid():
            print("错误: 无法加载人口网格图层，请检查数据库连接。")
            return
        project.addMapLayer(pop_layer)
        print("人口网格图层加载成功。")
    else:
        print("人口网格图层已存在于项目中。")

    # 3. 为候选地生成 5 km 缓冲区
    # 如果已存在旧的缓冲区图层，先将其移除
    old_buffer = None
    for l in layers.values():
        if l.name() == '候选地 5km 缓冲区':
            old_buffer = l
            break
    if old_buffer:
        project.removeMapLayer(old_buffer.id())
        print("已移除旧的缓冲区图层。")
        
    print("正在生成候选地 5 km 缓冲区...")
    # 5 km = 5000 米（因为 candidate_sites 投影为 EPSG:3035，单位是米）
    buffer_params = {
        'INPUT': candidate_sites_layer,
        'DISTANCE': 5000,
        'SEGMENTS': 10,
        'END_CAP_STYLE': 0, # 圆头
        'JOIN_STYLE': 0, # 圆角
        'MITER_LIMIT': 2,
        'DISSOLVE': True,
        'OUTPUT': 'memory:candidate_sites_5km_buffer'
    }
    buffer_result = processing.run("native:buffer", buffer_params)
    buffer_layer = buffer_result['OUTPUT']
    buffer_layer.setName("候选地 5km 缓冲区")
    project.addMapLayer(buffer_layer)
    print("5 km 缓冲区生成成功。")

    # 4. 样式渲染与美化
    print("正在应用视觉样式样式...")
    
    # 缓冲区样式：半透明红/橙色填充，较深颜色的边界
    buffer_symbol = QgsFillSymbol.createSimple({
        'color': '255,110,40,70',       # 半透明红橙色 (Alpha=70)
        'outline_color': '244,67,54,200', # 红色边界
        'outline_width': '0.5',
        'outline_style': 'solid'
    })
    buffer_layer.setRenderer(QgsSingleSymbolRenderer(buffer_symbol))
    buffer_layer.triggerRepaint()

    # 候选地样式：较粗的深灰色边界，无填充（中空），以便突出候选地本身
    site_symbol = QgsFillSymbol.createSimple({
        'color': '0,0,0,0',              # 完全透明填充
        'outline_color': '33,33,33,255', # 深黑边界
        'outline_width': '0.8',
        'outline_style': 'solid'
    })
    candidate_sites_layer.setRenderer(QgsSingleSymbolRenderer(site_symbol))
    candidate_sites_layer.triggerRepaint()

    # 人口网格样式：淡淡铺底 (透明度30%)，使用渐变色表示人口密度
    print("正在配置人口网格渐变样式...")
    pop_layer.setOpacity(0.30)
    
    # 自定义渐变区间 (根据人口数量划分为5个等级，采用优雅的淡蓝色系)
    ranges = []
    pop_colors = [
        ('0 - 50', 0, 50, '240,244,248,255'),      # 极低人口（极淡灰蓝）
        ('50 - 200', 50, 200, '208,224,238,255'),   # 低人口（浅蓝）
        ('200 - 500', 200, 500, '164,194,222,255'), # 中人口（柔蓝）
        ('500 - 1500', 500, 1500, '116,158,198,255'),# 高人口（中蓝）
        ('1500+', 1500, 999999, '68,114,168,255')    # 极高人口（钢蓝）
    ]
    
    for label, lower, upper, color_str in pop_colors:
        sym = QgsFillSymbol.createSimple({
            'color': color_str,
            'outline_color': '200,200,200,40', # 淡淡的网格线
            'outline_width': '0.1'
        })
        rng = QgsRendererRange(lower, upper, sym, label)
        ranges.append(rng)
        
    pop_renderer = QgsGraduatedSymbolRenderer('population', ranges)
    pop_layer.setRenderer(pop_renderer)
    pop_layer.triggerRepaint()

    # 噪声敏感设施样式：使用分类渲染器，不同类型设施（学校、医院、养老院）使用不同形状与颜色图标
    print("正在配置噪声敏感设施分类标记样式...")
    categories = []
    
    # 医院 (hospital)：红色十字 (cross)
    sym_hospital = QgsMarkerSymbol.createSimple({
        'name': 'cross',
        'color': '229,57,53,255', # 鲜红
        'size': '4.5',
        'outline_color': '229,57,53,255',
        'outline_width': '0.8'
    })
    cat_hospital = QgsRendererCategory('hospital', sym_hospital, 'Hospital (医院)')
    
    # 学校 (school)：蓝色圆点 (circle)
    sym_school = QgsMarkerSymbol.createSimple({
        'name': 'circle',
        'color': '30,136,229,255', # 天蓝
        'size': '3.5',
        'outline_color': '21,101,192,255', # 深蓝描边
        'outline_width': '0.4'
    })
    cat_school = QgsRendererCategory('school', sym_school, 'School (学校)')
    
    # 养老设施 (elderly_care)：紫色三角形 (triangle)
    sym_elderly = QgsMarkerSymbol.createSimple({
        'name': 'triangle',
        'color': '142,36,170,255', # 紫色
        'size': '3.8',
        'outline_color': '106,27,154,255', # 深紫描边
        'outline_width': '0.4'
    })
    cat_elderly = QgsRendererCategory('elderly_care', sym_elderly, 'Elderly Care (养老设施)')
    
    # 住宅区 (residential)：灰色方块 (square)
    sym_residential = QgsMarkerSymbol.createSimple({
        'name': 'square',
        'color': '120,120,120,255', # 中灰
        'size': '2.2',
        'outline_color': '80,80,80,255',
        'outline_width': '0.3'
    })
    cat_residential = QgsRendererCategory('residential', sym_residential, 'Residential (住宅区)')
    
    categories.extend([cat_hospital, cat_school, cat_elderly, cat_residential])
    
    noise_renderer = QgsCategorizedSymbolRenderer('facility_type', categories)
    noise_layer.setRenderer(noise_renderer)
    noise_layer.triggerRepaint()

    # 生态保护区样式（如果存在）：淡淡的绿色填充，突出自然屏障
    if eco_layer:
        print("正在配置生态保护区样式...")
        eco_symbol = QgsFillSymbol.createSimple({
            'color': '76,175,80,25',        # 极淡绿填充 (Alpha=25)
            'outline_color': '76,175,80,100',# 淡绿边界
            'outline_width': '0.3',
            'outline_style': 'solid'
        })
        eco_layer.setRenderer(QgsSingleSymbolRenderer(eco_symbol))
        eco_layer.triggerRepaint()

    # 5. 调整图层可见性
    print("正在调整图层可见性...")
    if base_layer:
        root.findLayer(base_layer.id()).setItemVisibilityChecked(True)
    if ref_layer:
        root.findLayer(ref_layer.id()).setItemVisibilityChecked(True)
    if osm_layer:
        root.findLayer(osm_layer.id()).setItemVisibilityChecked(False)
    if eco_layer:
        root.findLayer(eco_layer.id()).setItemVisibilityChecked(True)
        
    root.findLayer(pop_layer.id()).setItemVisibilityChecked(True)
    root.findLayer(buffer_layer.id()).setItemVisibilityChecked(True)
    root.findLayer(candidate_sites_layer.id()).setItemVisibilityChecked(True)
    root.findLayer(noise_layer.id()).setItemVisibilityChecked(True)

    # 6. 排序图层：从上到下决定渲染顺序（点在最上，线面在中，底图在最下）
    print("正在调整图层渲染顺序...")
    layer_order_names = [
        'noise_sensitive_facilities',
        'candidate_sites',
        '候选地 5km 缓冲区',
        'ecological_protected_areas',
        'population_grids',
        'Light_Gray_Canvas_Reference',
        'Light_Gray_Canvas_Base',
        'OpenStreetMap'
    ]
    
    # 提取并克隆 legend 中的所有图层节点，然后从树中临时移除
    nodes = {}
    for child in list(root.children()):
        if isinstance(child, QgsLayerTreeLayer):
            nodes[child.layerName()] = child.clone()
            root.removeChildNode(child)
            
    # 按照指定的顺序重新插入到图层树中
    for name in layer_order_names:
        for k, node in nodes.items():
            if k == name or (name in k):
                root.addChildNode(node)
                break
                
    # 将未在排序列表中的其余图层插入到末尾
    for k, node in nodes.items():
        already_added = False
        for name in layer_order_names:
            if k == name or (name in k):
                already_added = True
                break
        if not already_added:
            root.addChildNode(node)

    # 7. 自动缩放到缓冲区范围并保存地图
    print("正在缩放画布至缓冲区图层范围...")
    iface.setActiveLayer(buffer_layer)
    iface.zoomToActiveLayer()
    
    # 稍微缩小一点(放大比例因子1.2)，留出美观的边缘留白
    canvas = iface.mapCanvas()
    canvas.zoomByFactor(1.20)
    canvas.refresh()
    
    # 创建导出目录（如果不存在）
    export_dir = r"c:\Users\12907\Desktop\2025-2026大三下学期\数据库原理及应用\数据库期末作业\exports"
    if not os.path.exists(export_dir):
        os.makedirs(export_dir)
        
    export_path = os.path.join(export_dir, "noise_sensitive_facilities_5km_buffer.png")
    
    # 使用定时器延迟 1.5 秒再截图保存，确保 QGIS 已经完全绘制完毕所有图层，避免白图
    def save_canvas():
        canvas.saveAsImage(export_path)
        project.write() # 保存项目
        print(f"\n★ 成功：地图已成功保存至: {export_path}")
        print("★ 成功：QGIS 项目文件已保存！")
        
    QTimer.singleShot(1500, save_canvas)

# 执行脚本
run()

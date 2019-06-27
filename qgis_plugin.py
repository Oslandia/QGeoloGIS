# -*- coding: utf-8 -*-
#
#   Copyright (C) 2019 Oslandia <infos@oslandia.com>
#
#   This file is a piece of free software; you can redistribute it and/or
#   modify it under the terms of the GNU Library General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#   
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Library General Public License for more details.
#   You should have received a copy of the GNU Library General Public
#   License along with this library; if not, see <http://www.gnu.org/licenses/>.
#

from .qgeologis.qt_qgis_compat import QgsMapTool, QgsPoint, qgsCoordinateTransform, QgsRectangle, QgsGeometry
from .qgeologis.qt_qgis_compat import QgsMessageBar, QgsFeatureRequest, QgsVectorLayer

from .qgeologis.log_view import WellLogView
from .qgeologis.timeseries_view import TimeSeriesView
from .qgeologis.data_interface import FeatureData, LayerData

from qgis.PyQt.QtCore import Qt, pyqtSignal, QSettings
from qgis.PyQt.QtWidgets import QAction, QDialog, QVBoxLayout, QDialogButtonBox, QAbstractItemView
from qgis.PyQt.QtWidgets import QListWidget, QListWidgetItem, QHBoxLayout, QLabel, QComboBox, QPushButton
from qgis.PyQt.QtWidgets import QFileDialog

class FeatureSelectionTool(QgsMapTool):   
    pointClicked = pyqtSignal(QgsPoint)
    rightClicked = pyqtSignal(QgsPoint)
    featureSelected = pyqtSignal(list)

    def __init__(self, canvas, layer, tolerance_px = 5):
        super(FeatureSelectionTool, self).__init__(canvas)
        self.setCursor(Qt.CrossCursor)
        self.__layer = layer
        self.__tolerance_px = tolerance_px

    def canvasMoveEvent(self, event):
        pass

    def canvasPressEvent(self, event):
        #Get the click
        x = event.pos().x()
        y = event.pos().y()
        tr = self.canvas().getCoordinateTransform()
        point = tr.toMapCoordinates(x, y)
        if event.button() == Qt.RightButton:
            self.rightClicked.emit(QgsPoint(point.x(), point.y()))
        else:
            self.pointClicked.emit(QgsPoint(point.x(), point.y()))

            canvas_rect = QgsRectangle(tr.toMapCoordinates(x-self.__tolerance_px, y-self.__tolerance_px),
                                       tr.toMapCoordinates(x+self.__tolerance_px, y+self.__tolerance_px))
            ct = qgsCoordinateTransform(self.canvas().mapSettings().destinationCrs(), self.__layer.crs())
            box = QgsGeometry.fromRect(canvas_rect)
            box.transform(ct)

            req = QgsFeatureRequest()
            req.setFilterRect(box.boundingBox())
            req.setFlags(QgsFeatureRequest.ExactIntersect)
            features = list(self.__layer.getFeatures(req))
            if features:
                self.featureSelected.emit(features)

    def isZoomTool(self):
        return False

    def isTransient(self):
        return True

    def isEditTool(self):
        return True

class DataSelector(QDialog):
    #def select_data_to_add(viewer, feature_id, config_list):
    def __init__(self, viewer, feature_id, feature_name, config_list, config):
        QDialog.__init__(self)

        self.__viewer = viewer
        self.__feature_id = feature_id
        self.__config_list = config_list
        self.__config = config

        vbox = QVBoxLayout()

        btn = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        btn.accepted.connect(self.accept)
        btn.rejected.connect(self.reject)

        self.__list = QListWidget()
        self.__list.setSelectionMode(QAbstractItemView.ExtendedSelection)

        hbox = QHBoxLayout()
        lbl = QLabel("Sub selection")
        self.__sub_selection_combo = QComboBox()
        self.__sub_selection_combo.setEnabled(False)
        hbox.addWidget(lbl)
        hbox.addWidget(self.__sub_selection_combo)

        from_elsewhere_btn = QPushButton("Select another station")

        self.__title_label = QLabel()

        hbox2 = QHBoxLayout()
        hbox2.addWidget(self.__title_label)
        hbox2.addWidget(from_elsewhere_btn)
        
        vbox.addLayout(hbox2)
        vbox.addWidget(self.__list)
        vbox.addLayout(hbox)
        vbox.addWidget(btn)

        self.__list.itemSelectionChanged.connect(self.on_selection_changed)
        self.__sub_selection_combo.currentIndexChanged[str].connect(self.on_combo_changed)
        from_elsewhere_btn.clicked.connect(self.on_from_elsewhere_clicked)

        self.setLayout(vbox)
        self.setWindowTitle("Choose the data to add")
        self.resize(400,200)

        self._populate_list()
        self.set_title(feature_name)

    def set_title(self, title):
        self.__title_label.setText("Station: {}".format(title))

    def _populate_list(self):
        self.__list.clear()
        for cfg in self.__config_list:
            if cfg["type"] in ("continuous", "instantaneous"):
                uri, provider = cfg["source"]
                # check number of features for this station
                data_l = QgsVectorLayer(uri, "data_layer", provider)
                req = QgsFeatureRequest()
                req.setFilterExpression("{}={}".format(cfg["feature_ref_column"], self.__feature_id))
                if len(list(data_l.getFeatures(req))) == 0:
                    continue

                if cfg.get("feature_filter_type") == "unique_data_from_values":
                    # get unique filter values
                    cfg["filter_unique_values"] = sorted(list(set([f[cfg["feature_filter_column"]] for f in data_l.getFeatures(req)])))

            elif cfg["type"] == "image":
                if not self.__viewer.has_imagery_data(cfg):
                    continue

            item = QListWidgetItem(cfg["name"])
            item.setData(Qt.UserRole, cfg)
            self.__list.addItem(item)

    def accept(self):
        for item in self.__list.selectedItems():
            # now add the selected configuration
            cfg = item.data(Qt.UserRole)
            if cfg["type"] in ("continuous", "instantaneous"):
                uri, provider = cfg["source"]
                data_l = QgsVectorLayer(uri, "data_layer", provider)
                req = QgsFeatureRequest()
                filter_expr = "{}={}".format(cfg["feature_ref_column"], self.__feature_id)
                req.setFilterExpression(filter_expr)
                print("Layer", uri, "Filter", filter_expr)

                title = cfg["name"]

                if cfg["type"] == "instantaneous":
                    if "filter_value" in cfg:
                        filter_expr += " and {}='{}'".format(cfg["feature_filter_column"], cfg["filter_value"])
                        title = cfg["filter_value"]
                    else:
                        title = cfg["name"]

                    f = None
                    for f in data_l.getFeatures(req):
                        pass
                    if f is None:
                        return
                    uom = cfg["uom"] if "uom" in cfg else "@" + cfg["uom_column"]
                    data = LayerData(data_l, cfg["event_column"], cfg["value_column"], filter_expression=filter_expr, uom=uom)
                    uom = data.uom()

                if cfg["type"] == "continuous":
                    uom = cfg["uom"]
                    fids = [f.id() for f in data_l.getFeatures(req)]
                    data = FeatureData(data_l, cfg["values_column"], feature_ids=fids,
                                       x_start_fieldname=cfg["start_measure_column"],
                                       x_delta_fieldname=cfg["interval_column"])

                if hasattr(self.__viewer, "add_data_column"):
                    self.__viewer.add_data_column(data, title, uom)
                if hasattr(self.__viewer, "add_data_row"):
                    self.__viewer.add_data_row(data, title, uom)
            elif cfg["type"] == "image":
                self.__viewer.add_imagery_from_db(cfg)

        QDialog.accept(self)

    def on_selection_changed(self):
        self.__sub_selection_combo.clear()
        self.__sub_selection_combo.setEnabled(False)
        for item in self.__list.selectedItems():
            cfg = item.data(Qt.UserRole)
            if "filter_unique_values" in cfg:
                for v in cfg["filter_unique_values"]:
                    self.__sub_selection_combo.addItem(v)
            if "filter_value" in cfg:
                self.__sub_selection_combo.setCurrentIndex(self.__sub_selection_combo.findText(cfg["filter_value"]))
            self.__sub_selection_combo.setEnabled(True)
            return

    def on_combo_changed(self, text):
        for item in self.__list.selectedItems():
            cfg = item.data(Qt.UserRole)
            cfg["filter_value"] = text
            item.setData(Qt.UserRole, cfg)
            return

    def on_from_elsewhere_clicked(self):
        layer_config = get_layer_config()
        from qgis.utils import iface
        if iface.activeLayer() is None:
            iface.messageBar().pushMessage(u"Please select an active layer", QgsMessageBar.CRITICAL)
            return
        uri, provider = iface.activeLayer().source(), iface.activeLayer().dataProvider().name()
        if (uri, provider) not in layer_config:
            iface.messageBar().pushMessage(u"Unconfigured layer", QgsMessageBar.CRITICAL)
            return

        config = layer_config[(uri, provider)]
        iface.messageBar().pushMessage(u"Please select a feature on the active layer")
        self.__tool = FeatureSelectionTool(iface.mapCanvas(), iface.activeLayer())
        iface.mapCanvas().setMapTool(self.__tool)
        self.__tool.featureSelected.connect(self.on_other_station_selected)

        self.setModal(False)
        self.setWindowState(Qt.WindowMinimized)

    def on_other_station_selected(self, selected):
        self.__feature_id = selected[0].id()
        self._populate_list()
        self.set_title(selected[0][self.__config["name_column"]])
        self.setModal(True)
        self.setWindowState(Qt.WindowActive)

class WellLogViewWrapper(WellLogView):
    def __init__(self, config, feature):
        WellLogView.__init__(self, feature[config["name_column"]])
        self.setWindowTitle("Well log viewer")
        self.__config = config
        self.__feature = feature

        cfg = config["stratigraphy_config"]
        uri, provider = cfg["source"]
        l = QgsVectorLayer(uri, "layer", provider)
        f = "{}={}".format(cfg["feature_ref_column"], feature.id())
        l.setSubsetString(f)
        self.add_stratigraphy(l, (cfg["depth_from_column"],
                                  cfg["depth_to_column"],
                                  cfg["formation_code_column"],
                                  cfg["rock_code_column"],
                                  cfg.get("formation_description_column"),
                                  cfg.get("rock_description_column")), "Stratigraphy")

    def on_add_column(self):
        sources = list(self.__config["log_measures"])
        sources += [dict(list(d.items()) + [("type","image")]) for d in self.__config["imagery_data"]]
        s = DataSelector(self, self.__feature.id(), self.__feature[self.__config["name_column"]], sources, self.__config)
        s.exec_()

    def has_imagery_data(self, cfg):
        if cfg.get("provider", "postgres_bytea") != "postgres_bytea":
            # not implemented
            return False

        import psycopg2
        conn = psycopg2.connect(cfg["source"])
        cur = conn.cursor()
        cur.execute("select count(*) from {schema}.{table} where {ref_column}=%s"\
                    .format(schema=cfg["schema"],
                            table=cfg["table"],
                            ref_column=cfg["feature_ref_column"]),
                    (self.__feature.id(),))
        return cur.fetchone()[0] > 0

    def add_imagery_from_db(self, cfg):
        if cfg.get("provider", "postgres_bytea") != "postgres_bytea":
            raise "Access method not implemented !"
            
        import psycopg2
        import tempfile
        conn = psycopg2.connect(cfg["source"])
        cur = conn.cursor()
        cur.execute("select {depth_from}, {depth_to}, {data}, {format} from {schema}.{table} where {ref_column}=%s"\
                    .format(depth_from=cfg.get("depth_from_column", "depth_from"),
                            depth_to=cfg.get("depth_to_column", "depth_to"),
                            data=cfg.get("image_data_column", "image_data"),
                            format=cfg.get("image_data_column", "image_format"),
                            schema=cfg["schema"],
                            table=cfg["table"],
                            ref_column=cfg["feature_ref_column"]),
                    (self.__feature.id(),))
        r = cur.fetchone()
        if r is None:
            return

        depth_from, depth_to = float(r[0]), float(r[1])
        image_data = r[2]
        image_format = r[3]
        f = tempfile.NamedTemporaryFile(mode="wb", suffix=image_format.lower())
        image_filename = f.name
        f.close()
        with open(image_filename, "wb") as fo:
            fo.write(image_data)
        self.add_imagery(image_filename, cfg["name"], depth_from, depth_to)
        

class TimeSeriesWrapper(TimeSeriesView):
    def __init__(self, config, feature):
        TimeSeriesView.__init__(self, feature[config["name_column"]])
        self.setWindowTitle("Time series viewer")
        self.__config = config
        self.__feature = feature

    def on_add_row(self):
        s = DataSelector(self, self.__feature.id(), self.__feature[self.__config["name_column"]], self.__config["timeseries"], self.__config)
        s.exec_()

def get_layer_config():
    """Open and parse the configuration file"""

    import os
    s = QSettings("Oslandia", "qgeologis")
    config_file = s.value("config_file", os.path.join(os.path.dirname(__file__), "layer_config.py"))
    f = open(config_file, "r")
    layer_config = {}
    # the configuration file is a regular Python file
    # exec() will parse it and populate layer_config

    exec(f.read())  # FIXME port to python 3
    return layer_config
        
class QGeoloGISPlugin:
    def __init__(self, iface):
        self.iface = iface

        # look for the layer_config
        try:
            get_layer_config()
        except IOError:
            self.iface.messageBar().pushMessage(u"Cannot find the layer config !", QgsMessageBar.CRITICAL)
            return
            

        # current map tool
        self.__tool = None
        self.__windows = []

    def initGui(self):
        self.view_log_action = QAction(u'View well log', self.iface.mainWindow())
        self.view_timeseries_action = QAction(u'View timeseries', self.iface.mainWindow())
        self.load_base_layer_action = QAction(u'Load base layer', self.iface.mainWindow())
        self.view_log_action.triggered.connect(lambda : self.on_view_graph(WellLogViewWrapper))
        self.view_timeseries_action.triggered.connect(lambda: self.on_view_graph(TimeSeriesWrapper))
        self.load_base_layer_action.triggered.connect(self.on_load_base_layer)
        self.iface.addToolBarIcon(self.view_log_action)
        self.iface.addToolBarIcon(self.view_timeseries_action)
        self.iface.addToolBarIcon(self.load_base_layer_action)

        self.load_config_action = QAction("Load configuration file", self.iface.mainWindow())
        self.load_config_action.triggered.connect(self.on_load_config)
        self.iface.addPluginToMenu(u"QGeoloGIS", self.load_config_action)

    def unload(self):
        self.iface.removeToolBarIcon(self.view_log_action)
        self.iface.removeToolBarIcon(self.view_timeseries_action)
        self.iface.removeToolBarIcon(self.load_base_layer_action)
        self.view_log_action.setParent(None)
        self.view_timeseries_action.setParent(None)
        self.load_base_layer_action.setParent(None)
        
        self.iface.removePluginMenu(u"QGeoloGIS", self.load_config_action)
        self.load_config_action.setParent(None)

    def on_view_graph(self, graph_class):
        layer_config = get_layer_config()
        if self.iface.activeLayer() is None:
            self.iface.messageBar().pushMessage(u"Please select an active layer", QgsMessageBar.CRITICAL)
            return
        uri, provider = self.iface.activeLayer().source(), self.iface.activeLayer().dataProvider().name()
        if (uri, provider) not in layer_config:
            self.iface.messageBar().pushMessage(u"Unconfigured layer", QgsMessageBar.CRITICAL)
            return

        config = layer_config[(uri, provider)]
        self.iface.messageBar().pushMessage(u"Please select a feature on the active layer")
        self.__tool = FeatureSelectionTool(self.iface.mapCanvas(), self.iface.activeLayer())
        self.iface.mapCanvas().setMapTool(self.__tool)

        def on_feature_selected(features):
            w = graph_class(config, features[0])
            w.show()
            self.__windows.append(w)
        self.__tool.featureSelected.connect(on_feature_selected)

    def on_load_base_layer(self):
        # look for base layers in the config
        layer_config = get_layer_config()

        dlg = QDialog()
        vbox = QVBoxLayout()
        list_widget = QListWidget()
        button_box = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        vbox.addWidget(list_widget)
        vbox.addWidget(button_box)
        dlg.setWindowTitle("Select a base layer to load")
        dlg.setLayout(vbox)

        # populate the list widget
        for (uri, provider), cfg in layer_config.items():
            layer_name = cfg.get("layer_name", "Unnamed layer ({}, {})".format(uri, provider))
            list_item = QListWidgetItem()
            list_item.setText(layer_name)
            list_item.setData(Qt.UserRole, (uri, provider))
            list_widget.addItem(list_item)

        button_box.rejected.connect(dlg.reject)
        button_box.accepted.connect(dlg.accept)

        if dlg.exec_():
            item = list_widget.currentItem()
            if item:
                uri, provider = item.data(Qt.UserRole)
                self.iface.addVectorLayer(uri, item.text(), provider)

    def on_load_config(self):
        import os
        file_name = QFileDialog.getOpenFileName(None, "Choose a configuration file to load", os.path.dirname(__file__))
        if file_name:
            s = QSettings("Oslandia", "qgeologis")
            s.setValue("config_file", file_name)
            get_layer_config()

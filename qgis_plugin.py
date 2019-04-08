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

from well_log.qt_qgis_compat import QgsMapTool, QgsPoint, QgsCoordinateTransform, QgsRectangle, QgsGeometry
from well_log.qt_qgis_compat import QgsMessageBar, QgsFeatureRequest, QgsDataSourceURI, QgsVectorLayer, QgsWKBTypes

from well_log.well_log_view import WellLogView
from well_log.timeseries_view import TimeSeriesView
from well_log.data_interface import FeatureData

from qgis.PyQt.QtCore import Qt, pyqtSignal
from qgis.PyQt.QtWidgets import QAction, QDialog, QVBoxLayout, QDialogButtonBox
from qgis.PyQt.QtWidgets import QListWidget, QListWidgetItem

class FeatureSelectionTool(QgsMapTool):   
    pointClicked = pyqtSignal(QgsPoint)
    rightClicked = pyqtSignal(QgsPoint)
    featureSelected = pyqtSignal(list)

    def __init__(self, canvas, layer, tolerance_px = 2):
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
            ct = QgsCoordinateTransform(self.canvas().mapSettings().destinationCrs(), self.__layer.crs())
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

def select_data_to_add(viewer, feature_id, config_list, base_uri):
    dlg = QDialog()

    vbox = QVBoxLayout()

    btn = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
    btn.accepted.connect(dlg.accept)
    btn.rejected.connect(dlg.reject)

    lw = QListWidget()

    vbox.addWidget(lw)
    vbox.addWidget(btn)

    for cfg in config_list:
        uri = QgsDataSourceURI(base_uri)
        uri.setDataSource(cfg["schema"], cfg["table"], None, "", cfg["key"])
        # check number of features for this station
        data_l = QgsVectorLayer(uri.uri(), "data_layer", "postgres")
        req = QgsFeatureRequest()
        req.setFilterExpression("{}={}".format(cfg["feature_ref_column"], feature_id))
        if len(list(data_l.getFeatures(req))) == 0:
            continue

        item = QListWidgetItem(cfg["name"])
        item.setData(Qt.UserRole, cfg)
        lw.addItem(item)

    dlg.setLayout(vbox)
    dlg.setWindowTitle("Choose the data to add")
    dlg.resize(400,200)
    r = dlg.exec_()
    if r != QDialog.Accepted:
        return
    
    item = lw.currentItem()
    if item is None:
        return

    # now add the selected configuration
    cfg = item.data(Qt.UserRole)
    uri = QgsDataSourceURI(base_uri)
    uri.setDataSource(cfg["schema"], cfg["table"], None, "", cfg["key"])
    data_l = QgsVectorLayer(uri.uri(), "data_layer", "postgres")
    req = QgsFeatureRequest()
    req.setFilterExpression("{}={}".format(cfg["feature_ref_column"], feature_id))
    f = None
    for f in data_l.getFeatures(req):
        pass
    if f is None:
        return
    if cfg["type"] == "continuous":
        fd = FeatureData(data_l, cfg["values_column"], feature_id=f[cfg["key"]], x_start=f[cfg["start_measure_column"]], x_delta=f[cfg["interval_column"]])
        if hasattr(viewer, "add_data_column"):
            viewer.add_data_column(fd, cfg["name"], cfg["uom"])
        if hasattr(viewer, "add_data_row"):
            viewer.add_data_row(fd, cfg["name"], cfg["uom"])            
    else:
        # TODO
        pass
    

class WellLogViewWrapper(WellLogView):
    def __init__(self, config, base_uri, feature):
        WellLogView.__init__(self, feature[config["name_column"]])
        self.__config = config
        self.__base_uri = base_uri
        self.__feature = feature

        cfg = config["stratigraphy_config"]
        uri = QgsDataSourceURI(base_uri)
        uri.setDataSource(cfg["schema"], cfg["table"], None, "", cfg["key"])
        l = QgsVectorLayer(uri.uri(), "layer", "postgres")
        f = "{}={}".format(cfg["feature_ref_column"], feature.id())
        l.setSubsetString(f)
        self.add_stratigraphy(l, (cfg["depth_from_column"], cfg["depth_to_column"], cfg["formation_code_column"], cfg["rock_code_column"]), "Stratigraphie")

    def on_add_column(self):
        select_data_to_add(self, self.__feature.id(), self.__config["log_measures"], self.__base_uri)

class TimeSeriesWrapper(TimeSeriesView):
    def __init__(self, config, base_uri, feature):
        TimeSeriesView.__init__(self, feature[config["name_column"]])
        self.__config = config
        self.__base_uri = base_uri
        self.__feature = feature

    def on_add_row(self):
        select_data_to_add(self, self.__feature.id(), self.__config["timeseries"], self.__base_uri)

class WellLogPlugin:
    def __init__(self, iface):
        self.iface = iface

        # look for the layer_config
        try:
            from layer_config import layer_config
        except ImportError:
            self.iface.messageBar().pushMessage(u"Cannot find the layer config !", QgsMessageBar.CRITICAL)
            return
            

        # current map tool
        self.__tool = None
        self.__windows = []

    def initGui(self):
        self.view_log_action = QAction(u'View well log', self.iface.mainWindow())
        self.view_timeseries_action = QAction(u'View timeseries', self.iface.mainWindow())
        self.view_log_action.triggered.connect(lambda : self.on_view_graph(WellLogViewWrapper))
        self.view_timeseries_action.triggered.connect(lambda: self.on_view_graph(TimeSeriesWrapper))
        self.iface.addToolBarIcon(self.view_log_action)
        self.iface.addToolBarIcon(self.view_timeseries_action)

    def unload(self):
        self.iface.removeToolBarIcon(self.view_log_action)
        self.iface.removeToolBarIcon(self.view_timeseries_action)
        self.view_log_action.setParent(None)
        self.view_timeseries_action.setParent(None)

    def on_view_graph(self, graph_class):
        from layer_config import layer_config
        if self.iface.activeLayer() is None:
            self.iface.messageBar().pushMessage(u"Please select an active layer", QgsMessageBar.CRITICAL)
            return
        source = self.iface.activeLayer().source()
        if source not in layer_config:
            self.iface.messageBar().pushMessage(u"Unconfigured layer", QgsMessageBar.CRITICAL)
            return

        config = layer_config[source]
        self.iface.messageBar().pushMessage(u"Please select a feature on the active layer")
        self.__tool = FeatureSelectionTool(self.iface.mapCanvas(), self.iface.activeLayer())
        self.iface.mapCanvas().setMapTool(self.__tool)

        base_uri = QgsDataSourceURI(source)
        base_uri.setWkbType(QgsWKBTypes.Unknown)
        base_uri.setSrid("")
        
        def on_feature_selected(features):
            w = graph_class(config, base_uri, features[0])
            w.show()
            self.__windows.append(w)
        self.__tool.featureSelected.connect(on_feature_selected)

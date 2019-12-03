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

import json
import os

from qgis.PyQt.QtCore import Qt, pyqtSignal
from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtWidgets import QAction

from qgis.core import (QgsPoint, QgsCoordinateTransform, QgsRectangle,
                       QgsGeometry, QgsFeatureRequest, QgsProject)
from qgis.gui import QgsMapTool

from .configure_plot_dialog import ConfigurePlotDialog
from .main_dialog import MainDialog


class FeatureSelectionTool(QgsMapTool):
    pointClicked = pyqtSignal(QgsPoint)
    rightClicked = pyqtSignal(QgsPoint)
    featureSelected = pyqtSignal(list)

    def __init__(self, canvas, layer, tolerance_px=5):
        super(FeatureSelectionTool, self).__init__(canvas)
        self.setCursor(Qt.CrossCursor)
        self.__layer = layer
        self.__tolerance_px = tolerance_px

    def canvasMoveEvent(self, event):
        pass

    def canvasPressEvent(self, event):
        # Get the click
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

            ct = QgsCoordinateTransform(self.canvas().mapSettings().destinationCrs(), self.__layer.crs(), QgsProject.instance().transformContext())
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


class QGeoloGISPlugin:
    def __init__(self, iface):
        self.iface = iface
        self.__config = None
        self.__dialogs = []

        self.update_layer_config()
        QgsProject.instance().readProject.connect(self.update_layer_config)
        QgsProject.instance().cleared.connect(self.update_layer_config)

        # current map tool
        self.__tool = None

    def initGui(self):

        icon = QIcon(os.path.join(os.path.dirname(__file__), "qgeologis/img/plot.svg"))
        self.view_plot = QAction(icon, u'View plot', self.iface.mainWindow())
        self.view_plot.triggered.connect(self.on_view_plot)
        self.iface.addToolBarIcon(self.view_plot)
        
        # self.view_timeseries_action = QAction(u'View timeseries', self.iface.mainWindow())
        # self.load_base_layer_action = QAction(u'Load base layer', self.iface.mainWindow())
        # self.view_log_action.triggered.connect(lambda : self.on_view_graph(WellLogViewWrapper))
        # self.view_timeseries_action.triggered.connect(lambda: self.on_view_graph(TimeSeriesWrapper))
        # self.load_base_layer_action.triggered.connect(self.on_load_base_layer)
        # self.iface.addToolBarIcon(self.view_log_action)
        # self.iface.addToolBarIcon(self.view_timeseries_action)
        # self.iface.addToolBarIcon(self.load_base_layer_action)

        # self.load_config_action = QAction("Load configuration file", self.iface.mainWindow())
        # self.load_config_action.triggered.connect(self.on_load_config)
        # self.iface.addPluginToMenu(u"QGeoloGIS", self.load_config_action)

    def on_view_plot(self):

        layer = self.iface.activeLayer()
        if not layer:
            return

        if layer.id() not in self.__config:
            dlg = ConfigurePlotDialog(layer, self.iface.mainWindow())
            if dlg.exec_():
                conf = dlg.config()
                self.__config[layer.id()] = conf

                json_config = json.dumps(self.__config)
                QgsProject.instance().writeEntry("QGeoloGIS", "config", json_config)

            else:
                return

        dialog = MainDialog(self.__config, layer, self.iface)
        dialog.show()
        self.__dialogs.append(dialog)

    def unload(self):

        QgsProject.instance().readProject.disconnect(self.update_layer_config)
        QgsProject.instance().cleared.disconnect(self.update_layer_config)

        # TODO windows are never destroyed until the plugin is unload
        self.__dialogs = None
    
        self.__tool = None
        self.__config = None
        
        self.iface.removeToolBarIcon(self.view_plot)
        # self.iface.removeToolBarIcon(self.view_timeseries_action)
        # self.iface.removeToolBarIcon(self.load_base_layer_action)
        self.view_plot.setParent(None)
        # self.view_timeseries_action.setParent(None)
        # self.load_base_layer_action.setParent(None)
        
        # self.iface.removePluginMenu(u"QGeoloGIS", self.load_config_action)
        # self.load_config_action.setParent(None)
        

    # def on_view_graph(self, graph_class):
    #     if self.iface.activeLayer() is None:
    #         self.iface.messageBar().pushMessage(u"Please select an active layer", QgsMessageBar.CRITICAL)
    #         return

    #     layerid = self.iface.activeLayer().id()
    #     if layerid not in self.__layer_config:
    #         self.iface.messageBar().pushMessage(u"Unconfigured layer", QgsMessageBar.CRITICAL)
    #         return

    #     config = self.__layer_config[layerid]
    #     self.iface.messageBar().pushMessage(u"Please select a feature on the active layer")
    #     self.__tool = FeatureSelectionTool(self.iface.mapCanvas(), self.iface.activeLayer())
    #     self.iface.mapCanvas().setMapTool(self.__tool)

    #     def on_feature_selected(features):
    #         w = graph_class(config, features[0])
    #         w.show()
    #         self.__windows.append(w)
    #     self.__tool.featureSelected.connect(on_feature_selected)

    # def on_load_base_layer(self):
    #     # look for base layers in the config
    #     layer_config = get_layer_config()

    #     dlg = QDialog()
    #     vbox = QVBoxLayout()
    #     list_widget = QListWidget()
    #     button_box = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
    #     vbox.addWidget(list_widget)
    #     vbox.addWidget(button_box)
    #     dlg.setWindowTitle("Select a base layer to load")
    #     dlg.setLayout(vbox)

    #     # populate the list widget
    #     for (uri, provider), cfg in layer_config.items():
    #         layer_name = cfg.get("layer_name", "Unnamed layer ({}, {})".format(uri, provider))
    #         list_item = QListWidgetItem()
    #         list_item.setText(layer_name)
    #         list_item.setData(Qt.UserRole, (uri, provider))
    #         list_widget.addItem(list_item)

    #     button_box.rejected.connect(dlg.reject)
    #     button_box.accepted.connect(dlg.accept)

    #     if dlg.exec_():
    #         item = list_widget.currentItem()
    #         if item:
    #             uri, provider = item.data(Qt.UserRole)
    #             self.iface.addVectorLayer(uri, item.text(), provider)

    # def on_load_config(self):
    #     import os
    #     file_name = QFileDialog.getOpenFileName(None, "Choose a configuration file to load", os.path.dirname(__file__))
    #     if isinstance(file_name, tuple): #Qt5
    #         file_name = file_name[0]

    #     if file_name:
    #         s = QSettings("Oslandia", "qgeologis")
    #         s.setValue("config_file", file_name)
    #         get_layer_config()


    def update_layer_config(self):
        """Open and parse the configuration file"""

        config, _ = QgsProject.instance().readEntry("QGeoloGIS", "config", "{}")
        self.__config = json.loads(config)
        

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

from qgis.PyQt.QtCore import Qt, pyqtSignal, QSettings
from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtWidgets import QAction, QDockWidget, QFileDialog, QCheckBox, QDialog, QVBoxLayout

from qgis.core import (QgsPoint, QgsCoordinateTransform, QgsRectangle,
                       QgsGeometry, QgsFeatureRequest, QgsProject)
from qgis.gui import QgsMapTool

from .configure_plot_dialog import ConfigurePlotDialog
from .main_dialog import MainDialog
from .config import import_config, export_config, remove_layer_from_config

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

        self.update_layer_config()
        QgsProject.instance().readProject.connect(self.update_layer_config)
        QgsProject.instance().cleared.connect(self.update_layer_config)

        # current map tool
        self.__tool = None

        # Root widget, to attach children to
        self.__dock = None

    def initGui(self):

        icon = QIcon(os.path.join(os.path.dirname(__file__), "qgeologis/img/plot.svg"))
        self.view_logs = QAction(icon, u'View log plots', self.iface.mainWindow())
        self.view_logs.triggered.connect(lambda: self.on_view_plots("logs"))
        self.iface.addToolBarIcon(self.view_logs)
        
        icon = QIcon(os.path.join(os.path.dirname(__file__), "qgeologis/img/timeseries.svg"))
        self.view_timeseries = QAction(icon, u'View timeseries', self.iface.mainWindow())
        self.view_timeseries.triggered.connect(lambda: self.on_view_plots("timeseries"))
        self.iface.addToolBarIcon(self.view_timeseries)

        self.import_config_action = QAction("Import configuration", self.iface.mainWindow())
        self.export_config_action = QAction("Export configuration to ...", self.iface.mainWindow())
        self.import_config_action.triggered.connect(self.on_import_config)
        self.export_config_action.triggered.connect(self.on_export_config)
        self.iface.addPluginToMenu(u"QGeoloGIS", self.import_config_action)
        self.iface.addPluginToMenu(u"QGeoloGIS", self.export_config_action)

        QgsProject.instance().layerWillBeRemoved.connect(self.on_layer_removed)

    def on_layer_removed(self, layer_id):
        # Check if the layer is not part of the config,
        # in which case, it must be deleted from the config
        remove_layer_from_config(self.__config, layer_id)
        QgsProject.instance().writeEntry("QGeoloGIS", "config", json.dumps(self.__config))

    def on_view_plots(self, plot_type):

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

        self.__dock = QDockWidget("Well Log")
        dialog = MainDialog(self.__dock, plot_type, self.__config, layer, self.iface)
        self.__dock.setWidget(dialog)
        self.iface.addDockWidget(Qt.LeftDockWidgetArea, self.__dock)

    def unload(self):

        QgsProject.instance().layerWillBeRemoved.disconnect(self.on_layer_removed)

        QgsProject.instance().readProject.disconnect(self.update_layer_config)
        QgsProject.instance().cleared.disconnect(self.update_layer_config)

        self.__tool = None
        self.__config = None
        if self.__dock:
            self.iface.removeDockWidget(self.__dock)
            self.__dock.setParent(None)
        
        self.iface.removeToolBarIcon(self.view_logs)
        self.iface.removeToolBarIcon(self.view_timeseries)

        self.view_logs.setParent(None)
        self.view_timeseries.setParent(None)
        
        self.iface.removePluginMenu(u"QGeoloGIS", self.import_config_action)
        self.iface.removePluginMenu(u"QGeoloGIS", self.export_config_action)
        self.import_config_action.setParent(None)
        self.export_config_action.setParent(None)
        

    def on_import_config(self):
        s = QSettings("Oslandia", "QGeoloGIS")
        last_dir = s.value("config_last_dir", None)
        if not last_dir:
            last_dir = os.path.dirname(__file__)

        dlg = QDialog(None)
        file_dialog = QFileDialog(None,
                                  "Choose a configuration file to import",
                                  last_dir,
                                  "JSON files (*.json)",
                                  options=QFileDialog.DontUseNativeDialog # transform into an embeddable QWidget
        )
        # when file dialog is done, close the main dialog
        file_dialog.finished.connect(dlg.done)
        overwrite_checkbox = QCheckBox("Overwrite existing layers")
        overwrite_checkbox.setChecked(True)
        vbox = QVBoxLayout()
        vbox.addWidget(file_dialog)
        vbox.addWidget(overwrite_checkbox)
        dlg.setLayout(vbox)

        r = dlg.exec_()
        print(r)
        if r == QDialog.Accepted:
            filename = file_dialog.selectedFiles()[0]
            s.setValue("config_last_dir", os.path.dirname(filename))
            json_config = import_config(filename, overwrite_existing=overwrite_checkbox.isChecked())
            QgsProject.instance().writeEntry("QGeoloGIS", "config", json_config)
            self.__config = json_config

    def on_export_config(self):
        s = QSettings("Oslandia", "QGeoloGIS")
        last_dir = s.value("config_last_dir", None)
        if not last_dir:
            last_dir = os.path.dirname(__file__)

        filename, _ = QFileDialog.getSaveFileName(None,
                                                  "Export the configuration to ...",
                                                  last_dir,
                                                  "JSON files (*.json)")
        if filename:
            s.setValue("config_last_dir", os.path.dirname(filename))
            json_config = json.loads(self.__config)
            export_config(json_config, filename)


    def update_layer_config(self):
        """Open and parse the configuration file"""

        config, _ = QgsProject.instance().readEntry("QGeoloGIS", "config", "{}")
        self.__config = json.loads(config)
        

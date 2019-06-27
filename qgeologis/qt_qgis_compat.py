# -*- coding: utf-8 -*-
#
#   Copyright (C) 2018 Oslandia <infos@oslandia.com>
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

"""
Qt4 / Qt5 and QGIS 2/3 compatibility layer.

This file includes all classes from qgis.core and qgis.gui and monkey patch classes used in this project
in order to have a common API for QGIS 2 and QGIS 3 and Qt 4 / Qt 5.

The current strategy is to mimick as much as possible the Qt 4 / QGIS 2 API.
"""

import sys

from qgis.core import *
from qgis.gui import *

from qgis.PyQt.QtGui import QWheelEvent

if sys.version_info.major == 3:
    # ===========================
    #
    #           QGIS
    #
    # ===========================
    QgsFeatureRendererV2 = QgsFeatureRenderer

    QgsFeatureRendererV2._load = lambda doc: QgsFeatureRenderer.load(doc, QgsReadWriteContext())

    # restore QgsFeature.setFeatureId()
    QgsFeature.setFeatureId = lambda self, id: self.setId(id)

    def qgsApplication(args, b):
        return QgsApplication([bytes(x, "utf8") for x in args], b)

    # symbology
    QgsSimpleFillSymbolLayer.setBorderWidth = lambda self, w: self.setStrokeWidth(w)

    # geometry
    old_from_wkb = QgsGeometry.fromWkb
    def new_from_wkb(self, data):
        if data.__class__.__name__ == 'ndarray':
            return old_from_wkb(self, data.tobytes())
        return old_from_wkb(self, data)
    QgsGeometry.fromWkb = new_from_wkb

    QgsDataSourceURI = QgsDataSourceUri

    QgsMessageBar.CRITICAL = Qgis.Critical

    def qgsCoordinateTransform(src, tgt):
        return QgsCoordinateTransform(src, tgt, QgsProject.instance().transformContext())

    def qgsAddMapLayer(layer, addToLegend = True):
        QgsProject.instance().addMapLayers([layer], addToLegend)

    # ===========================
    #
    #           Qt
    #
    # ===========================
    QWheelEvent.delta = lambda self: self.angleDelta().y()
else:
    def qgsApplication(args, b):
        return QgsApplication(args, b)
    def qgsCoordinateTransform(src, tgt):
        return QgsCoordinateTransform(src, tgt)
    QgsFeatureRendererV2._load = QgsFeatureRendererV2.load

    def qgsAddMapLayer(layer, addToLegend = True):
        QgsMapLayerRegistry.instance().addMapLayers([layer], addToLegend)

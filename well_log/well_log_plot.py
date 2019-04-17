#!/usr/bin/env python
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

from qgis.PyQt.QtCore import Qt, QSizeF, QRectF, QPoint
from qgis.PyQt.QtGui import QBrush, QColor, QFontMetrics
from qgis.PyQt.QtWidgets import QGraphicsItem, QComboBox, QDialog, QVBoxLayout, QDialogButtonBox
from qgis.PyQt.QtWidgets import QStackedWidget, QToolTip
from .qt_qgis_compat import QgsFeatureRendererV2, QgsGeometry, QgsFields, QgsFeature, QgsRectangle

from .well_log_common import POINT_RENDERER, LINE_RENDERER, POLYGON_RENDERER
from .well_log_common import ORIENTATION_UPWARD, ORIENTATION_DOWNWARD, ORIENTATION_LEFT_TO_RIGHT, LogItem, qgis_render_context

from .well_log_time_scale import UTC

import numpy as np
import bisect
import math
from datetime import datetime

class PlotItem(LogItem):

    def __init__(self,
                 size=QSizeF(400,200),
                 render_type=POINT_RENDERER,
                 x_orientation=ORIENTATION_LEFT_TO_RIGHT,
                 y_orientation=ORIENTATION_UPWARD,
                 allow_mouse_translation=False,
                 allow_wheel_zoom=False,
                 parent=None):
        LogItem.__init__(self, parent)

        self.__item_size = size
        self.__data_rect = None
        self.__data = None
        self.__delta = None
        self.__x_orientation = x_orientation
        self.__y_orientation = y_orientation

        # origin point of the graph translation, if any
        self.__translation_orig = None

        self.__render_type = render_type

        self.__allow_mouse_translation = allow_mouse_translation
        self.__allow_wheel_zoom = allow_wheel_zoom

        self.__layer = None

        self.__renderers = [QgsFeatureRendererV2.defaultRenderer(POINT_RENDERER),
                            QgsFeatureRendererV2.defaultRenderer(LINE_RENDERER),
                            QgsFeatureRendererV2.defaultRenderer(POLYGON_RENDERER)]
        symbol = self.__renderers[1].symbol()
        symbol.setWidth(1.0)
        symbol = self.__renderers[0].symbol()
        symbol.setSize(5.0)
        symbol = self.__renderers[2].symbol()
        symbol.symbolLayers()[0].setBorderWidth(1.0)
        self.__renderer = self.__renderers[self.__render_type]

        # index of the current point to label
        self.__old_point_to_label = None
        self.__point_to_label = None

    def boundingRect(self):
        return QRectF(0, 0, self.__item_size.width(), self.__item_size.height())

    def height(self):
        return self.__item_size.height()
    def set_height(self, height):
        self.__item_size.setHeight(height)

    def width(self):
        return self.__item_size.width()
    def set_width(self, width):
        self.__item_size.setWidth(width)

    def set_data_window(self, window):
        """window: QRectF"""
        self.__data_rect = window

    def min_depth(self):
        if self.__data_rect is None:
            return None
        return self.__data_rect.x() * self.__delta
    def max_depth(self):
        if self.__data_rect is None:
            return None
        return (self.__data_rect.x() + self.__data_rect.width()) * self.__delta

    def set_min_depth(self, min_depth):
        if self.__data_rect is not None:
            self.__data_rect.setX(min_depth)
    def set_max_depth(self, max_depth):
        if self.__data_rect is not None:
            w = max_depth - self.__data_rect.x()
            self.__data_rect.setWidth(w)

    def layer(self):
        return self.__layer
    def set_layer(self, layer):
        self.__layer = layer

    def data_window(self):
        return self.__data_rect

    def set_data(self, x_values, y_values):
        self.__x_values = x_values
        self.__y_values = y_values

        if len(self.__x_values) != len(self.__y_values):
            raise ValueError("X and Y array has different length : "
                             "{} != {}".format(len(self.__x_values),
                                               len(self.__y_values)))

        # Remove None values
        for i in reversed(range(len(self.__y_values))):
            if (self.__y_values[i] is None
                or self.__x_values[i] is None
                or math.isnan(self.__y_values[i])
                or math.isnan(self.__x_values[i])):
                self.__y_values.pop(i)
                self.__x_values.pop(i)

        # Initialize data rect to display all data
        min_x = min(self.__x_values)
        max_x = max(self.__x_values)
        min_y = min(self.__y_values)
        max_y = max(self.__y_values)
        self.__data_rect = QRectF(
            min_x, min_y,
            max_x-min_x, max_y-min_y)

    def renderer(self):
        return self.__renderer

    def set_renderer(self, renderer):
        self.__renderer = renderer

    def render_type(self):
        return self.__render_type

    def set_render_type(self, type):
        self.__render_type = type
        self.__renderer = self.__renderers[self.__render_type]

    def paint(self, painter, option, widget):
        self.draw_background(painter)
        if self.__data_rect is None:
            return

        imin_x = bisect.bisect_left(self.__x_values, self.__data_rect.x())
        if imin_x > 0:
            imin_x -= 1
        imax_x = bisect.bisect_right(self.__x_values, self.__data_rect.right())
        if imax_x < len(self.__x_values) - 1:
            imax_x += 1
        x_values_slice = np.array(self.__x_values[imin_x:imax_x])
        y_values_slice = np.array(self.__y_values[imin_x:imax_x])

        if len(x_values_slice) == 0:
            return

        # filter points that are not None (nan in numpy arrays)
        n_points = len(x_values_slice)

        if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
            rw = float(self.__item_size.width()) / self.__data_rect.width()
            rh = float(self.__item_size.height()) / self.__data_rect.height()
            xx = (x_values_slice - self.__data_rect.x()) * rw
            yy = (y_values_slice - self.__data_rect.y()) * rh
        elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
            rw = float(self.__item_size.height()) / self.__data_rect.width()
            rh = float(self.__item_size.width()) / self.__data_rect.height()
            xx = (y_values_slice - self.__data_rect.y()) * rh
            yy = self.__item_size.height() - (x_values_slice - self.__data_rect.x()) * rw
        if self.__render_type == LINE_RENDERER:
            # WKB structure of a linestring
            #
            #   01 : endianness
            #   02 00 00 00 : WKB type (linestring)
            #   nn nn nn nn : number of points (int32)
            # Then, for each point:
            #   xx xx xx xx xx xx xx xx : X coordinate (float64)
            #   yy yy yy yy yy yy yy yy : Y coordinate (float64)

            wkb = np.zeros(8*2*n_points+9, dtype='uint8')
            wkb[0] = 1 # wkb endianness
            wkb[1] = 2 # linestring
            size_view = np.ndarray(buffer=wkb, dtype='int32', offset=5, shape=(1,))
            size_view[0] = n_points
            coords_view = np.ndarray(buffer=wkb, dtype='float64', offset=9, shape=(n_points,2))
            coords_view[:,0] = xx[:]
            coords_view[:,1] = yy[:]
        elif self.__render_type == POINT_RENDERER:
            # WKB structure of a multipoint
            # 
            #   01 : endianness
            #   04 00 00 00 : WKB type (multipoint)
            #   nn nn nn nn : number of points (int32)
            # Then, for each point:
            #   01 : endianness
            #   01 00 00 00 : WKB type (point)
            #   xx xx xx xx xx xx xx xx : X coordinate (float64)
            #   yy yy yy yy yy yy yy yy : Y coordinate (float64)

            wkb = np.zeros((8*2+5)*n_points+9, dtype='uint8')
            wkb[0] = 1 # wkb endianness
            wkb[1] = 4 # multipoint
            size_view = np.ndarray(buffer=wkb, dtype='int32', offset=5, shape=(1,))
            size_view[0] = n_points
            coords_view = np.ndarray(buffer=wkb, dtype='float64', offset=9+5, shape=(n_points,2), strides=(16+5,8))
            coords_view[:,0] = xx[:]
            coords_view[:,1] = yy[:]
            # header of each point
            h_view = np.ndarray(buffer=wkb, dtype='uint8', offset=9, shape=(n_points,2), strides=(16+5,1))
            h_view[:,0] = 1 # endianness
            h_view[:,1] = 1 # point
        elif self.__render_type == POLYGON_RENDERER:
            # WKB structure of a polygon
            # 
            #   01 : endianness
            #   03 00 00 00 : WKB type (polygon)
            #   01 00 00 00 : Number of rings (always 1 here)
            #   nn nn nn nn : number of points (int32)
            # Then, for each point:
            #   xx xx xx xx xx xx xx xx : X coordinate (float64)
            #   yy yy yy yy yy yy yy yy : Y coordinate (float64)
            #
            # We add two additional points to close the polygon

            wkb = np.zeros(8*2*(n_points+2)+9+4, dtype='uint8')
            wkb[0] = 1 # wkb endianness
            wkb[1] = 3 # polygon
            wkb[5] = 1 # number of rings
            size_view = np.ndarray(buffer=wkb, dtype='int32', offset=9, shape=(1,))
            size_view[0] = n_points+2
            coords_view = np.ndarray(buffer=wkb, dtype='float64', offset=9+4, shape=(n_points,2))
            coords_view[:,0] = xx[:]
            coords_view[:,1] = yy[:]
            # two extra points
            extra_coords = np.ndarray(buffer=wkb, dtype='float64', offset=8*2*n_points+9+4, shape=(2,2))
            if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
                extra_coords[0,0] = coords_view[-1,0]
                extra_coords[0,1] = 0.0
                extra_coords[1,0] = coords_view[0,0]
                extra_coords[1,1] = 0.0
            elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
                extra_coords[0,0] = 0.0
                extra_coords[0,1] = coords_view[-1,1]
                extra_coords[1,0] = 0.0
                extra_coords[1,1] = coords_view[0,1]

        # build a geometry from the WKB
        # since numpy arrays have buffer protocol, sip is able to read it
        geom = QgsGeometry()
        geom.fromWkb(wkb)

        painter.setClipRect(0, 0, self.__item_size.width(), self.__item_size.height())

        fields = QgsFields()
        #fields.append(QgsField("", QVariant.String))
        feature = QgsFeature(fields, 1)
        feature.setGeometry(geom)

        context = qgis_render_context(painter, self.__item_size.width(), self.__item_size.height())
        context.setExtent(QgsRectangle(0, 1, self.__item_size.width(), self.__item_size.height()))

        self.__renderer.startRender(context, fields)
        self.__renderer.renderFeature(feature, context)
        self.__renderer.stopRender(context)

        if self.__point_to_label is not None:
            i = self.__point_to_label
            x, y = self.__x_values[i], self.__y_values[i]
            if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
                px = (x - self.__data_rect.x()) * rw
                py = self.__item_size.height() - (y - self.__data_rect.y()) * rh
            elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
                px = (y - self.__data_rect.y()) * rh
                py = (x - self.__data_rect.x()) * rw
            painter.drawLine(px-5, py, px+5, py)
            painter.drawLine(px, py-5, px, py+5)

    def mouseMoveEvent(self, event):
        if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
            xx = (event.scenePos().x() - self.pos().x()) / self.width() * self.__data_rect.width() + self.__data_rect.x()
        elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
            xx = (event.scenePos().y() - self.pos().y()) / self.height() * self.__data_rect.width() + self.__data_rect.x()
        i = bisect.bisect_left(self.__x_values, xx)
        if i >= 0 and i < len(self.__x_values):
            # switch the attached point when we are between two points
            if i > 0 and (xx - self.__x_values[i-1]) < (self.__x_values[i] - xx):
                i -= 1
            self.__point_to_label = i
        else:
            self.__point_to_label = None
        if self.__point_to_label != self.__old_point_to_label:
            self.update()
        if self.__point_to_label is not None:
            x, y = self.__x_values[i], self.__y_values[i]
            if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
                dt = datetime.fromtimestamp(x, UTC())
                txt = "Time: {} Value: {}".format(unicode(dt.strftime("%x %X"), "utf8"),y)
            elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
                txt = "Depth: {} Value: {}".format(x,y)
            self.tooltipRequested.emit(txt)

        self.__old_point_to_label = self.__point_to_label

    def edit_style(self):
        from qgis.gui import QgsSingleSymbolRendererV2Widget
        from qgis.core import QgsStyleV2

        style = QgsStyleV2()
        sw = QStackedWidget()
        sw.addWidget
        for i in range(3):
            w = QgsSingleSymbolRendererV2Widget(self.__layer, style, self.__renderers[i])
            sw.addWidget(w)
        
        combo = QComboBox()
        combo.addItem("Points")
        combo.addItem("Line")
        combo.addItem("Polygon")

        combo.currentIndexChanged[int].connect(sw.setCurrentIndex)
        combo.setCurrentIndex(self.__render_type)
        
        dlg = QDialog()

        vbox = QVBoxLayout()

        btn = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        btn.accepted.connect(dlg.accept)
        btn.rejected.connect(dlg.reject)

        vbox.addWidget(combo)
        vbox.addWidget(sw)
        vbox.addWidget(btn)

        dlg.setLayout(vbox)
        dlg.resize(800, 600)

        r = dlg.exec_()
        if r == QDialog.Accepted:
            self.set_render_type(combo.currentIndex())
            self.set_renderer(sw.currentWidget().renderer().clone())
            self.update()

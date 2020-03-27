#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
#   Copyright (C) 2020 Oslandia <infos@oslandia.com>
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

from PyQt5.QtCore import (
    pyqtSignal,
    QSizeF,
    QRectF
)
from PyQt5.QtGui import (
    QPolygonF
)
from PyQt5.QtWidgets import (
    QStackedWidget,
    QComboBox,
    QDialog,
    QVBoxLayout,
    QDialogButtonBox
)

from qgis.core import (
    QgsFeatureRenderer,
    QgsReadWriteContext,
    QgsFeatureRequest,
    QgsRectangle,
    QgsGeometry,
    QgsPointXY,
    QgsFeature
)

from .common import LINE_RENDERER, POLYGON_RENDERER, qgis_render_context
from .common import ORIENTATION_UPWARD, ORIENTATION_DOWNWARD, ORIENTATION_LEFT_TO_RIGHT, LogItem

from .time_scale import UTC

import bisect
from datetime import datetime

class IntervalPlotItem(LogItem):
    """Plot data that have a value on an interval (x_min, x_max). See IntervalData"""

    # emitted when the style is updated
    style_updated = pyqtSignal()

    def __init__(self,
                 layer,
                 column_mapping,
                 filter_expression=None,
                 size=QSizeF(400, 200),
                 render_type=POLYGON_RENDERER,
                 x_orientation=ORIENTATION_LEFT_TO_RIGHT,
                 y_orientation=ORIENTATION_UPWARD,
                 symbology=None,
                 parent=None):

        """
        Parameters
        ----------
        layer: QgsVectorLayer
          Input vector layer
        column_mapping: dict
          Layer column mapping with the following keys:
          - min_event_column : name of the column which holds the minimum x value
          - max_event_column : name of the column which holds the maximum x value
          - value_column : name of the column which holds the value
        filter_expression: str
          Filter expression to apply to the input layer
        size: QSize
          Size of the item
        render_type: Literal[LINE_RENDERER, POLYGON_RENDERER]
          Type of renderer
        x_orientation: Literal[ORIENTATION_LEFT_TO_RIGHT, ORIENTATION_RIGHT_TO_LEFT]
        y_orientation: Literal[ORIENTATION_UPWARD, ORIENTATION_DOWNWARD]
        symbology: QDomDocument
          QGIS symbology to use for the renderer
        parent: QObject
        """
        LogItem.__init__(self, parent)

        self.__item_size = size
        self.__data_rect = None
        self.__data = None
        self.__x_orientation = x_orientation
        self.__y_orientation = y_orientation

        if render_type not in (LINE_RENDERER, POLYGON_RENDERER):
            raise RuntimeError(
                "Render type not supported: {}".format(render_type)
            )
        self.__render_type = render_type # type: Literal[POINT_RENDERER, LINE_RENDERER, POLYGON_RENDERER]

        self.__layer = layer
        self.__column_mapping = column_mapping
        self.__filter_expression = filter_expression

        self.__default_renderers = [
            None,
            QgsFeatureRenderer.defaultRenderer(LINE_RENDERER),
            QgsFeatureRenderer.defaultRenderer(POLYGON_RENDERER)
        ]
        symbol = self.__default_renderers[1].symbol()
        symbol.setWidth(1.0)
        symbol = self.__default_renderers[2].symbol()
        symbol.symbolLayers()[0].setStrokeWidth(1.0)

        if not symbology:
            self.__renderer = self.__default_renderers[self.__render_type]
        else:
            self.__renderer = QgsFeatureRenderer.load(symbology.documentElement(), QgsReadWriteContext())

        # values cache
        self.__min_x_values = []
        self.__max_x_values = []
        self.__y_values = []
        # index of the current point to label
        self.__old_point_to_label = None
        self.__point_to_label = None

        # determine data window on loading
        # FIXME we should use the database when possible
        self.__min_x_field = column_mapping["min_event_column"]
        self.__max_x_field = column_mapping["max_event_column"]
        self.__y_field = column_mapping["value_column"]

        req = QgsFeatureRequest()
        req.setFilterExpression(filter_expression)
        req.setSubsetOfAttributes(
            [
                self.__min_x_field,
                self.__max_x_field,
                self.__y_field
            ],
            layer.fields()
        )
        min_x, max_x = None, None
        min_y, max_y = None, None
        for f in layer.getFeatures(req):
            if min_x is None or f[self.__min_x_field] < min_x:
                min_x = f[self.__min_x_field]
            if max_x is None or f[self.__max_x_field] > max_x:
                max_x = f[self.__max_x_field]
            if min_y is None or f[self.__y_field] < min_y:
                min_y = f[self.__y_field]
            if max_y is None or f[self.__y_field] > max_y:
                max_y = f[self.__y_field]

        if min_x is None:
            return

        # Add a 10% buffer above max
        h = max_y - min_y
        if h < 0.1:
            max_y = min_y + 1.0
            h = 1.0
        max_y += h * 0.1

        self.set_data_window(
            QRectF(
                min_x, min_y,
                max_x-min_x, max_y-min_y
            )
        )

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
        self._invalidate_cache()

    def _invalidate_cache(self):
        # invalidate cache
        self.__min_x_values = []
        self.__max_x_values = []
        self.__y_values = []

    def min_depth(self):
        if self.__data_rect is None:
            return None
        return self.__data_rect.x()
    def max_depth(self):
        if self.__data_rect is None:
            return None
        return (self.__data_rect.x() + self.__data_rect.width())

    def set_min_depth(self, min_depth):
        if self.__data_rect is not None:
            self.__data_rect.setX(min_depth)
            self._invalidate_cache()
    def set_max_depth(self, max_depth):
        if self.__data_rect is not None:
            w = max_depth - self.__data_rect.x()
            self.__data_rect.setWidth(w)
            self._invalidate_cache()

    def layer(self):
        return self.__layer
    def set_layer(self, layer):
        self.__layer = layer

    def data_window(self):
        return self.__data_rect

    def renderer(self):
        return self.__renderer

    def _populate_cache(self):
        req = QgsFeatureRequest()
        filter = self.__filter_expression or ""
        if filter:
            filter += " and "
        filter += "{} >= {} and {} <= {}".format(
            self.__min_x_field, self.__data_rect.x(),
            self.__max_x_field, self.__data_rect.right()
        )
        req.setFilterExpression(filter)
        req.setSubsetOfAttributes(
            [
                self.__min_x_field,
                self.__max_x_field,
                self.__y_field
            ],
            self.__layer.fields()
        )
        req.addOrderBy(self.__min_x_field)

        # reset cache for picking
        self.__min_x_values = []
        self.__max_x_values = []
        self.__y_values = []

        for f in self.__layer.getFeatures(req):
            self.__min_x_values.append(f[self.__min_x_field])
            self.__max_x_values.append(f[self.__max_x_field])
            self.__y_values.append(f[self.__y_field])

    def paint(self, painter, option, widget):
        self.draw_background(painter)
        if self.__data_rect is None:
            return

        context = qgis_render_context(painter, self.width(), self.height())
        context.setExtent(QgsRectangle(0, 0, self.width(), self.height()))
        fields = self.__layer.fields()

        context.expressionContext().setFields(fields)

        self.__renderer.startRender(context, fields)

        if not self.__y_values:
            self._populate_cache()

        if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
            rw = self.width() / self.__data_rect.width()
            rh = self.height() / self.__data_rect.height()
        elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
            rw = self.height() / self.__data_rect.width()
            rh = self.width() / self.__data_rect.height()

        for i in range(len(self.__y_values)):
            f = QgsFeature(self.__layer.fields())
            min_x, max_x = self.__min_x_values[i], self.__max_x_values[i]
            value = self.__y_values[i]
            min_xx = (min_x - self.__data_rect.left()) * rw
            max_xx = (max_x - self.__data_rect.left()) * rw
            yy = (value - self.__data_rect.top()) * rh

            if self.__render_type == POLYGON_RENDERER:
                if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
                    geom = QgsGeometry.fromQPolygonF(
                        QPolygonF(
                            QRectF(
                                min_xx,
                                0,
                                max_xx - min_xx,
                                yy
                            )
                        )
                    )
                elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
                    geom = QgsGeometry.fromQPolygonF(
                        QPolygonF(
                            QRectF(
                                0,
                                self.height() - max_xx,
                                yy,
                                max_xx - min_xx
                            )
                        )
                    )
                    
            elif self.__render_type == LINE_RENDERER:
                if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
                    geom = QgsGeometry.fromPolylineXY(
                        [
                            QgsPointXY(min_xx, yy),
                            QgsPointXY(max_xx, yy)
                        ]
                    )
                elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
                    geom = QgsGeometry.fromPolylineXY(
                        [
                            QgsPointXY(yy, min_xx),
                            QgsPointXY(yy, max_xx)
                        ]
                    )
            f.setGeometry(geom)

            self.__renderer.renderFeature(f, context)

        if self.__point_to_label is not None:
            i = self.__point_to_label
            if i >= len(self.__min_x_values):
                return
            x1, x2, y = self.__min_x_values[i], self.__max_x_values[i], self.__y_values[i]
            if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
                px1 = (x1 - self.__data_rect.x()) * rw
                px2 = (x2 - self.__data_rect.x()) * rw
                px = (px1 + px2) / 2.0
                py = self.height() - (y - self.__data_rect.y()) * rh
            elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
                py1 = (x1 - self.__data_rect.x()) * rw
                py2 = (x2 - self.__data_rect.x()) * rw
                py = (py1 + py2) / 2.0
                px = (y - self.__data_rect.y()) * rh
            painter.drawLine(px-5, py-5, px+5, py+5)
            painter.drawLine(px-5, py+5, px+5, py-5)

                    
        self.__renderer.stopRender(context)

    def mouseMoveEvent(self, event):
        if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
            xx = (event.scenePos().x() - self.pos().x()) / self.width() * self.__data_rect.width() + self.__data_rect.x()
        elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
            xx = (event.scenePos().y() - self.pos().y()) / self.height() * self.__data_rect.width() + self.__data_rect.x()

        i = bisect.bisect_left(self.__min_x_values, xx) - 1
        if i >= 0 and i < len(self.__min_x_values) and xx <= self.__max_x_values[i]:
            self.__point_to_label = i
        else:
            self.__point_to_label = None
        if self.__point_to_label != self.__old_point_to_label:
            self.update()
        if self.__point_to_label is not None:
            x1, x2, y = self.__min_x_values[i], self.__max_x_values[i], self.__y_values[i]
            if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
                dt1 = datetime.fromtimestamp(x1, UTC())
                dt2 = datetime.fromtimestamp(x2, UTC())
                txt = "Time: {} - {} Value: {:.2f}".format(
                    dt1.strftime("%x %X"),
                    dt2.strftime("%x %X"),
                    y
                )
            elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
                txt = "Depth: {} - {} Value: {:.2f}".format(x1, x2, y)
            self.tooltipRequested.emit(txt)

        self.__old_point_to_label = self.__point_to_label

    def edit_style(self):
        from qgis.gui import QgsSingleSymbolRendererWidget
        from qgis.core import QgsStyle

        style = QgsStyle()
        sw = QStackedWidget()

        if self.__renderer and self.__render_type == LINE_RENDERER:
            w = QgsSingleSymbolRendererWidget(self.__layer, style, self.__renderer)
        else:
            w = QgsSingleSymbolRendererWidget(self.__layer, style, self.__default_renderers[LINE_RENDERER])
        sw.addWidget(w)
        if self.__renderer and self.__render_type == POLYGON_RENDERER:
            w = QgsSingleSymbolRendererWidget(self.__layer, style, self.__renderer)
        else:
            w = QgsSingleSymbolRendererWidget(self.__layer, style, self.__default_renderers[POLYGON_RENDERER])
        sw.addWidget(w)

        combo = QComboBox()
        combo.addItem("Line")
        combo.addItem("Polygon")

        combo.currentIndexChanged[int].connect(sw.setCurrentIndex)
        combo.setCurrentIndex(self.__render_type - 1)

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
            self.__render_type = combo.currentIndex() + 1
            self.__renderer = sw.currentWidget().renderer().clone()
            self.update()
            self.style_updated.emit()

    def qgis_style(self):
        """Returns the current style, as a QDomDocument"""
        from PyQt5.QtXml import QDomDocument
        from qgis.core import QgsReadWriteContext

        doc = QDomDocument()
        elt = self.__renderer.save(doc, QgsReadWriteContext())
        doc.appendChild(elt)
        return (doc, self.__render_type)

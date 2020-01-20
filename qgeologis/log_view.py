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

from qgis.PyQt.QtCore import Qt, QSizeF
from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtWidgets import (QGraphicsView, QGraphicsScene, QWidget, QToolBar, QAction, QLabel,
                                 QVBoxLayout)
from qgis.PyQt.QtWidgets import QStatusBar

from qgis.core import QgsFeatureRequest

from .common import POLYGON_RENDERER, ORIENTATION_DOWNWARD, ORIENTATION_LEFT_TO_RIGHT

from .log_plot import PlotItem
from .z_scale import ZScaleItem
from .stratigraphy import StratigraphyItem
from .legend_item import LegendItem
from .imagery_data import ImageryDataItem

import os


class LogGraphicsView(QGraphicsView):
    def __init__(self, scene, parent=None):
        QGraphicsView.__init__(self, scene, parent)

        self.__allow_mouse_translation = True
        self.__translation_orig = None
        self.__translation_min_z = None
        self.__translation_max_z = None
        self.__max_width = 500

        self.setMouseTracking(True)

    def resizeEvent(self, event):
        QGraphicsView.resizeEvent(self, event)
        # by default, the rect is centered on 0,0,
        # we prefer to have 0,0 in the upper left corner
        rect = self.scene().sceneRect()
        rect.setHeight(event.size().height())
        self.scene().setSceneRect(rect)

    def wheelEvent(self, event):
        print(self.source())
        delta = -event.angleDelta().y() / 100.0
        if delta > 0:
            dt = delta
        else:
            dt = 1.0/(-delta)

        min_z = self.parentWidget()._min_z
        max_z = self.parentWidget()._max_z
        h = max_z - min_z
        nh = h * dt
        dy = event.y() / self.scene().sceneRect().height() * (h - nh)
        self.parentWidget()._min_z += dy
        self.parentWidget()._max_z = self.parentWidget()._min_z + nh
        self.parentWidget()._update_column_depths()

    def mouseMoveEvent(self, event):
        if not self.__allow_mouse_translation:
            return QGraphicsView.mouseMoveEvent(self, event)

        if self.__translation_orig is not None:
            delta = self.__translation_orig - event.pos()
            delta_y = delta.y() / self.scene().sceneRect().height() * (self.parentWidget()._max_z - self.parentWidget()._min_z)
            min_z = self.__translation_min_z + delta_y
            self.parentWidget()._min_z = min_z
            self.parentWidget()._max_z = self.__translation_max_z + delta_y
            self.parentWidget()._update_column_depths()
        return QGraphicsView.mouseMoveEvent(self, event)

    def mousePressEvent(self, event):
        self.__translation_orig = None
        if event.buttons() == Qt.LeftButton:
            self.__translation_orig = event.pos()
            self.__translation_min_z = self.parentWidget()._min_z
            self.__translation_max_z = self.parentWidget()._max_z
        return QGraphicsView.mousePressEvent(self, event)

    def mouseReleaseEvent(self, event):
        if event.pos() == self.__translation_orig:
            self.parentWidget().select_column_at(event.pos())
        self.__translation_orig = None

        return QGraphicsView.mouseReleaseEvent(self, event)

class MyScene(QGraphicsScene):
    def __init__(self, x, y, w, h):
        QGraphicsScene.__init__(self, x, y, w, h)

    def mouseMoveEvent(self, event):
        # pass the event to the underlying item
        for item in list(self.items()):
            r = item.boundingRect()
            r.translate(item.pos())
            if r.contains(event.scenePos()):
                return item.mouseMoveEvent(event)
        return QGraphicsScene.mouseMoveEvent(self, event)

class WellLogView(QWidget):

    DEFAULT_COLUMN_WIDTH = 150

    def __init__(self, title=None,image_dir=None, parent=None):
        QWidget.__init__(self, parent)

        self.toolbar = QToolBar()
        self.__log_scene = MyScene(0, 0, 600, 600)
        self.__log_view = LogGraphicsView(self.__log_scene)
        self.__log_view.setAlignment(Qt.AlignLeft|Qt.AlignTop)

        self.__log_scene.sceneRectChanged.connect(self.on_rect_changed)

        if image_dir is None:
            image_dir = os.path.join(os.path.dirname(__file__), "img")

        self.__action_move_column_left = QAction(QIcon(os.path.join(image_dir, "left.svg")), "Move the column to the left", self.toolbar)
        self.__action_move_column_left.triggered.connect(self.on_move_column_left)
        self.__action_move_column_right = QAction(QIcon(os.path.join(image_dir, "right.svg")), "Move the column to the right", self.toolbar)
        self.__action_move_column_right.triggered.connect(self.on_move_column_right)

        self.__action_edit_style = QAction(QIcon(os.path.join(image_dir, "symbology.svg")), "Edit column style", self.toolbar)
        self.__action_edit_style.triggered.connect(self.on_edit_style)

        self.__action_add_column = QAction(QIcon(os.path.join(image_dir, "add.svg")), "Add a data column from configured ones", self.toolbar)
        self.__action_add_column.triggered.connect(self.on_add_column)

        self.__action_remove_column = QAction(QIcon(os.path.join(image_dir, "remove.svg")), "Remove the column", self.toolbar)
        self.__action_remove_column.triggered.connect(self.on_remove_column)

        #self.__action_move_content_right = QAction("Move content right", self.toolbar)
        #self.__action_move_content_left = QAction("Move content left", self.toolbar)
        #self.__action_move_content_left.triggered.connect(self.on_move_content_left)
        #self.__action_move_content_right.triggered.connect(self.on_move_content_right)

        self.toolbar.addAction(self.__action_move_column_left)
        self.toolbar.addAction(self.__action_move_column_right)
        self.toolbar.addAction(self.__action_edit_style)
        self.toolbar.addAction(self.__action_add_column)
        self.toolbar.addAction(self.__action_remove_column)

        #self.__toolbar.addAction(self.__action_move_content_left)
        #self.__toolbar.addAction(self.__action_move_content_right)

        self.__title_label = QLabel()
        if title is not None:
            self.set_title(title)

        self.__status_bar = QStatusBar()

        vbox = QVBoxLayout()
        vbox.addWidget(self.__title_label)
        vbox.addWidget(self.toolbar)
        vbox.addWidget(self.__log_view)
        vbox.addWidget(self.__status_bar)
        self.setLayout(vbox)

        self.__station_id = None
        # (log_item, legend_item) for each column
        self.__columns = []
        # { layer : (log_item, legend_item) }
        self.__data2logitems = {}
        self.__column_widths = []

        self._min_z = 0
        self._max_z = 40

        self.__allow_mouse_translation = True
        self.__translation_orig = None

        self.__style_dir = os.path.join(os.path.dirname(__file__),
                                        'styles')

        self.select_column(-1)

        # by default we have a Z scale
        self.add_z_scale()
        
    def on_rect_changed(self, rect):
        for item, _ in self.__columns:
            item.set_height(rect.height())

    def set_title(self, title):
        self.__title_label.setText(title)

    def _place_items(self):
        x = 0
        for i, c in enumerate(self.__columns):
            item, legend = c
            width = self.__column_widths[i]
            legend.setPos(x, 0)
            item.setPos(x, legend.boundingRect().height())
            x += width

        rect = self.__log_scene.sceneRect()
        rect.setWidth(x)
        self.__log_scene.setSceneRect(rect)

    def _add_column(self, log_item, legend_item):
        self.__log_scene.addItem(log_item)
        self.__log_scene.addItem(legend_item)

        log_item.set_min_depth(self._min_z)
        log_item.set_max_depth(self._max_z)
        self.__columns.append((log_item, legend_item))
        self.__column_widths.append(log_item.boundingRect().width())

        self._place_items()

    def _fit_to_max_depth(self):
        self._min_z = min([i.min_depth() for i, _ in self.__columns if i.min_depth() is not None])
        self._max_z = max([i.max_depth() for i, _ in self.__columns if i.max_depth() is not None])
        # if we have only one value, center it on a 2 meters range
        if self._min_z == self._max_z:
            self._min_z -= 1.0
            self._max_z += 1.0

    def _update_column_depths(self):
        for item, _ in self.__columns:
            item.set_min_depth(self._min_z)
            item.set_max_depth(self._max_z)
            item.update()

    def add_z_scale(self, title="Depth"):
        scale_item = ZScaleItem(self.DEFAULT_COLUMN_WIDTH / 2, self.__log_scene.height(), self._min_z, self._max_z)
        legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH / 2, title, unit_of_measure="m")
        self._add_column(scale_item, legend_item)

    def remove_data_column(self, data):
        """Remove data column from widget

        :param data: data to be removed
        """

        # Column doesn't exist
        if data not in self.__data2logitems:
            raise ValueError("Impossible to remove data column : given data"
                             " object doesn't exist")

        log_item, legend_item = self.__data2logitems[data]
        for i, (pitem, litem) in enumerate(self.__columns):
            if pitem == log_item and litem == legend_item:
                self.__columns.pop(i)
                self.__column_widths.pop(i)
                del self.__data2logitems[data]
                self.__log_scene.removeItem(log_item)
                self.__log_scene.removeItem(legend_item)
                return

        # Columns not found
        assert False

    def clear_data_columns(self):
        # remove item from scenes
        for (item, legend) in self.__columns:
            self.__log_scene.removeItem(legend)
            self.__log_scene.removeItem(item)

        # remove from internal lists
        self.__columns = []
        self.__column_widths = []
        self.__data2logitems = {}
        
        self.__selected_column = -1
        self._place_items()
        self._update_button_visibility()

        # still add z scale
        self.add_z_scale()

    def on_plot_tooltip(self, txt, station_name = None):
        if station_name is not None:
            self.__status_bar.showMessage(u"Station: {} ".format(station_name) + txt)
        else:
            self.__status_bar.showMessage(txt)

    def add_data_column(self, data, title, uom, station_name = None):
        plot_item = PlotItem(size=QSizeF(self.DEFAULT_COLUMN_WIDTH, self.__log_scene.height()),
                             render_type = POLYGON_RENDERER,
                             x_orientation = ORIENTATION_DOWNWARD,
                             y_orientation = ORIENTATION_LEFT_TO_RIGHT)

        plot_item.set_layer(data.get_layer())
        plot_item.tooltipRequested.connect(lambda txt: self.on_plot_tooltip(txt, station_name))

        legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH, title, unit_of_measure=uom)
        data.data_modified.connect(lambda data=data : self._update_data_column(data))

        self.__data2logitems[data] = (plot_item, legend_item)
        self._add_column(plot_item, legend_item)
        self._update_data_column(data)
        self._update_column_depths()

    def _update_data_column(self, data):

        plot_item, legend_item = self.__data2logitems[data]

        y_values = data.get_y_values()
        x_values = data.get_x_values()
        if y_values is None or x_values is None:
            plot_item.set_data_window(None)
            return

        plot_item.set_data(data.get_x_values(), data.get_y_values())

#        r = QRectF(0, min_y, (max_x-min_x)/delta, max_y)
#        plot_item.set_data_window(r)

        # legend
        min_str = "{:.1f}".format(min(data.get_y_values()) if data.get_y_values() else 0)
        max_str = "{:.1f}".format(max(data.get_y_values()) if data.get_y_values() else 0)
        legend_item.set_scale(min_str, max_str)

        self.__log_scene.update()

    def add_stratigraphy(self, layer, filter_expression, column_mapping, title, style_file):
        item = StratigraphyItem(self.DEFAULT_COLUMN_WIDTH,
                                self.__log_scene.height(),
                                style_file=style_file)
        legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH, title)

        item.set_layer(layer)
        item.tooltipRequested.connect(self.on_plot_tooltip)

        req = QgsFeatureRequest()
        req.setFilterExpression(filter_expression)
        item.set_data([[f[c] if c is not None else None for c in column_mapping]
                       for f in layer.getFeatures(req)])

        self._add_column(item, legend_item)

    def add_imagery(self, image_filename, title, depth_from, depth_to):
        item = ImageryDataItem(self.DEFAULT_COLUMN_WIDTH,
                               self.__log_scene.height(),
                               image_filename,
                               depth_from,
                               depth_to)
        
        legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH, title)

        self._add_column(item, legend_item)

    def select_column_at(self, pos):
        x = pos.x()
        c = 0
        selected = -1
        for i, width in enumerate(self.__column_widths):
            if x >= c and x < c + width:
                selected = i
                break
            c += width
        self.select_column(selected)

    def select_column(self, idx):
        self.__selected_column = idx
        for i, p in enumerate(self.__columns):
            item, legend = p
            item.set_selected(idx == i)
            legend.set_selected(idx == i)
            item.update()
            legend.update()

        self._update_button_visibility()

    def selected_column(self):
        return self.__selected_column

    def _update_button_visibility(self):
        idx = self.__selected_column
        self.__action_move_column_left.setEnabled(idx != -1 and idx > 0)
        self.__action_move_column_right.setEnabled(idx != -1 and idx < len(self.__columns) - 1)

        item = self.__columns[idx][0] if idx > 0 else None
        self.__action_edit_style.setEnabled(bool(item and not isinstance(item, ImageryDataItem)))
        self.__action_remove_column.setEnabled(idx != -1)

    def on_move_column_left(self):
        if self.__selected_column < 1:
            return

        sel = self.__selected_column
        self.__columns[sel-1], self.__columns[sel] = self.__columns[sel], self.__columns[sel-1]
        self.__column_widths[sel-1], self.__column_widths[sel] = self.__column_widths[sel], self.__column_widths[sel-1]
        self.__selected_column -= 1
        self._place_items()
        self._update_button_visibility()

    def on_move_column_right(self):
        if self.__selected_column == -1 or self.__selected_column >= len(self.__columns) - 1:
            return

        sel = self.__selected_column
        self.__columns[sel+1], self.__columns[sel] = self.__columns[sel], self.__columns[sel+1]
        self.__column_widths[sel+1], self.__column_widths[sel] = self.__column_widths[sel], self.__column_widths[sel+1]
        self.__selected_column += 1
        self._place_items()
        self._update_button_visibility()

    def on_remove_column(self):
        if self.__selected_column == -1:
            return

        sel = self.__selected_column

        # remove item from scenes
        item, legend = self.__columns[sel]
        self.__log_scene.removeItem(legend)
        self.__log_scene.removeItem(item)

        # remove from internal list
        del self.__columns[sel]
        del self.__column_widths[sel]
        self.__selected_column = -1
        self._place_items()
        self._update_button_visibility()

    def on_edit_style(self):
        if self.__selected_column == -1:
            return

        item = self.__columns[self.__selected_column][0]
        item.edit_style()

    def on_add_column(self):
        # to be overridden by subclasses
        pass

# QGIS_PREFIX_PATH=~/src/qgis_2_18/build/output PYTHONPATH=~/src/qgis_2_18/build/output/python/ python test_canvas.py
if __name__=='__main__':

    import sys
    import random

    from qgis.core import QgsApplication, QgsVectorLayer, QgsFeature
    from data_interface import LayerData, FeatureData

    app = QgsApplication([bytes(x, "utf8") for x in sys.argv], True)
    app.initQgis()

    # layer example
    layer = QgsVectorLayer("None?field=x:double&field=y:double", "test_layer",
                           "memory")
    y_values = [random.uniform(1., 100.) for i in range(1000)]
    features = []
    for i, y in enumerate(y_values):
        feature = QgsFeature()
        feature.setAttributes([float(i), y])
        features.append(feature)

    layer.dataProvider().addFeatures(features)

    w = WellLogView("Sample")
    w.add_data_column(LayerData(layer, "x", "y"), "test title", "m")

    # feature example
    layer = QgsVectorLayer("None?field=y:double", "test_feature",
                           "memory")
    feature = QgsFeature()
    y_values = ",".join([str(random.uniform(1., 100.)) for i in range(1000)])
    feature.setAttributes([y_values])
    feature.setFeatureId(1)
    layer.dataProvider().addFeatures([feature])
    x_values = [float(x) for x in range(1, 1001)]
    w.add_data_column(FeatureData(layer, "y", x_values, 1), "test title", "m")

    #w.add_imagery("/home/hme/src/1805_03_ceadam_visu_geol/data/VALDUC/DIAGRAPHIE/B8/DIAGRAPHIE_DIFFEREE/OBI/20161201/OBI.optimized.tiff", "Image", 5.0, 48.0)
    
    w.show()

    app.exec_()

    app.exitQgis()

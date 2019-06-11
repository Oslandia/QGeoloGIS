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

from qgis.PyQt.QtCore import Qt, QRectF, QSizeF
from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtWidgets import QGraphicsView, QGraphicsScene, QWidget, QToolBar, QAction, QLabel, QVBoxLayout
from qgis.PyQt.QtWidgets import QStatusBar

from .common import LINE_RENDERER, ORIENTATION_UPWARD, ORIENTATION_LEFT_TO_RIGHT
from .log_plot import PlotItem
from .time_scale import TimeScaleItem
from .legend_item import LegendItem

import os

class TimeSeriesGraphicsView(QGraphicsView):
    def __init__(self, scene, parent=None):
        QGraphicsView.__init__(self, scene, parent)

        self.__allow_mouse_translation = True
        self.__translation_orig = None
        self.__translation_min_x = None
        self.__translation_max_x = None

        self.setMouseTracking(True)

    def resizeEvent(self, event):
        QGraphicsView.resizeEvent(self, event)
        # by default, the rect is centered on 0,0,
        # we prefer to have 0,0 in the upper left corner
        self.scene().setSceneRect(QRectF(0, 0, event.size().width(), event.size().height()))

    def wheelEvent(self, event):
        delta = -event.delta() / 100.0
        if delta > 0:
            dt = delta
        else:
            dt = 1.0/(-delta)

        min_x = self.parentWidget()._min_x
        max_x = self.parentWidget()._max_x
        w = max_x - min_x
        nw = w * dt
        dx = event.x() / self.scene().sceneRect().width() * (w - nw)
        self.parentWidget()._min_x += dx
        self.parentWidget()._max_x = self.parentWidget()._min_x + nw
        self.parentWidget()._update_row_depths()

    def mouseMoveEvent(self, event):
        if not self.__allow_mouse_translation:
            return QGraphicsView.mouseMoveEvent(self, event)

        if self.__translation_orig is not None:
            delta = self.__translation_orig - event.pos()
            delta_x = delta.x() / self.scene().sceneRect().width() * (self.parentWidget()._max_x - self.parentWidget()._min_x)
            self.parentWidget()._min_x = self.__translation_min_x + delta_x
            self.parentWidget()._max_x = self.__translation_max_x + delta_x
            self.parentWidget()._update_row_depths()
        return QGraphicsView.mouseMoveEvent(self, event)

    def mousePressEvent(self, event):
        self.__translation_orig = None
        if event.buttons() == Qt.LeftButton:
            self.__translation_orig = event.pos()
            self.__translation_min_x = self.parentWidget()._min_x
            self.__translation_max_x = self.parentWidget()._max_x
        return QGraphicsView.mousePressEvent(self, event)

    def mouseReleaseEvent(self, event):
        if event.pos() == self.__translation_orig:
            self.parentWidget().select_row_at(event.pos())
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

class TimeSeriesView(QWidget):

    DEFAULT_ROW_HEIGHT = 150

    def __init__(self, title=None, image_dir=None, parent=None):
        QWidget.__init__(self, parent)

        self.__toolbar = QToolBar()
        self.__scene = MyScene(0, 0, 600, 400)
        self.__view = TimeSeriesGraphicsView(self.__scene)
        self.__view.setAlignment(Qt.AlignLeft|Qt.AlignTop)

        self.__scene.sceneRectChanged.connect(self.on_rect_changed)

        if image_dir is None:
            image_dir = os.path.join(os.path.dirname(__file__), "img")

        self.__action_move_row_up = QAction(QIcon(os.path.join(image_dir, "up.svg")), "Move the row up", self.__toolbar)
        self.__action_move_row_up.triggered.connect(self.on_move_row_up)
        self.__action_move_row_down = QAction(QIcon(os.path.join(image_dir, "down.svg")), "Move the row down", self.__toolbar)
        self.__action_move_row_down.triggered.connect(self.on_move_row_down)

        self.__action_edit_style = QAction(QIcon(os.path.join(image_dir, "symbology.svg")), "Edit row style", self.__toolbar)
        self.__action_edit_style.triggered.connect(self.on_edit_style)

        self.__action_add_row = QAction(QIcon(os.path.join(image_dir, "add.svg")), "Add a data row", self.__toolbar)
        self.__action_add_row.triggered.connect(self.on_add_row)

        self.__action_remove_row = QAction(QIcon(os.path.join(image_dir, "remove.svg")), "Remove the row", self.__toolbar)
        self.__action_remove_row.triggered.connect(self.on_remove_row)

        self.__toolbar.addAction(self.__action_move_row_up)
        self.__toolbar.addAction(self.__action_move_row_down)
        self.__toolbar.addAction(self.__action_edit_style)
        self.__toolbar.addAction(self.__action_add_row)
        self.__toolbar.addAction(self.__action_remove_row)

        self.__title_label = QLabel()
        if title is not None:
            self.set_title(title)

        self.__status_bar = QStatusBar()

        vbox = QVBoxLayout()
        vbox.addWidget(self.__title_label)
        vbox.addWidget(self.__toolbar)
        vbox.addWidget(self.__view)
        vbox.addWidget(self.__status_bar)
        self.setLayout(vbox)

        self.__station_id = None
        # (log_item, legend_item) for each row
        self.__rows = []
        # { layer : (log_item, legend_item) }
        self.__data2logitems = {}
        self.__row_heights = []

        self._min_x = None
        self._max_x = None

        self.__allow_mouse_translation = True
        self.__translation_orig = None

        self.__style_dir = os.path.join(os.path.dirname(__file__),
                                        'styles')

        self.select_row(-1)

        self._update_row_depths()

    def on_rect_changed(self, rect):
        for item, _ in self.__rows:
            item.set_width(rect.width())

    def set_title(self, title):
        self.__title_label.setText(title)

    def _place_items(self):
        y = 0
        for i, r in enumerate(self.__rows):
            item, legend = r
            height = self.__row_heights[i]
            legend.setPos(0, y)
            item.setPos(legend.boundingRect().width(), y)
            y += height
        self.__view.setMinimumSize(self.__view.minimumSize().width(), y)

    def _add_row(self, log_item, legend_item):
        self.__scene.addItem(log_item)
        self.__scene.addItem(legend_item)

        log_item.set_min_depth(self._min_x)
        log_item.set_max_depth(self._max_x)
        self.__rows.insert(0, (log_item, legend_item))
        self.__row_heights.insert(0, log_item.boundingRect().height())

        self._place_items()

    def _fit_to_max_depth(self):
        self._min_x = min([i.min_depth() for i, _ in self.__rows if i.min_depth() is not None])
        self._max_x = max([i.max_depth() for i, _ in self.__rows if i.max_depth() is not None])

    def _update_row_depths(self):
        for item, _ in self.__rows:
            item.set_min_depth(self._min_x)
            item.set_max_depth(self._max_x)
            item.update()

    def remove_data_row(self, data):
        """Remove data row from widget

        :param data: data to be removed
        """

        # Row doesn't exist
        if data not in self.__data2logitems:
            raise ValueError("Impossible to remove data row : given data"
                             " object doesn't exist")

        log_item, legend_item = self.__data2logitems[data]
        for i, (pitem, litem) in enumerate(self.__rows):
            if pitem == log_item and litem == legend_item:
                self.__rows.pop(i)
                self.__row_widths.pop(i)
                del self.__data2logitems[data]
                self.__scene.removeItem(log_item)
                self.__scene.removeItem(legend_item)
                return

        # Rows not found
        assert False

    def on_plot_tooltip(self, txt):
        self.__status_bar.showMessage(txt)

    def add_data_row(self, data, title, uom):
        plot_item = PlotItem(size=QSizeF(self.__scene.width(), self.DEFAULT_ROW_HEIGHT),
                             render_type = LINE_RENDERER,
                             x_orientation = ORIENTATION_LEFT_TO_RIGHT,
                             y_orientation = ORIENTATION_UPWARD)

        plot_item.set_layer(data.get_layer())
        plot_item.tooltipRequested.connect(self.on_plot_tooltip)

        legend_item = LegendItem(self.DEFAULT_ROW_HEIGHT, title, unit_of_measure=uom, is_vertical=True)
        data.data_modified.connect(lambda data=data : self._update_data_row(data))

        if self._min_x is None:
            self._min_x, self._max_x = data.get_x_min(), data.get_x_max()
            self.add_time_scale()

        self.__data2logitems[data] = (plot_item, legend_item)
        self._add_row(plot_item, legend_item)
        self._update_data_row(data)
        self._update_row_depths()

    def add_time_scale(self, title="Time"):
        scale_item = TimeScaleItem(self.__scene.width(), self.DEFAULT_ROW_HEIGHT * 3 / 4, self._min_x, self._max_x)
        legend_item = LegendItem(self.DEFAULT_ROW_HEIGHT * 3 / 4, title, is_vertical = True)
        self._add_row(scale_item, legend_item)

    def _update_data_row(self, data):

        plot_item, legend_item = self.__data2logitems[data]

        y_values = data.get_y_values()
        x_values = data.get_x_values()
        if y_values is None or x_values is None:
            plot_item.set_data_window(None)
            return

        plot_item.set_data(data.get_x_values(), data.get_y_values())

        #r = QRectF(0, min_y, (max_x-min_x)/delta, max_y)
        #plot_item.set_data_window(r)

        # legend
        min_str = "{:.1f}".format(data.get_y_min())
        max_str = "{:.1f}".format(data.get_y_max())
        legend_item.set_scale(min_str, max_str)

        self.__scene.update()

    def select_row_at(self, pos):
        y = pos.y()
        r = 0
        selected = -1
        for i, height in enumerate(self.__row_heights):
            if y >= r and y < r + height:
                selected = i
                break
            r += height
        self.select_row(selected)

    def select_row(self, idx):
        self.__selected_row = idx
        for i, p in enumerate(self.__rows):
            item, legend = p
            item.set_selected(idx == i)
            legend.set_selected(idx == i)
            item.update()
            legend.update()

        self._update_button_visibility()

    def _update_button_visibility(self):
        idx = self.__selected_row
        self.__action_move_row_up.setEnabled(idx != -1 and idx > 0)
        self.__action_move_row_down.setEnabled(idx != -1 and idx < len(self.__rows) - 1)
        self.__action_edit_style.setEnabled(idx != -1)
        self.__action_remove_row.setEnabled(idx != -1)

    def on_move_row_up(self):
        if self.__selected_row < 1:
            return

        sel = self.__selected_row
        self.__rows[sel-1], self.__rows[sel] = self.__rows[sel], self.__rows[sel-1]
        self.__row_heights[sel-1], self.__row_heights[sel] = self.__row_heights[sel], self.__row_heights[sel-1]
        self.__selected_row -= 1
        self._place_items()
        self._update_button_visibility()

    def on_move_row_down(self):
        if self.__selected_row == -1 or self.__selected_row >= len(self.__rows) - 1:
            return

        sel = self.__selected_row
        self.__rows[sel+1], self.__rows[sel] = self.__rows[sel], self.__rows[sel+1]
        self.__row_heights[sel+1], self.__row_heights[sel] = self.__row_heights[sel], self.__row_heights[sel+1]
        self.__selected_row += 1
        self._place_items()
        self._update_button_visibility()

    def on_remove_row(self):
        if self.__selected_row == -1:
            return

        sel = self.__selected_row

        # remove item from scenes
        item, legend = self.__rows[sel]
        self.__scene.removeItem(legend)
        self.__scene.removeItem(item)

        # remove from internal list
        del self.__rows[sel]
        del self.__row_heights[sel]
        self.__selected_row = -1
        self._place_items()
        self._update_button_visibility()

    def on_edit_style(self):
        if self.__selected_row == -1:
            return

        item = self.__rows[self.__selected_row][0]
        item.edit_style()

    def on_add_row(self):
        # to be overridden by subclasses
        pass

# QGIS_PREFIX_PATH=~/src/qgis_2_18/build_ninja/output PYTHONPATH=~/src/qgis_2_18/build_ninja/output/python/ python timeseries_view.py
if __name__=='__main__':
    import sys
    import random

    from .qt_qgis_compat import qgsApplication, QgsVectorLayer, QgsFeature
    from .data_interface import FeatureData

    app = qgsApplication(sys.argv, True)
    app.initQgis()

    # feature example
    layer = QgsVectorLayer("None?field=y:double", "test_feature",
                           "memory")
    feature = QgsFeature()
    y_values = ",".join([str(random.uniform(1., 100.)) for i in range(1000)])
    feature.setAttributes([y_values])
    feature.setFeatureId(1)
    layer.dataProvider().addFeatures([feature])
    x_values = [float(x) for x in range(1, 1001)]

    layer2 = QgsVectorLayer("None?field=y:double", "test_feature",
                           "memory")
    feature = QgsFeature()
    y_values2 = ",".join([str(random.uniform(1., 100.)) for i in range(1000)])
    feature.setAttributes([y_values2])
    feature.setFeatureId(1)
    layer2.dataProvider().addFeatures([feature])

    w = TimeSeriesView("Sample")
    w.add_data_row(FeatureData(layer, "y", feature_id=1, x_start=1.0, x_delta=1.0), "test title", "m")
    w.add_data_row(FeatureData(layer2, "y", x_values, 1), "test title2", "m")

    w.show()

    app.exec_()

    app.exitQgis()

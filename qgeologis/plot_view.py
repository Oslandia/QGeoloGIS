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
Set of classes used to draw both "vertical" and "horizontal" plots.

The "X" axis in the code below refers to the dimension against which
the "Y" dimension is observed: e.g. time for timeseries or depth for well logs.

The X axis may also be named "domain axis".
The Y axis may also be named "value axis".
"""

from PyQt5.QtCore import (
    Qt, pyqtSignal,
    QSizeF,
    QRectF
)

from PyQt5.QtWidgets import (
    QGraphicsView,
    QGraphicsScene,
    QWidget,
    QAction,
    QToolBar,
    QLabel,
    QStatusBar,
    QHBoxLayout,
    QVBoxLayout
)

from PyQt5.QtGui import (
    QIcon
)

from .common import (
    POINT_RENDERER,
    POLYGON_RENDERER,
    ORIENTATION_UPWARD,
    ORIENTATION_DOWNWARD,
    ORIENTATION_LEFT_TO_RIGHT,
    ORIENTATION_HORIZONTAL,
    ORIENTATION_VERTICAL
)
from .plot_item import PlotItem
from .time_scale import TimeScaleItem
from .z_scale import ZScaleItem
from .legend_item import LegendItem
from .interval_plot import IntervalPlotItem

import os

class Axis:
    """Class designed to abstract X/Y axis calculations

    The X axis is refered to as the "domain" axis.
    The Y axis is refered to as the "value" axis.
    """

    def __init__(self, orientation):
        self._orientation = orientation

    def domain_pos(self, obj):
        """Returns the position on the domain axis of an object"""
        if self._orientation == ORIENTATION_HORIZONTAL:
            return obj.x()
        return obj.y()

    def value_pos(self, obj):
        """Returns the position on the value axis of an object"""
        if self._orientation == ORIENTATION_HORIZONTAL:
            return obj.y()
        return obj.x()

    def domain_size(self, obj):
        """Returns the size of the domain axis of a QSize/QRect/..."""
        if self._orientation == ORIENTATION_HORIZONTAL:
            return obj.width()
        return obj.height()

    def value_size(self, obj):
        """Returns the size of the value axis of a QSize/QRect/..."""
        if self._orientation == ORIENTATION_HORIZONTAL:
            return obj.height()
        return obj.width()

    def domain_set_size(self, obj, size):
        """Sets the size of the domain axis of a QSize/QRect/..."""
        if self._orientation == ORIENTATION_HORIZONTAL:
            return obj.setWidth(size)
        return obj.setHeight(size)

    def value_set_size(self, obj, size):
        """Sets the size of the value axis of a QSize/QRect/..."""
        if self._orientation == ORIENTATION_HORIZONTAL:
            return obj.setHeight(size)
        return obj.setWidth(size)


class PlotGraphicsView(QGraphicsView):
    def __init__(self, scene, orientation, parent=None):
        QGraphicsView.__init__(self, scene, parent)

        self.__allow_mouse_translation = True
        self.__translation_orig = None
        self.__translation_min_x = None
        self.__translation_max_x = None

        self.setMouseTracking(True)

        self.__axis = Axis(orientation)

    def resizeEvent(self, event):
        QGraphicsView.resizeEvent(self, event)
        # by default, the rect is centered on 0,0,
        # we prefer to have 0,0 in the upper left corner
        rect = self.scene().sceneRect()
        self.__axis.domain_set_size(rect, self.__axis.domain_size(event.size()))
        self.scene().setSceneRect(rect)

    def wheelEvent(self, event):
        delta = - event.angleDelta().y() / 100.0
        if delta >= 0:
            dt = 1.1
        else:
            dt = 0.9

        min_x = self.parentWidget()._min_x
        max_x = self.parentWidget()._max_x
        w = max_x - min_x
        nw = w * dt
        dx = self.__axis.domain_pos(event) / self.__axis.domain_size(self.scene().sceneRect()) * (w - nw)
        self.parentWidget()._min_x += dx
        self.parentWidget()._max_x = self.parentWidget()._min_x + nw
        self.parentWidget()._update_cell_sizes()

    def mouseMoveEvent(self, event):
        pos = self.mapToScene(event.pos())
        if not self.__allow_mouse_translation:
            return QGraphicsView.mouseMoveEvent(self, event)

        if self.__translation_orig is not None:
            delta = self.__translation_orig - pos
            delta_x = self.__axis.domain_pos(delta) \
                / self.__axis.domain_size(self.scene().sceneRect()) \
                * (self.parentWidget()._max_x - self.parentWidget()._min_x)
            self.parentWidget()._min_x = self.__translation_min_x + delta_x
            self.parentWidget()._max_x = self.__translation_max_x + delta_x
            self.parentWidget()._update_cell_sizes()
        return QGraphicsView.mouseMoveEvent(self, event)

    def mousePressEvent(self, event):
        pos = self.mapToScene(event.pos())
        self.__translation_orig = None
        if event.buttons() == Qt.LeftButton:
            self.__translation_orig = pos
            self.__translation_min_x = self.parentWidget()._min_x
            self.__translation_max_x = self.parentWidget()._max_x
        return QGraphicsView.mousePressEvent(self, event)

    def mouseReleaseEvent(self, event):
        pos = self.mapToScene(event.pos())
        if pos == self.__translation_orig:
            self.parentWidget().select_cell_at(pos)
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

class PlotView(QWidget):

    DEFAULT_ROW_HEIGHT = 150
    DEFAULT_COLUMN_WIDTH = 150

    # Emitted when some styles have been updated
    styles_updated = pyqtSignal()

    def __init__(self, title=None, image_dir=None, orientation=ORIENTATION_HORIZONTAL, parent=None):
        QWidget.__init__(self, parent)

        self.__orientation = orientation
        self.__axis = Axis(orientation)
        self._toolbar = QToolBar()
        self._scene = MyScene(0, 0, 600, 400)
        self.__view = PlotGraphicsView(self._scene, orientation)
        self.__view.setAlignment(Qt.AlignLeft|Qt.AlignTop)

        self._scene.sceneRectChanged.connect(self.on_rect_changed)

        if image_dir is None:
            image_dir = os.path.join(os.path.dirname(__file__), "img")

        if orientation == ORIENTATION_HORIZONTAL:
            self.__action_move_cell_before = QAction(QIcon(os.path.join(image_dir, "up.svg")), "Move up", self._toolbar)
            self.__action_move_cell_after = QAction(QIcon(os.path.join(image_dir, "down.svg")), "Move down", self._toolbar)
        else:
            self.__action_move_cell_before = QAction(QIcon(os.path.join(image_dir, "left.svg")), "Move left", self._toolbar)
            self.__action_move_cell_after = QAction(QIcon(os.path.join(image_dir, "right.svg")), "Move right", self._toolbar)

        self.__action_move_cell_before.triggered.connect(self.on_move_cell_before)
        self.__action_move_cell_after.triggered.connect(self.on_move_cell_after)

        self.__action_edit_style = QAction(QIcon(os.path.join(image_dir, "symbology.svg")), "Edit style", self._toolbar)
        self.__action_edit_style.triggered.connect(self.on_edit_style)

        self.__action_add_cell = QAction(QIcon(os.path.join(image_dir, "add.svg")), "Add a data cell", self._toolbar)
        self.__action_add_cell.triggered.connect(self.on_add_cell)

        self.__action_remove_cell = QAction(QIcon(os.path.join(image_dir, "remove.svg")), "Remove the cell", self._toolbar)
        self.__action_remove_cell.triggered.connect(self.on_remove_cell)

        self._toolbar.addAction(self.__action_move_cell_before)
        self._toolbar.addAction(self.__action_move_cell_after)
        self._toolbar.addAction(self.__action_edit_style)
        self._toolbar.addAction(self.__action_add_cell)
        self._toolbar.addAction(self.__action_remove_cell)

        self.__title_label = QLabel()
        if title is not None:
            self.set_title(title)

        self.__status_bar = QStatusBar()

        box = QVBoxLayout()
        box.addWidget(self.__title_label)
        box.addWidget(self._toolbar)
        box.addWidget(self.__view)
        box.addWidget(self.__status_bar)
        self.setLayout(box)

        # (plot_item, legend_item) for each cell
        self.__cells = []
        # { layer : (plot_item, legend_item) }
        self.__data2items = {}
        self.__cell_sizes = []

        # Minimum and maximum in the domain axis direction (a.k.a. X for horizontal)
        if orientation == ORIENTATION_HORIZONTAL:
            self._min_x, self._max_x = 0, 1200
        else:
            self._min_x, self._max_x = 0, 100

        self.__allow_mouse_translation = True
        self.__translation_orig = None

        self.__style_dir = os.path.join(os.path.dirname(__file__),
                                        'styles')

        self.__has_scale = False

        self.select_cell(-1)

        self._update_cell_sizes()

    def on_rect_changed(self, rect):
        if self.__orientation == ORIENTATION_HORIZONTAL:
            for item, _ in self.__cells:
                item.set_width(rect.width())
        else:
            for item, _ in self.__cells:
                item.set_height(rect.height())

    def set_title(self, title):
        self.__title_label.setText(title)

    def _place_items(self):
        xy = 0
        for i, r in enumerate(self.__cells):
            item, legend = r
            size = self.__cell_sizes[i]
            if self.__orientation == ORIENTATION_HORIZONTAL:
                legend.setPos(0, xy)
                item.setPos(legend.boundingRect().width(), xy)
            else:
                legend.setPos(xy, 0)
                item.setPos(xy, legend.boundingRect().height())
            xy += size

        rect = self._scene.sceneRect()
        self.__axis.value_set_size(rect, xy)
        self._scene.setSceneRect(rect)

    def _add_cell(self, plot_item, legend_item, reversed=False):
        self._scene.addItem(plot_item)
        self._scene.addItem(legend_item)

        plot_item.set_min_depth(self._min_x)
        plot_item.set_max_depth(self._max_x)

        if self.__orientation == ORIENTATION_VERTICAL:
            if not reversed:
                self.__cells.append((plot_item, legend_item))
                self.__cell_sizes.append(plot_item.boundingRect().width())
            else:
                self.__cells.insert(0, (plot_item, legend_item))
                self.__cell_sizes.insert(0, plot_item.boundingRect().width())
        else:
            if not reversed:
                self.__cells.insert(0, (plot_item, legend_item))
                self.__cell_sizes.insert(0, plot_item.boundingRect().height())
            else:
                self.__cells.append((plot_item, legend_item))
                self.__cell_sizes.append(plot_item.boundingRect().height())

        self._place_items()

    def set_x_range(self, min_x, max_x):
        self._min_x, self._max_x = min_x, max_x
        # Add a scale if none yet
        self.add_scale()
        self._update_cell_sizes()

    def _update_cell_sizes(self):
        if self._min_x is None:
            return
        for item, _ in self.__cells:
            item.set_min_depth(self._min_x)
            item.set_max_depth(self._max_x)
            item.update()

    def clear_data_cells(self):
        # remove item from scenes
        for (item, legend) in self.__cells:
            self._scene.removeItem(legend)
            self._scene.removeItem(item)

        # remove from internal lists
        self.__cells = []
        self.__cell_sizes = []
        self.__data2items = {}

        self.select_cell(-1)
        self._place_items()
        self._update_button_visibility()
        self.__has_scale = False

    def on_plot_tooltip(self, station_name, txt):
        if station_name is not None:
            self.__status_bar.showMessage(u"Station: {} ".format(station_name) + txt)
        else:
            self.__status_bar.showMessage(txt)

    def add_data_cell(self, data, title, uom, station_name = None, config=None):
        """
        Parameters
        ----------
        data: ??
        title: str
        uom: str
          Unit of measure
        station_name: str
          Station name
        config: PlotConfig
        """
        symbology, symbology_type = config.get_symbology()

        if self.__orientation == ORIENTATION_HORIZONTAL:
            default_size = QSizeF(self._scene.width(), self.DEFAULT_ROW_HEIGHT)
            x_orientation = ORIENTATION_LEFT_TO_RIGHT
            y_orientation = ORIENTATION_UPWARD
        else:
            default_size = QSizeF(self.DEFAULT_COLUMN_WIDTH, self._scene.height())
            x_orientation = ORIENTATION_DOWNWARD
            y_orientation = ORIENTATION_LEFT_TO_RIGHT

        plot_item = PlotItem(
            default_size,
            render_type=POINT_RENDERER if not symbology_type else symbology_type,
            symbology=symbology,
            x_orientation=x_orientation,
            y_orientation=y_orientation
        )

        plot_item.style_updated.connect(self.styles_updated)

        plot_item.set_layer(data.get_layer())
        plot_item.tooltipRequested.connect(lambda txt: self.on_plot_tooltip(station_name, txt))

        legend_item = LegendItem(
            self.__axis.value_size(default_size),
            title,
            unit_of_measure=uom,
            # legend is vertical if the plot is horizontal
            is_vertical=self.__orientation == ORIENTATION_HORIZONTAL
        )
        data.data_modified.connect(lambda data=data: self._update_data_cell(data, config))

        # center on new data
        self._min_x, self._max_x = data.get_x_min(), data.get_x_max()
        if self._min_x and self._min_x == self._max_x:
            if self.__orientation == ORIENTATION_HORIZONTAL:
                # if we have only one value, center it on a 4 days range
                self._min_x -= 3600*24*2
                self._max_x += 3600*24*2
            else:
                # -/+ 1 meter in depth
                self._min_x -= 1
                self._max_x += 1

        self.__data2items[data] = (plot_item, legend_item)
        self._add_cell(plot_item, legend_item)
        self._update_data_cell(data, config)
        self._update_cell_sizes()

    def add_scale(self, title="Time"):
        if self._min_x is None or self._max_x is None:
            return
        if self.__has_scale:
            return
        if self.__orientation == ORIENTATION_HORIZONTAL:
            scale_item = TimeScaleItem(self._scene.width(), self.DEFAULT_ROW_HEIGHT * 3 / 4, self._min_x, self._max_x)
            legend_item = LegendItem(self.DEFAULT_ROW_HEIGHT * 3 / 4, title, is_vertical=True)
        else:
            scale_item = ZScaleItem(self.DEFAULT_COLUMN_WIDTH / 2, self._scene.height(), self._min_x, self._max_x)
            legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH / 2, title, unit_of_measure="m")

        self._add_cell(scale_item, legend_item, reversed=True)
        self.__has_scale = True

    def _update_data_cell(self, data, config):
        plot_item, legend_item = self.__data2items[data]

        y_values = data.get_y_values()
        x_values = data.get_x_values()
        if y_values is None or x_values is None:
            plot_item.set_data_window(None)
            return

        plot_item.set_data(data.get_x_values(), data.get_y_values())
        win = plot_item.data_window()
        min_x, min_y, max_x, max_y = win.left(), win.top(), win.right(), win.bottom()

        if config and config.get("min") is not None:
            min_y = float(config['min'])
        if config and config.get("max") is not None:
            max_y = float(config['max'])

        # legend
        legend_item.set_scale(min_y, max_y)
        plot_item.set_data_window(QRectF(min_x, min_y, max_x-min_x, max_y-min_y))

        self._scene.update()

    def add_histogram(self, layer, filter_expression, column_mapping, title, config=None, station_name=""):
        """Add histogram data

        Parameters
        ----------
        layer: QgsVectorLayer
          The input layer
        filter_expression: str
          A QGIS expression to filter the vector layer
        column_mapping: dict
          Dictionary of column names
        title: str
          Title of the graph
        config: PlotConfig
        station_name: str
          Name of the station
        """
        symbology, symbology_type = config.get_symbology()

        if self.__orientation == ORIENTATION_HORIZONTAL:
            default_size = QSizeF(self._scene.width(), self.DEFAULT_ROW_HEIGHT)
            x_orientation = ORIENTATION_LEFT_TO_RIGHT
            y_orientation = ORIENTATION_UPWARD
        else:
            default_size = QSizeF(self.DEFAULT_COLUMN_WIDTH, self._scene.height())
            x_orientation = ORIENTATION_DOWNWARD
            y_orientation = ORIENTATION_LEFT_TO_RIGHT

        item = IntervalPlotItem(
            layer,
            column_mapping=column_mapping,
            filter_expression=filter_expression,
            size=default_size,
            render_type=POLYGON_RENDERER if symbology_type is None else symbology_type,
            x_orientation=x_orientation,
            y_orientation=y_orientation,
            symbology=symbology
        )
        if item.data_window():
            self.set_x_range(item.min_depth(), item.max_depth())
            item.style_updated.connect(self.styles_updated)
            legend_item = LegendItem(
                self.__axis.value_size(default_size),
                title,
                unit_of_measure=config.get("uom"),
                # legend is vertical if the plot is horizontal
                is_vertical=self.__orientation == ORIENTATION_HORIZONTAL
            )
            min_y, max_y = item.data_window().top(), item.data_window().bottom()
            legend_item.set_scale(min_y, max_y)

            item.tooltipRequested.connect(lambda txt: self.on_plot_tooltip(station_name, txt))

            self._add_cell(item, legend_item)

    def select_cell_at(self, pos):
        s = self.__axis.value_pos(pos)
        r = 0
        selected = -1
        for i, size in enumerate(self.__cell_sizes):
            if s >= r and s < r + size:
                selected = i
                break
            r += size
        self.select_cell(selected)

    def select_cell(self, idx):
        self.__selected_cell = idx
        for i, p in enumerate(self.__cells):
            item, legend = p
            item.set_selected(idx == i)
            legend.set_selected(idx == i)
            item.update()
            legend.update()

        self._update_button_visibility()

    def _update_button_visibility(self):
        idx = self.__selected_cell
        self.__action_move_cell_before.setEnabled(idx != -1 and idx > 0)
        self.__action_move_cell_after.setEnabled(idx != -1 and idx < len(self.__cells) - 1)
        self.__action_edit_style.setEnabled(idx != -1)
        self.__action_remove_cell.setEnabled(idx != -1)

    def on_move_cell_before(self):
        if self.__selected_cell < 1:
            return

        sel = self.__selected_cell
        self.__cells[sel-1], self.__cells[sel] = self.__cells[sel], self.__cells[sel-1]
        self.__cell_sizes[sel-1], self.__cell_sizes[sel] = self.__cell_sizes[sel], self.__cell_sizes[sel-1]
        self.__selected_cell -= 1
        self._place_items()
        self._update_button_visibility()

    def on_move_cell_after(self):
        if self.__selected_cell == -1 or self.__selected_cell >= len(self.__cells) - 1:
            return

        sel = self.__selected_cell
        self.__cells[sel+1], self.__cells[sel] = self.__cells[sel], self.__cells[sel+1]
        self.__cell_sizes[sel+1], self.__cell_sizes[sel] = self.__cell_sizes[sel], self.__cell_sizes[sel+1]
        self.__selected_cell += 1
        self._place_items()
        self._update_button_visibility()

    def on_remove_cell(self):
        if self.__selected_cell == -1:
            return

        sel = self.__selected_cell

        # remove item from scenes
        item, legend = self.__cells[sel]
        self._scene.removeItem(legend)
        self._scene.removeItem(item)

        # remove from internal list
        del self.__cells[sel]
        del self.__cell_sizes[sel]
        self.__selected_cell = -1
        self._place_items()
        self._update_button_visibility()

    def on_edit_style(self):
        if self.__selected_cell == -1:
            return

        item = self.__cells[self.__selected_cell][0]
        item.edit_style()

    def on_add_cell(self):
        # to be overridden by subclasses
        pass

    def styles(self):
        """Return the current style of each item"""
        return dict([(item.layer().id(), item.qgis_style())
                     for item, _ in self.__cells
                     if hasattr(item, "qgis_style")])

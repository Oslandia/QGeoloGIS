#!/usr/bin/env python
# -*- coding: utf-8 -*-

from well_log_common import *
from well_log_plot import PlotItem
from well_log_z_scale import ZScaleItem
from well_log_stratigraphy import StratigraphyItem

import numpy as np

import os

class LegendItem(LogItem):
    # margin all around the whole legend item
    LEGEND_ITEM_MARGIN = 3
    # margin between title and legend line
    LEGEND_LINE_MARGIN = 4

    def __init__(self, width, title, min_value=None, max_value=None, unit_of_measure=None, parent=None):
        LogItem.__init__(self, parent)
        self.__width = width
        self.__title = title
        self.__min_value = min_value
        self.__max_value = max_value
        self.__uom = unit_of_measure

        self.__selected = False

        # title font
        self.__font1 = QFont()
        self.__font1.setBold(True)
        self.__font1.setPointSize(12)

        # value font
        self.__font2 = QFont()
        self.__font2.setPointSize(9)

        fm1 = QFontMetrics(self.__font1)
        fm2 = QFontMetrics(self.__font2)
        self.__height = self.LEGEND_LINE_MARGIN * 3 + fm1.height() + fm2.height() + 10 + self.LEGEND_ITEM_MARGIN

    def set_scale(self, min_value, max_value):
        self.__min_value = min_value
        self.__max_value = max_value

    def boundingRect(self):
        return QRectF(0, 0, self.__width, self.__height)

    def selected(self):
        return __selected

    def paint(self, painter, option, widget):
        self.draw_background(painter, outline=False)

        painter.setFont(self.__font1)
        fm = painter.fontMetrics()
        # add "..." if needed
        title = fm.elidedText(self.__title, Qt.ElideRight, self.__width)
        w1 = (self.__width - fm.width(title)) / 2
        y = self.LEGEND_ITEM_MARGIN + fm.ascent()
        painter.drawText(w1, y, title)
        y += fm.descent() + self.LEGEND_LINE_MARGIN

        # legend line
        xmin = 0
        xmax = self.__width - 1
        painter.drawLine(xmin, y+5, xmax, y+5)
        painter.drawLine(xmin, y, xmin, y+10)
        painter.drawLine(xmax, y, xmax, y+10)
        y+= 10 + self.LEGEND_LINE_MARGIN

        painter.setFont(self.__font2)
        fm = painter.fontMetrics()
        y += fm.ascent()
        if self.__min_value is not None:
            painter.drawText(self.LEGEND_ITEM_MARGIN, y, str(self.__min_value))
        if self.__max_value is not None:
            t = str(self.__max_value)
            painter.drawText(self.__width - self.LEGEND_ITEM_MARGIN - fm.width(t), y, t)
        if self.__uom is not None:
            t = str(self.__uom)
            painter.drawText((self.__width - fm.width(t)) /2, y, t)

class LogGraphicsView(QGraphicsView):
    def __init__(self, scene, parent=None):
        QGraphicsView.__init__(self, scene, parent)

        self.__allow_mouse_translation = True
        self.__translation_orig = None
        self.__translation_min_z = None
        self.__translation_max_z = None

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

        return QGraphicsView.mouseReleaseEvent(self, event)

class WellLogView(QWidget):

    DEFAULT_COLUMN_WIDTH = 150

    def __init__(self, db_connection, style_dir=None, image_dir=None, parent=None):
        QWidget.__init__(self, parent)

        self.__toolbar = QToolBar()
        self.__log_scene = QGraphicsScene(0, 0, 600, 600)
        self.__log_view = LogGraphicsView(self.__log_scene)
        self.__log_view.setAlignment(Qt.AlignLeft|Qt.AlignTop)

        self.__log_scene.sceneRectChanged.connect(self.on_rect_changed)

        if image_dir is None:
            image_dir = os.path.join(os.path.dirname(__file__), "img")

        self.__action_move_column_left = QAction(QIcon(os.path.join(image_dir, "left.svg")), "Move the column to the left", self.__toolbar)
        self.__action_move_column_left.triggered.connect(self.on_move_column_left)
        self.__action_move_column_right = QAction(QIcon(os.path.join(image_dir, "right.svg")), "Move the column to the right", self.__toolbar)
        self.__action_move_column_right.triggered.connect(self.on_move_column_right)

        self.__action_edit_style = QAction(QIcon(os.path.join(image_dir, "symbology.svg")), "Edit column style", self.__toolbar)
        self.__action_edit_style.triggered.connect(self.on_edit_style)

        self.__action_add_column = QAction(QIcon(os.path.join(image_dir, "add.svg")), "Add a data column", self.__toolbar)
        self.__action_add_column.triggered.connect(self.on_add_column)

        self.__action_remove_column = QAction(QIcon(os.path.join(image_dir, "remove.svg")), "Remove the column", self.__toolbar)
        self.__action_remove_column.triggered.connect(self.on_remove_column)

        self.__toolbar.addAction(self.__action_move_column_left)
        self.__toolbar.addAction(self.__action_move_column_right)
        self.__toolbar.addAction(self.__action_edit_style)
        self.__toolbar.addAction(self.__action_add_column)
        self.__toolbar.addAction(self.__action_remove_column)

        self.__db_connection = db_connection

        self.__station_label = QLabel()

        vbox = QVBoxLayout()
        vbox.addWidget(self.__station_label)
        vbox.addWidget(self.__toolbar)
        vbox.addWidget(self.__log_view)
        self.setLayout(vbox)

        self.__station_id = None
        # (log_item, legend_item) for each column
        self.__columns = []
        self.__column_widths = []

        self._min_z = 0
        self._max_z = 40

        self.__allow_mouse_translation = True
        self.__translation_orig = None

        if style_dir is None:
            self.__style_dir = os.path.dirname(__file__)
        else:
            self.__style_dir = style_dir

        self.select_column(-1)

        # by default we have two columns: Z scale and stratigraphy
        self._add_z_scale()
        self._add_stratigraphy_column()


    def on_rect_changed(self, rect):
        for item, _ in self.__columns:
            item.set_height(rect.height())

    def set_station_id(self, station_id):
        self.__station_id = station_id

        for item, legend in self.__columns:
            if isinstance(item, PlotItem):
                self._update_data_column(item, legend)
            elif isinstance(item, StratigraphyItem):
                self._update_stratigraphy_column(item, legend)
            item.update()
            legend.update()

        self._fit_to_max_depth()
        self._update_column_depths()

    def set_station_name(self, site_name, station_name):
        sql = ("select station.id from station.station join station.site on "
               "site.id = site.id where station.name='{}' and site.name='{}'").format(station_name, site_name)
        l = QgsVectorLayer('{} table="({})" key="id"'.format(self.__db_connection, sql), "layer", "postgres")
        f = None
        for f in l.getFeatures():
            pass
        if f is None:
            return None
        self.__station_label.setText("<b>Station:</b> {}".format(station_name))
        self.set_station_id(f["id"])

    def _place_items(self):
        x = 0
        for i, c in enumerate(self.__columns):
            item, legend = c
            width = self.__column_widths[i]
            legend.setPos(x, 0)
            item.setPos(x, legend.boundingRect().height())
            x += width
        self.__log_view.setMinimumSize(x, self.__log_view.minimumSize().height())

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

    def _update_column_depths(self):
        for item, _ in self.__columns:
            item.set_min_depth(self._min_z)
            item.set_max_depth(self._max_z)
            item.update()

    def _add_z_scale(self):
        scale_item = ZScaleItem(self.DEFAULT_COLUMN_WIDTH / 2, self.__log_scene.height(), self._min_z, self._max_z)
        legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH / 2, "Prof.", unit_of_measure="m")
        self._add_column(scale_item, legend_item)
        
    def _add_data_column(self, table_name, title, uom):
        plot_item = PlotItem(size=QSizeF(self.DEFAULT_COLUMN_WIDTH, self.__log_scene.height()),
                             render_type = POLYGON_RENDERER,
                             x_orientation = ORIENTATION_DOWNWARD,
                             y_orientation = ORIENTATION_LEFT_TO_RIGHT)
        l = QgsVectorLayer('{} key="station_id" table="qgis"."{}" (geom)'.format(self.__db_connection, table_name), "layer", "postgres")
        plot_item.set_layer(l)

        legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH, title, uom)

        self._update_data_column(plot_item, legend_item)
        
        self._add_column(plot_item, legend_item)


    def _update_data_column(self, plot_item, legend_item):
        # data
        req = QgsFeatureRequest()
        req.setFilterExpression("station_id={}".format(self.__station_id))
        data = None
        for f in plot_item.layer().getFeatures(req):
            data = [None if s == 'NULL' else float(s) for s in f["measures"][1:-1].split(",")]
            min_x = f["begin_measure_altitude_m"]
            delta = f["altitude_interval_m"]
            break
        if data is None:
            plot_item.set_data_window(None)
            return
        max_x = min_x + delta*len(data)
        dt = np.array(data, dtype='float64')
        min_y = min(dt)
        max_y = max(dt)
        plot_item.set_data(dt, min_x, max_x, delta)
        r = QRectF(0, min_y, (max_x-min_x)/delta, max_y)
        plot_item.set_data_window(r)

        # legend
        min_str = "{:.1f}".format(min_y)
        max_str = "{:.1f}".format(max_y)
        legend_item.set_scale(min_str, max_str)

    def _add_stratigraphy_column(self):
        l = QgsVectorLayer('{} key="station_id,depth_from,depth_to" table="qgis"."measure_stratigraphic_logvalue" (geom)'.format(self.__db_connection),
                           "layer", "postgres")

        item = StratigraphyItem(self.DEFAULT_COLUMN_WIDTH,
                                self.__log_scene.height(),
                                style_file=os.path.join(self.__style_dir, "stratigraphy_style.xml"))
        legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH, "Stratigraphie")

        item.set_layer(l)

        self._update_stratigraphy_column(item, legend_item)
        
        self._add_column(item, legend_item)

    def _update_stratigraphy_column(self, item, legend):
        req = QgsFeatureRequest()
        req.setFilterExpression("station_id={}".format(self.__station_id))
        data = [(f["depth_from"], f["depth_to"], f["formation_code"], f["rock_code"]) for f in item.layer().getFeatures(req)]

        item.set_data(data)

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

    def _update_button_visibility(self):
        idx = self.__selected_column
        self.__action_move_column_left.setEnabled(idx != -1 and idx > 0)
        self.__action_move_column_right.setEnabled(idx != -1 and idx < len(self.__columns) - 1)
        self.__action_edit_style.setEnabled(idx != -1)
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
        dlg = QDialog()

        vbox = QVBoxLayout()

        btn = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        btn.accepted.connect(dlg.accept)
        btn.rejected.connect(dlg.reject)

        lw = QListWidget()

        vbox.addWidget(lw)
        vbox.addWidget(btn)

        l = QgsVectorLayer('{} table="qgis"."measure_metadata" key="measure_table"'.format(self.__db_connection), "md_layer", "postgres")
        for f in l.getFeatures():
            if f["x_axis_type"] != "DepthAxis":
                continue

            # check number of features for this station
            data_l = QgsVectorLayer('{} key="station_id" table="qgis"."{}" (geom)'.format(self.__db_connection, f["measure_table"]), "data_layer", "postgres")
            req = QgsFeatureRequest()
            req.setFilterExpression("station_id={}".format(self.__station_id))
            if len(list(data_l.getFeatures(req))) == 0:
                continue

            item = QListWidgetItem(f["name"])
            item.setData(Qt.UserRole, (f["measure_table"], f["unit_of_measure"]))
            lw.addItem(item)

        dlg.setLayout(vbox)
        dlg.setWindowTitle("Choose the data to add")
        dlg.resize(400,200)
        r = dlg.exec_()
        if r == QDialog.Accepted:
            item = lw.currentItem()
            if item is not None:
                table, uom = item.data(Qt.UserRole)
                self._add_data_column(table, item.text(), uom)

# QGIS_PREFIX_PATH=~/src/qgis_2_18/build/output PYTHONPATH=~/src/qgis_2_18/build/output/python/ python test_canvas.py
if __name__=='__main__':
    import sys

    from qgis.core import QgsApplication
    from PyQt4.QtGui import QApplication

    app = QgsApplication(sys.argv, True)
    #app = QApplication(sys.argv)
    QgsApplication.initQgis()

    w = WellLogView("service=bdlhes", style_dir="./styles/")
    w.set_station_name('valduc', 'B6')
    w._add_data_column("measure_tool_instant_speed", "Vitesse", "m/h")
    w._add_data_column("measure_weight_on_tool", "Poids", "t")
    w.show()

    app.exec_()

    QgsApplication.exitQgis()


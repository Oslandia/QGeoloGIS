# -*- coding: utf-8 -*-

from well_log_common import *

import numpy as np

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
        self.__min_x = None
        self.__max_x = None
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

    def boundingRect(self):
        #return QRectF(self.pos().x(), self.pos().y(), self.__item_size.width(), self.__item_size.height())
        return QRectF(0, 0, self.__item_size.width(), self.__item_size.height())

    def set_item_size(self, size):
        self.prepareGeometryChange()
        self.__item_size = size

    def height(self):
        return self.__item_size.height()
    def set_height(self, height):
        self.__item_size.setHeight(height)

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
            self.__data_rect.setX(min_depth / self.__delta)
    def set_max_depth(self, max_depth):
        if self.__data_rect is not None:
            w = max_depth / self.__delta - self.__data_rect.x()
            self.__data_rect.setWidth(w)

    def layer(self):
        return self.__layer
    def set_layer(self, layer):
        self.__layer = layer

    def data_window(self):
        return self.__data_rect

    def set_data(self, data, min_x, max_x, delta):
        self.__data = data
        self.__min_x = min_x
        self.__max_x = max_x
        self.__delta = delta

        real_data = [x for x in self.__data if x is not None]
        min_data = min(real_data)
        max_data = max(real_data)
        self.__data_rect = QRectF(0, min_data, len(self.__data), max_data-min_data)

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
        min_x = int(max([0, self.__data_rect.x()]))
        max_x = int(max([0, self.__data_rect.width() + self.__data_rect.x()]))
        data_slice = self.__data[min_x:max_x]

        if len(data_slice) == 0:
            return
        # filter points that are not None (nan in numpy arrays)
        defined_mask = np.invert(np.isnan(data_slice))
        defined_data = data_slice[defined_mask]
        n_points = len(defined_data)
        #print("# points rendered: {}".format(n_points))

        if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
            rw = float(self.__item_size.width()) / self.__data_rect.width()
            rh = float(self.__item_size.height()) / self.__data_rect.height()
            xx = (np.arange(len(data_slice), dtype='float64') + min_x - self.__data_rect.x()) * rw
            yy = (data_slice - self.__data_rect.y()) * rh
        elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
            rw = float(self.__item_size.height()) / self.__data_rect.width()
            rh = float(self.__item_size.width()) / self.__data_rect.height()
            xx = (data_slice - self.__data_rect.y()) * rh
            yy = self.__item_size.height() - (np.arange(len(data_slice), dtype='float64') + min_x - self.__data_rect.x()) * rw

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
            coords_view[:,0] = xx[defined_mask]
            coords_view[:,1] = yy[defined_mask]
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
            coords_view[:,0] = xx[defined_mask]
            coords_view[:,1] = yy[defined_mask]
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
            coords_view[:,0] = xx[defined_mask]
            coords_view[:,1] = yy[defined_mask]
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
        context.setExtent(QgsRectangle(0, 0, self.__item_size.width(), self.__item_size.height()))

        self.__renderer.startRender(context, fields)
        self.__renderer.renderFeature(feature, context)
        self.__renderer.stopRender(context)

    def mouseMoveEvent(self, event):
        if not self.__allow_mouse_translation:
            return QGraphicsItem.mouseMoveEvent(self, event)

        #print(event.pos(), event.lastPos())
        if self.__translation_orig is not None:
            delta = self.__translation_orig - event.pos()
            if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
                deltaX = delta.x() / self.__item_size.width() * self.__data_rect.width()
                deltaY = -delta.y() / self.__item_size.height() * self.__data_rect.height()
            elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
                deltaX = delta.y() / self.__item_size.height() * self.__data_rect.width()
                deltaY = delta.x() / self.__item_size.width() * self.__data_rect.height()
            self.__data_rect = QRectF(self.__translation_orig_rect)
            self.__data_rect.translate(deltaX, deltaY)
            self.update()
        return QGraphicsItem.mouseMoveEvent(self, event)

    def mousePressEvent(self, event):
        if not self.__allow_mouse_translation:
            return QGraphicsItem.mousePressEvent(self, event)
        self.__translation_orig = None
        if event.buttons() == Qt.LeftButton:
            self.__translation_orig = event.pos()
            self.__translation_orig_rect = QRectF(self.__data_rect)
        return QGraphicsItem.mousePressEvent(self, event)

    def wheelEvent(self, event):
        if not self.__allow_wheel_zoom:
            return QGraphicsItem.wheelEvent(self, event)
        #print("wheel", event.delta(), event.orientation())
        delta = -event.delta() / 100.0

        w = self.__data_rect.width()
        h = self.__data_rect.height()
        if delta > 0:
            nw = w * delta
            nh = h * delta
        else:
            nw = w / -delta
            nh = h / -delta
        if self.__x_orientation == ORIENTATION_LEFT_TO_RIGHT and self.__y_orientation == ORIENTATION_UPWARD:
            dx = self.__data_rect.x() + event.pos().x() / self.__item_size.width() * (w - nw)
            dy = self.__data_rect.y() + (self.__item_size.height() - event.pos().y()) / self.__item_size.height() * (h - nh)
        elif self.__x_orientation == ORIENTATION_DOWNWARD and self.__y_orientation == ORIENTATION_LEFT_TO_RIGHT:
            dx = self.__data_rect.x() + event.pos().y() / self.__item_size.height() * (w - nw)
            dy = self.__data_rect.y() + event.pos().x() / self.__item_size.width() * (h - nh)
        self.__data_rect.setWidth(nw)
        self.__data_rect.setHeight(nh)
        self.__data_rect.moveTo(dx, dy)
        self.update()

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

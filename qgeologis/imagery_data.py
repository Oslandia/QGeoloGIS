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

from qgis.PyQt.QtCore import QRectF, QSize
from qgis.PyQt.QtGui import QColor

from qgis.core import (QgsRasterLayer, QgsMapSettings, QgsMapRendererCustomPainterJob,
                       QgsRectangle, QgsProject)

from .common import LogItem


class ImageryDataItem(LogItem):
    def __init__(self, width, height, image_file, depth_from, depth_to, parent=None):
        LogItem.__init__(self, parent)

        self.__width = width
        self.__height = height
        self.__min_z = 0
        self.__max_z = 100

        self.__layer = QgsRasterLayer(image_file, "rl")
        QgsProject.instance().addMapLayers([self.__layer], False)
        self.__image_depth_range = (depth_from, depth_to)

        # unused for now
        self.__x_offset = 0

    def boundingRect(self):
        return QRectF(0, 0, self.__width, self.__height)

    def min_depth(self):
        return self.__min_z

    def max_depth(self):
        return self.__max_z

    def set_min_depth(self, min_depth):
        self.__min_z = min_depth
    def set_max_depth(self, max_depth):
        self.__max_z = max_depth

    def height(self):
        return self.__height
    def set_height(self, height):
        self.__height = height

    #def move_right(self):
    #    self.__x_offset -= 10.0 / self.__width * self.__layer.width()
    #    self.update()
    #def move_left(self):
    #    self.__x_offset += 10.0 / self.__width * self.__layer.width()
    #    self.update()

    def paint(self, painter, option, widget):
        self.draw_background(painter)
        painter.setClipRect(0, 0, self.__width-1, self.__height-2)

        image_depth = (self.__image_depth_range[1] - self.__image_depth_range[0])
        ymin = -(self.__max_z - self.__image_depth_range[0])/ image_depth * self.__layer.height()
        ymax = -(self.__min_z - self.__image_depth_range[0])/ image_depth * self.__layer.height()

        # we need to also set the width of the extent according to the aspect ratio
        # so that QGIS allows to "zoom in"
        ar = float(self.__layer.width()) / self.__layer.height()
        nw = ar * (ymax-ymin)

        lext = QgsRectangle(self.__x_offset, ymin, self.__x_offset+nw-1, ymax)

        # QgsMapSettings.setExtent() recomputes the given extent
        # so that the scene is centered
        # We reproduce here this computation to set the raster
        # x coordinate to what we want

        mw = float(self.__width-2)
        mh = float(self.__height-2)
        mu_p_px_y = lext.height() / mh
        mu_p_px_x = lext.width() / mw
        dxmin = lext.xMinimum()
        dxmax = lext.xMaximum()
        dymin = lext.yMinimum()
        dymax = lext.yMaximum()
        if mu_p_px_y > mu_p_px_x:
            mu_p_px = mu_p_px_y
            whitespace = ((mw * mu_p_px) - lext.width()) * 0.5
            dxmin -= whitespace
            dxmax += whitespace
        else:
            mu_p_px = mu_p_px_x
            whitespace = ((mh * mu_p_px) - lext.height()) * 0.5
            dymin -= whitespace
            dymax += whitespace
        lext = QgsRectangle(dxmin+whitespace, dymin, dxmax+whitespace, dymax)

        ms = QgsMapSettings()
        ms.setExtent(lext)
        ms.setOutputSize(QSize(mw, mh))
        ms.setLayers([self.__layer.id()])
        if self.selected():
            ms.setBackgroundColor(QColor("#ffff66"))
        job = QgsMapRendererCustomPainterJob(ms, painter)

        painter.translate(1, 1)
        job.start()
        job.waitForFinished()
        painter.translate(-1, -1)


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

from qgis.PyQt.QtCore import Qt, pyqtSignal
from qgis.PyQt.QtGui import QColor, QPen, QBrush
from qgis.PyQt.QtWidgets import QGraphicsWidget

from qgis.core import QgsMapToPixel, QgsRenderContext

POINT_RENDERER = 0
LINE_RENDERER = 1
POLYGON_RENDERER = 2

# X and Y data orientations
ORIENTATION_LEFT_TO_RIGHT = 0
ORIENTATION_RIGHT_TO_LEFT = 1 # unused
ORIENTATION_UPWARD = 2
ORIENTATION_DOWNWARD = 3

ORIENTATION_HORIZONTAL = 0
ORIENTATION_VERTICAL = 1

def qgis_render_context(painter, width, height):
    mtp = QgsMapToPixel()
    # the default viewport if centered on 0, 0
    mtp.setParameters( 1,        # map units per pixel
                       width/2,  # map center in geographical units
                       height/2, # map center in geographical units
                       width,    # output width in pixels
                       height,   # output height in pixels
                       0.0       # rotation in degrees
    )
    context = QgsRenderContext()
    context.setMapToPixel(mtp)
    context.setPainter(painter)
    return context

class LogItem(QGraphicsWidget):

    # the item has requested to display a tooltip string
    tooltipRequested = pyqtSignal(str)

    def __init__(self, parent=None):
        QGraphicsWidget.__init__(self, parent)

        self.__selected = False

    def selected(self):
        return self.__selected

    def set_selected(self, sel):
        self.__selected = sel

    def draw_background(self, painter, outline=True):
        old_pen = painter.pen()
        old_brush = painter.brush()
        p = QPen()
        b = QBrush()
        if self.__selected:
            p.setColor(QColor("#ffff99"))
            p.setWidth(2)
            b.setColor(QColor("#ffff66"))
            b.setStyle(Qt.SolidPattern)
        if self.__selected:
            painter.setBrush(b)
            painter.setPen(p)
            painter.drawRect(1, 0, self.boundingRect().width()-1, self.boundingRect().height()-1)
        if outline:
            painter.setBrush(QBrush())
            painter.setPen(QPen())
            painter.drawRect(0, 0, self.boundingRect().width(), self.boundingRect().height()-1)
        painter.setBrush(old_brush)
        painter.setPen(old_pen)

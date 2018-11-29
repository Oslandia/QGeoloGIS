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

from well_log_common import *

class ZScaleItem(LogItem):
    SCALE_POSSIBLE_STEPS = [0.1, 0.5, 1, 2, 5, 10, 20, 50, 100]
    def __init__(self, width, height, min_z, max_z, parent=None):
        LogItem.__init__(self, parent)

        self.__width = width
        self.__height = height
        self.__min_z = min_z
        self.__max_z = max_z

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

    def paint(self, painter, option, widget):
        import math
        self.draw_background(painter)
        painter.setClipRect(0, 0, self.__width, self.__height)

        depth = self.__max_z - self.__min_z
        pixels_per_m = float(depth) / self.__height
        
        fm = painter.fontMetrics()
        # we need two font height between two labels at minimum
        m_per_step = depth / self.__height * (2 * fm.height())
        # we round up at the nearest possible step
        for step in self.SCALE_POSSIBLE_STEPS:
            if step >= m_per_step:
                break

        # find the first integer depth
        mfirst = self.__min_z * 10
        mm = int(math.ceil(mfirst))
        offset = mm - mfirst
        while mm < self.__max_z * 10:
            m = mm / 10.0
            y = float(m - self.__min_z) / depth * self.__height + offset

            tick_size = 0
            if mm % 100 == 0:
                tick_size = 20
            elif mm % 10 == 0 and pixels_per_m < 0.25:
                tick_size = 10
            elif pixels_per_m < 0.025:
                tick_size = 5

            if tick_size > 0:
                painter.drawLine(0, y, tick_size, y)
                painter.drawLine(self.__width-tick_size, y, self.__width, y)

            if mm % (step * 10) == 0:
                s = str(m)
                x = (self.__width - fm.width(s)) / 2
                painter.drawText(x, y + fm.ascent() / 2, s)

            mm += 1

    def edit_style(self):
        pass

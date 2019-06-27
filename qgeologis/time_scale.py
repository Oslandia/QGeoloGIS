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

from qgis.PyQt.QtCore import QRectF

from .common import LogItem

from datetime import timedelta, tzinfo, datetime

# we assume epoch are computed based on a UTC time
class UTC(tzinfo):
    """UTC"""

    def utcoffset(self, dt):
        return timedelta(0)

    def tzname(self, dt):
        return "UTC"

    def dst(self, dt):
        return timedelta(0)

class TimeScaleItem(LogItem):
    # duration in seconds, next duration in seconds, datetime format
    DURATION_FORMATS = [(1, "%H:%M:%S"),
                        (60, "%H:%M"),
                        (3600, "%H:%M"),
                        (3600*24, "%Y-%m-%d"),
                        (3600*24*28, "%b %Y"),
                        (3600*24*365, "%Y")]
    def __init__(self, width, height, min_t, max_t, parent=None):
        LogItem.__init__(self, parent)

        self.__width = width
        self.__height = height
        self.__min_t = min_t
        self.__max_t = max_t

    def boundingRect(self):
        return QRectF(0, 0, self.__width, self.__height)

    def min_depth(self):
        return self.__min_t
    def max_depth(self):
        return self.__max_t

    def set_min_depth(self, min_depth):
        self.__min_t = min_depth
    def set_max_depth(self, max_depth):
        self.__max_t = max_depth

    def width(self):
        return self.__width
    def set_width(self, width):
        self.__width = width

    def mouseMoveEvent(self, event):
        #print(event.pos().x(), event.pos().y())
        pass

    def paint(self, painter, option, widget):
        import math
        self.draw_background(painter)
        painter.setClipRect(0, 0, self.__width, self.__height)

        fm = painter.fontMetrics()

        font = painter.font()
        bold_font = painter.font()
        bold_font.setBold(True)

        tick_size = 10
        utc = UTC()
        min_tick_distance = 2
        min_label_distance = 60
        
        duration_s = self.__max_t - self.__min_t
        # get the widest and narrowest scale
        min_slot_idx = None
        for slot_idx, (slot_duration, _) in enumerate(self.DURATION_FORMATS):
            slot_width = float(slot_duration) / duration_s * self.__width
            if min_slot_idx is None and slot_width > min_tick_distance:
                min_slot_idx = slot_idx

        # iterate from the narrowest to the widest scale
        slot_duration, format = self.DURATION_FORMATS[min_slot_idx]
        min_tick_idx = int(math.floor(float(self.__min_t) / slot_duration) + 1)
        max_tick_idx = int(math.ceil(float(self.__max_t) / slot_duration))
        old_x = 0
        for k in range(min_tick_idx,max_tick_idx):
            t = k * slot_duration
            x = int((t - self.__min_t) / float(duration_s) * self.__width)

            painter.drawLine(x, 0, x, tick_size)

            if x - old_x < min_label_distance:
                continue

            hformat = format
            painter.setFont(font)
            # replace the format with one of a wider scaler if it applies
            for j in range(min_slot_idx+1, len(self.DURATION_FORMATS)):
                next_slot_duration, next_format = self.DURATION_FORMATS[j]
                if t % next_slot_duration == 0:
                    hformat = next_format
                    painter.setFont(bold_font)
                    break
            
            old_x = x
            dt = datetime.fromtimestamp(t, utc)
            if dt.year < 1900:
                dt_str = "--"
            else:
                dt_str = unicode(dt.strftime(hformat), "utf8")
            r = fm.boundingRect(dt_str)

            # draw the text rotated
            painter.save()
            xx = x-r.width()/2
            yy = tick_size + 5
            painter.translate(xx+r.width()/2-r.height()/2, yy+r.width())
            painter.rotate(-90)
            painter.drawText(0, fm.ascent(), dt_str)
            painter.restore()

    def edit_style(self):
        pass

#!/usr/bin/env python
# -*- coding: utf-8 -*-

from well_log_common import *


class LegendItem(LogItem):
    # margin all around the whole legend item
    LEGEND_ITEM_MARGIN = 3
    # margin between title and legend line
    LEGEND_LINE_MARGIN = 4

    def __init__(self, width, title, min_value=None, max_value=None,
                 unit_of_measure=None, parent=None):
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

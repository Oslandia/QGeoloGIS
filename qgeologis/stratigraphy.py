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

import os

from qgis.PyQt.QtCore import QRectF, QVariant, pyqtSignal
from qgis.PyQt.QtGui import QPen, QBrush, QPolygonF
from qgis.PyQt.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QComboBox
from qgis.PyQt.QtWidgets import QPushButton, QStackedWidget, QDialogButtonBox, QFileDialog
from qgis.PyQt.QtXml import QDomDocument

from qgis.core import (QgsFeatureRenderer, QgsRectangle, QgsField, QgsFields, QgsGeometry,
                       QgsReadWriteContext, QgsFeature)

from .common import LogItem, POLYGON_RENDERER, qgis_render_context


class StratigraphyItem(LogItem):
    # emitted when the style is updated
    style_updated = pyqtSignal()

    def __init__(self, width, height, style_file=None, symbology=None,parent=None):
        LogItem.__init__(self, parent)

        self.__width = width
        self.__height = height
        self.__min_z = 0
        self.__max_z = 100

        self.__data = None
        self.__layer = None

        # change current directory, so that relative paths to SVG get correctly resolved
        os.chdir(os.path.dirname(__file__))

        if style_file:
            doc = QDomDocument()
            doc.setContent(open(style_file, "r").read())
            self.__renderer = QgsFeatureRenderer.load(doc.documentElement(), QgsReadWriteContext())
        elif symbology:
            self.__renderer = QgsFeatureRenderer.load(symbology.documentElement(), QgsReadWriteContext())
        else:
            self.__renderer = QgsFeatureRenderer.defaultRenderer(POLYGON_RENDERER)

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

    def set_data(self, data):
        self.__data = data

    def layer(self):
        return self.__layer
    def set_layer(self, layer):
        self.__layer = layer

    def paint(self, painter, option, widget):
        self.draw_background(painter)

        painter.setClipRect(0, 0, self.__width-1, self.__height-1)

        context = qgis_render_context(painter, self.__width, self.__height)
        context.setExtent(QgsRectangle(0, 0, self.__width, self.__height))
        fields = QgsFields()
        fields.append(QgsField("formation_code", QVariant.String))
        fields.append(QgsField("rock_code", QVariant.String))

        # need to set fields in context so they can be evaluated in expression.
        # if not QgsExpressionNodeColumnRef prepareNode methods will fail when
        # checking that variable EXPR_FIELDS is defined (this variable is set
        # by setFields method
        context.expressionContext().setFields(fields)

        self.__renderer.startRender(context, fields)

        for i, d in enumerate(self.__data):
            depth_from, depth_to, formation_code, rock_code = float(d[0]), float(d[1]), str(d[2]), str(d[3])

            if abs((self.__max_z - self.__min_z) * self.__height) > 0:
                y1 = (depth_from - self.__min_z) / (self.__max_z - self.__min_z) * self.__height
                y2 = (depth_to - self.__min_z) / (self.__max_z - self.__min_z) * self.__height

                painter.setPen(QPen())
                painter.setBrush(QBrush())
                if i == 0:
                    painter.drawLine(0, y1, self.__width-1, y1)
                painter.drawLine(0, y2, self.__width-1, y2)

                # legend text
                if formation_code:
                    fm = painter.fontMetrics()
                    w = fm.width(formation_code)
                    x = (self.__width/2 - w) / 2 + self.__width/2
                    y = (y1+y2)/2
                    if y - fm.ascent() > y1 and y + fm.descent() < y2:
                        painter.drawText(x, y, formation_code)

                geom = QgsGeometry.fromQPolygonF(QPolygonF(QRectF(0, self.__height-y1, self.__width/2, y1-y2)))

                feature = QgsFeature(fields, 1)

                feature["formation_code"] = formation_code
                feature["rock_code"] = rock_code
                feature.setGeometry(geom)

                self.__renderer.renderFeature(feature, context)

        self.__renderer.stopRender(context)

    def mouseMoveEvent(self, event):
        z = (event.scenePos().y() - self.pos().y()) / self.height() * (self.__max_z - self.__min_z) + self.__min_z
        for d in self.__data:
            depth_from, depth_to, _, _, formation_description, rock_description = d
            if z > depth_from and z < depth_to:
                self.tooltipRequested.emit(u"Formation: {} Rock: {}".format(formation_description, rock_description))
                break

    def edit_style(self):
        dlg = StratigraphyStyleDialog(self.__layer, self.__renderer)
        if dlg.exec_() == QDialog.Accepted:
            self.__renderer = dlg.renderer().clone()
            self.update()
            self.style_updated.emit()

    def qgis_style(self):
        """Returns the current style, as a QDomDocument"""
        from PyQt5.QtXml import QDomDocument
        from qgis.core import QgsReadWriteContext

        doc = QDomDocument()
        elt = self.__renderer.save(doc, QgsReadWriteContext())
        doc.appendChild(elt)
        return (doc, 0)

class StratigraphyStyleDialog(QDialog):
    def __init__(self, layer, renderer, parent=None):
        QDialog.__init__(self, parent)

        self.__layer = layer
        self.__renderer = renderer

        from qgis.gui import QgsSingleSymbolRendererWidget, QgsRuleBasedRendererWidget, QgsCategorizedSymbolRendererWidget, QgsGraduatedSymbolRendererWidget
        from qgis.core import QgsSingleSymbolRenderer, QgsRuleBasedRenderer, QgsCategorizedSymbolRenderer, QgsGraduatedSymbolRenderer
        from qgis.core import QgsStyle

        vbox = QVBoxLayout()
        hbox = QHBoxLayout()

        self.__combo = QComboBox()

        self.__load_btn = QPushButton("Charger style")
        self.__save_btn = QPushButton("Sauver style")
        self.__load_btn.clicked.connect(self.on_load_style)
        self.__save_btn.clicked.connect(self.on_save_style)
        hbox.addWidget(self.__combo)
        hbox.addWidget(self.__load_btn)
        hbox.addWidget(self.__save_btn)

        self.__sw = QStackedWidget()
        self.__classes = [(u"Symbole unique", QgsSingleSymbolRenderer, QgsSingleSymbolRendererWidget),
                          (u"Ensemble de règles", QgsRuleBasedRenderer, QgsRuleBasedRendererWidget),
                          (u"Catégorisé", QgsCategorizedSymbolRenderer, QgsCategorizedSymbolRendererWidget),
                          (u"Gradué", QgsGraduatedSymbolRenderer, QgsGraduatedSymbolRendererWidget)]
        self.__styles = [QgsStyle(), QgsStyle(), QgsStyle(), QgsStyle()]
        for i, c in enumerate(self.__classes):
            name, cls, wcls = c
            w = wcls.create(self.__layer, self.__styles[i], self.__renderer)
            self.__sw.addWidget(w)
            self.__combo.addItem(name)

        self.__combo.currentIndexChanged.connect(self.__sw.setCurrentIndex)

        for i, c in enumerate(self.__classes):
            _, cls, _ = c
            if self.__renderer.__class__ == cls:
                self.__combo.setCurrentIndex(i)
                break

        btn = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        btn.accepted.connect(self.accept)
        btn.rejected.connect(self.reject)

        vbox.addLayout(hbox)
        vbox.addWidget(self.__sw)
        vbox.addWidget(btn)

        self.setLayout(vbox)
        self.resize(800, 600)

    def renderer(self):
        return self.__renderer

    def on_save_style(self):
        fn, _ = QFileDialog.getSaveFileName(self, "Fichier style à sauvegarder", filter = "*.xml")
        if fn:
            doc = QDomDocument()
            elt = self.__sw.currentWidget().renderer().save(doc, QgsReadWriteContext())
            doc.appendChild(elt)
            fo = open(fn, "w")
            fo.write(doc.toString())
            fo.close()

    def on_load_style(self):
        fn, _ = QFileDialog.getOpenFileName(self, "Fichier style à charger", filter = "*.xml")
        if fn:
            doc = QDomDocument()
            doc.setContent(open(fn, "r").read())
            self.__renderer = QgsFeatureRenderer.load(doc.documentElement(), QgsReadWriteContext())
            for i, c in enumerate(self.__classes):
                _, cls, wcls = c
                if self.__renderer.__class__ == cls:
                    new_widget = wcls.create(self.__layer, self.__styles[i], self.__renderer)
                    idx = i
                    break
            # replace old widget
            self.__sw.removeWidget(self.__sw.widget(idx))
            self.__sw.insertWidget(idx, new_widget)
            self.__sw.setCurrentIndex(idx)
            self.__combo.setCurrentIndex(idx)

    def accept(self):
        self.__renderer = self.__sw.currentWidget().renderer().clone()
        self.update()
        return QDialog.accept(self)

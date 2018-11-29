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

from PyQt4.QtCore import pyqtSignal, QObject
from qgis.core import QgsFeatureRequest


class DataInterface(QObject):

    data_modified = pyqtSignal()

    def __init__(self):
        QObject.__init__(self)

    def get_x_values(self):
        raise("DataInterface is an abstract class, get_x_values() "
              "must be defined")

    def get_y_values(self):
        raise("DataInterface is an abstract class, get_y_values() "
              "must be defined")

    # keep here just for compatibility but it should'nt exist
    # plot_item doesn't need layer object
    def get_layer(self):
        raise("DataInterface is an abstract class, get_layer() "
              "must be defined")


class LayerData(DataInterface):

    def __init__(self, layer, x_fieldname, y_fieldname):

        DataInterface.__init__(self)

        self.__y_fieldname = y_fieldname
        self.__x_fieldname = x_fieldname
        self.__layer = layer
        self.__y_values = None
        self.__x_values = None

        layer.attributeValueChanged.connect(self.__build_data)
        layer.featureAdded.connect(self.__build_data)
        layer.featureDeleted.connect(self.__build_data)

        self.__build_data()

    def get_y_values(self):
        return self.__y_values

    def get_layer(self):
        return self.__layer

    def get_x_values(self):
        return self.__x_values

    def __build_data(self):

        # TODO It should have been way more better to use addOrderBy on
        # QgsFeatureRequest but it doesn't work well (with memory data for
        # instance) in QGIS 2 To be changed in QGIS 3

        # Sort data on x for correct display
        xy_values = zip([f[self.__x_fieldname]
                         for f in self.__layer.getFeatures()],
                        [f[self.__y_fieldname]
                         for f in self.__layer.getFeatures()])

        # sort on x
        xy_values.sort(key=lambda coord: coord[0])

        self.__x_values = [coord[0] for coord in xy_values]
        self.__y_values = [coord[1] for coord in xy_values]

        self.data_modified.emit()


class FeatureData(DataInterface):

    def __init__(self, layer, y_fieldname, x_values, feature_id=0):

        DataInterface.__init__(self)

        self.__y_fieldname = y_fieldname
        self.__layer = layer
        self.__x_values = x_values
        self.__feature_id = feature_id

        # TODO connect on feature modification

        self.__build_data()

    def get_y_values(self):
        return self.__y_values

    def get_layer(self):
        return self.__layer

    def get_x_values(self):
        return self.__x_values

    def __build_data(self):

        req = QgsFeatureRequest()
        req.setFilterExpression("$id={}".format(self.__feature_id))
        f = next(self.__layer.getFeatures())

        if not f:
            return

        self.__y_values = [float(value)
                           for value in f[self.__y_fieldname].split(",")]

        self.data_modified.emit()

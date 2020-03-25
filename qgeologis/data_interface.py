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

from qgis.PyQt.QtCore import pyqtSignal, QObject, QVariant
from qgis.core import QgsFeatureRequest

import numpy as np

class DataInterface(QObject):
    """DataInterface is a class that abstracts how a bunch of (X,Y) data are represented"""

    data_modified = pyqtSignal()

    def __init__(self):
        QObject.__init__(self)

    def get_x_values(self):
        raise("DataInterface is an abstract class, get_x_values() "
              "must be defined")

    def get_y_values(self):
        raise("DataInterface is an abstract class, get_y_values() "
              "must be defined")

    def get_x_min(self):
        raise("DataInterface is an abstract class, get_x_min() "
              "must be defined")

    def get_x_max(self):
        raise("DataInterface is an abstract class, get_x_min() "
              "must be defined")

    def get_y_min(self):
        raise("DataInterface is an abstract class, get_y_min() "
              "must be defined")

    def get_y_max(self):
        raise("DataInterface is an abstract class, get_y_max() "
              "must be defined")

    # keep here just for compatibility but it should'nt exist
    # plot_item doesn't need layer object
    # FIXME a layer seems to be needed for symbology.
    # TODO: try to make it internal to plotter UI
    def get_layer(self):
        raise("DataInterface is an abstract class, get_layer() "
              "must be defined")



class LayerData(DataInterface):
    """LayerData model data that are spanned on multiple features (resp. rows) on a layer (resp. table).

    This means each feature (resp. row) of a layer (resp. table) has one (X,Y) pair.
    They will be sorted on X before being displayed.
    """

    # BREAKING CHANGE FOR NEXT RELEASE
    # nodata_value should be None by default (i.e. remove null values)
    def __init__(self, layer, x_fieldname, y_fieldname, filter_expression = None, nodata_value = 0.0, uom = None):
        """
        Parameters
        ----------
        layer: QgsVectorLayer
          Vector layer that holds data
        x_fieldname: str
          Name of the field that holds X values
        y_fieldname: str
          Name of the field that holds Y values
        filter_expression: str
          Filter expression
        nodata_value: Optional[float]
          If None, null values will be removed
          Otherwise, they will be replaced by nodata_value
        uom: Optional[str]
          Unit of measure
          If uom starts with "@" it means the unit of measure is carried by a field name
          e.g. @unit means the field "unit" carries the unit of measure
        """

        DataInterface.__init__(self)

        self.__y_fieldname = y_fieldname
        self.__x_fieldname = x_fieldname
        self.__layer = layer
        self.__y_values = None
        self.__x_values = None
        self.__x_min = None
        self.__x_max = None
        self.__y_min = None
        self.__y_max = None
        self.__filter_expression = filter_expression
        self.__nodata_value = nodata_value
        self.__uom = uom

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

    def get_x_min(self):
        return self.__x_min

    def get_x_max(self):
        return self.__x_max

    def get_y_min(self):
        return self.__y_min

    def get_y_max(self):
        return self.__y_max

    def uom(self):
        return self.__uom

    def __build_data(self):

        req = QgsFeatureRequest()
        if self.__filter_expression is not None:
            req.setFilterExpression(self.__filter_expression)

        # Get unit of the first feature if needed
        if self.__uom is not None and self.__uom.startswith("@"):
            request_unit = QgsFeatureRequest(req)
            request_unit.setLimit(1)
            for f in self.__layer.getFeatures(request_unit):
                self.__uom = f[self.__uom[1:]]
                break

        req.setSubsetOfAttributes([self.__x_fieldname, self.__y_fieldname], self.__layer.fields())
        # Do not forget to add an index on this field to speed up ordering
        req.addOrderBy(self.__x_fieldname)

        def is_null(v):
            return isinstance(v, QVariant) and v.isNull()

        if self.__nodata_value is not None:
            # replace null values by a 'Nodata' value
            xy_values = [(
                f[self.__x_fieldname], f[self.__y_fieldname]
                if not is_null(f[self.__y_fieldname])
                else self.__nodata_value
            )
                         for f in self.__layer.getFeatures(req)
            ]
        else:
            # do not include null values
            xy_values = [
                (f[self.__x_fieldname], f[self.__y_fieldname])
                for f in self.__layer.getFeatures(req)
                if not is_null(f[self.__y_fieldname])
            ]

        self.__x_values = [coord[0] for coord in xy_values]
        self.__y_values = [coord[1] for coord in xy_values]

        self.__x_min, self.__x_max = (min(self.__x_values), max(self.__x_values)) if self.__x_values else (None, None)
        self.__y_min, self.__y_max = (min(self.__y_values), max(self.__y_values)) if self.__y_values else (None, None)

        self.data_modified.emit()


class IntervalData(DataInterface):
    """IntervalData models data that have one Y value for a range of X values.

    They are usually used to represent "continuous" data (as opposed to "discrete" data).
    The Y value may represent an average on the range, or a sum.
    X ranges may be of different sizes and not necessarily adjacent.
    """

    def __init__(self, layer, x_min_fieldname, x_max_fieldname, y_fieldname, filter_expression = None, uom = None):
        """
        layer: QgsVectorLayer
          Input vector layer
        x_min_fieldname: str
          Name of the field that carries the minimum value of each X interval
        x_max_fieldname: str
          Name of the field that carries the maximum value of each X interval
        y_fieldname: str
          Name of the field in the input layer that carries data
        filter_expression: Optional[str]
          Filter expression to apply to the input vector layer
        uom: Optional[str]
          Unit of measure
          If uom starts with "@" it means the unit of measure is carried by a field name
          e.g. @unit means the field "unit" carries the unit of measure
        """
        super().__init__()

        self.__layer = layer
        self.__x_min_fieldname = x_min_fieldname
        self.__x_max_fieldname = x_max_fieldname
        self.__y_fieldname = y_fieldname
        self.__uom = uom

    def get_x_values(self):
        """Returns a sequence of (x_min, x_max) intervals"""
        return None

    def get_y_values(self):
        """Returns a sequence of y values (floats)"""
        return None

    def get_x_min(self):
        """Returns the minimum X of all the intervals"""
        return None

    def get_x_max(self):
        """Returns the maximum X of all the intervals"""
        return None

    def get_y_min(self):
        """Returns the minimum Y value"""
        return None

    def get_y_max(self):
        """Returns the maximum Y value"""
        return None

    def get_layer(self):
        return self.__layer

    """
    def __build_data(self):

        req = QgsFeatureRequest()
        if self.__filter_expression is not None:
            req.setFilterExpression(self.__filter_expression)

        # Get unit of the first feature if needed
        if self.__uom is not None and self.__uom.startswith("@"):
            request_unit = QgsFeatureRequest(req)
            request_unit.setLimit(1)
            for f in self.__layer.getFeatures(request_unit):
                self.__uom = f[self.__uom[1:]]
                break

        req.setSubsetOfAttributes(
            [
                self.__x_min_fieldname,
                self._x_max_fieldname,
                self.__y_fieldname
            ],
            self.__layer.fields()
        )
        # Do not forget to add an index on this field to speed up ordering
        req.addOrderBy(self.__x_min_fieldname)

        def is_null(v):
            return isinstance(v, QVariant) and v.isNull()

        # do not include null values
        xy_values = [
            (f[self.__x_min_fieldname], f[self.__x_max_fieldname], f[self.__y_fieldname])
            for f in self.__layer.getFeatures(req)
            if not is_null(f[self.__y_fieldname])
        ]

        self.__x_values = [(coord[0], coord[1]) for coord in xy_values]
        self.__y_values = [coord[2] for coord in xy_values]

        self.__x_min = min((x[0] for x in self.__x_values)) \
            if self.__x_values else None
        self.__x_max = max((x[1] for x in self.__x_values)) \
            if self.__x_values else None
        self.__y_min, self.__y_max = (min(self.__y_values), max(self.__y_values)) \
            if self.__y_values else (None, None)

        self.data_modified.emit()
    """

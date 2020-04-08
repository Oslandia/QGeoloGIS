# -*- coding: utf-8 -*-
#
#   Copyright (C) 2020 Oslandia <infos@oslandia.com>
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

from qgis.core import QgsFeatureRequest

from .plot_view import PlotView

from .stratigraphy import StratigraphyItem
from .legend_item import LegendItem
from .imagery_data import ImageryDataItem

from .common import (
    ORIENTATION_HORIZONTAL,
    ORIENTATION_VERTICAL
)

class DepthPlotView(PlotView):
    def __init__(self):
        super().__init__(orientation=ORIENTATION_VERTICAL)

    def add_stratigraphy(self, layer, filter_expression, column_mapping, title, style_file=None, config=None, station_name=""):
        """Add stratigraphy data

        Parameters
        ----------
        layer: QgsVectorLayer
          The layer where stratigraphic data are stored
        filter_expression: str
          A QGIS expression to filter the vector layer
        column_mapping: dict
          Dictionary of column names
        title: str
          Title of the graph
        style_file: str
          Name of the style file to use
        config: PlotConfig
        station_name: str
        """
        symbology = config.get_symbology()[0] if config else None
        item = StratigraphyItem(self.DEFAULT_COLUMN_WIDTH,
                                self._scene.height(),
                                style_file=style_file if not symbology else None,
                                symbology=symbology,
                                column_mapping=column_mapping
        )
        item.style_updated.connect(self.styles_updated)
        legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH, title)

        item.set_layer(layer)
        item.tooltipRequested.connect(lambda txt: self.on_plot_tooltip(station_name, txt))

        req = QgsFeatureRequest()
        req.setFilterExpression(filter_expression)
        item.set_data(list(layer.getFeatures(req)))

        self._add_cell(item, legend_item)
        return item.min_depth(), item.max_depth()

    def add_imagery(self, image_filename, title, depth_from, depth_to):
        item = ImageryDataItem(self.DEFAULT_COLUMN_WIDTH,
                               self._scene.height(),
                               image_filename,
                               depth_from,
                               depth_to)
        
        legend_item = LegendItem(self.DEFAULT_COLUMN_WIDTH, title)

        self._add_cell(item, legend_item)
        return item.min_depth(), item.max_depth()

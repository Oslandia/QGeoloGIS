# QGeoloGIS plugin

This project allows the visualization of logs of drilling wells or boreholes and time series.

It is based on QT and the QGIS rendering engine to plot series of measurements. This allows:
- the use of the rich symbology engine of QGIS to display underground data
- having decent display performances, since QGIS is optimized to quickly render geometries possibly made of lots of points

Currently three types of data are handled:
- **stratigraphy** data, where a polygon is defined by a depth range and a pattern fill is given by a rock code
- **continuous series** of data that represent data sampled continuously underground (a sample every centimer for instance). This could also be reused to plot time series.
- **scatter plots** of data

![Example in a QGIS application](qgeologis.png)

See the [corresponding video](https://vimeo.com/303279452)

# How to use it as a standalone plugin

Install the plugin in the QGIS plugin directory and enable it. You can install it by typing `make deploy` in the main folder.

It requires a configuration that describes what is the base layer that displays measure points and how to access the different measure layers.

Some sample resources are available in the [sample folder](./sample). Apart from the small [toy dataset](./sample/qgeologistest.sql) itself, you can find an [example QGIS project file](sample/project.qgs) and the associated [configuration file](./sample/qgeologistest.json), which may be loaded from the plugin menu.

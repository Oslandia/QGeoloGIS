# QGIS Well log

This repository contains classes to provide well log widget inside QGis.

# How to use it

First you can add qgs_well_log as a depends of your project with a git submodule. Type this inside your main python module

```shell
git submodule add ssh://git@git.oslandia.net:10022/Oslandia-3d/qgis_well_log.git
```

Then you have to add this module in python path by editing your main *__init__.py* file
```python
import os
import sys

# append sub modules
sys.path.append(os.path.join(os.path.dirname(__file__),
                             "qgis_well_log"))

```

Finally you have to choose your interface *LayerData* or *FeatureData*, create a WellLogView object and add it to your application. See [main entry point](well_log/well_log_view.py) for examples.






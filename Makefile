# Install with QGIS3_PROFILE=xxx make deploy

PLUGIN_NAME=$(shell grep "^name" metadata.txt | cut -d'=' -f2)
VERSION=$(shell grep "^version" metadata.txt | cut -d'=' -f2)
ifeq ($(QGIS3_PROFILE),)
QGIS3_PROFILE=default
endif

SOURCES=__init__.py \
	qgis_plugin.py \
	metadata.txt \
	qgeologis/__init__.py \
	qgeologis/data_interface.py \
	qgeologis/imagery_data.py \
	qgeologis/legend_item.py \
	qgeologis/qt_qgis_compat.py \
	qgeologis/timeseries_view.py \
	qgeologis/common.py \
	qgeologis/time_scale.py \
	qgeologis/log_plot.py \
	qgeologis/log_view.py \
	qgeologis/z_scale.py \
	qgeologis/stratigraphy.py \
	qgeologis/img/*.svg \
	qgeologis/styles/*.svg \
	qgeologis/styles/*.xml

ZIP_FILE=$(PLUGIN_NAME)-$(VERSION).zip

QGIS2_PATH=~/.qgis2/python/plugins/$(PLUGIN_NAME)
QGIS3_PATH=~/.local/share/QGIS/QGIS3/profiles/$(QGIS3_PROFILE)/python/plugins/$(PLUGIN_NAME)

.PHONY = zip
zip: $(ZIP_FILE)

$(ZIP_FILE): $(SOURCES)
	zip $(ZIP_FILE) $(SOURCES)

deploy: $(ZIP_FILE)
	mkdir -p $(QGIS2_PATH)
	unzip -o $(ZIP_FILE) -d $(QGIS2_PATH)
	mkdir -p $(QGIS3_PATH)
	unzip -o $(ZIP_FILE) -d $(QGIS3_PATH)




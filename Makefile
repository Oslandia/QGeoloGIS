# Install with QGIS3_PROFILE=xxx make deploy

PLUGIN_NAME=$(shell grep "^name" metadata.txt | cut -d'=' -f2)
VERSION=$(shell grep "^version" metadata.txt | cut -d'=' -f2)
ifeq ($(QGIS3_PROFILE),)
QGIS3_PROFILE=default
endif

SOURCES=__init__.py \
	config.py \
	config_create_dialog.py \
	config_create_dialog.ui \
	configure_plot_dialog.py \
	configure_plot_dialog.ui \
	data_selector.py \
	main_dialog.py \
	qgis_plugin.py \
	metadata.txt \
	qgeologis

ZIP_FILE=$(PLUGIN_NAME)-$(VERSION).zip

QGIS3_PATH=~/.local/share/QGIS/QGIS3/profiles/$(QGIS3_PROFILE)/python/plugins/
PLUGIN_PATH=$(QGIS3_PATH)$(PLUGIN_NAME)

zip: deploy
	cd $(QGIS3_PATH) ; zip -9r $(CURDIR)/$(ZIP_FILE) $(PLUGIN_NAME)

deploy: 
	rm -rf $(PLUGIN_PATH)
	mkdir -p $(PLUGIN_PATH)
	cp -r $(SOURCES) $(PLUGIN_PATH)




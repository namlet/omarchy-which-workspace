QT_BIN ?= /usr/lib/qt6/bin
OMARCHY_PATH ?= /usr/share/omarchy

.PHONY: test test-js test-qml lint validate preview

test: test-js test-qml lint

# Layout, ordering and validation logic in plain JS, runs anywhere Node does.
test-js:
	node --test tests/

# The Quickshell-free components, headless.
test-qml:
	QT_QPA_PLATFORM=offscreen $(QT_BIN)/qmltestrunner -input tests

# BarWidget.qml is left out: qs.* and Quickshell types only resolve inside the
# running shell, so it is checked by the manual smoke test in AGENTS.md instead.
lint:
	@for f in manifest.json i18n/*.json; do \
		node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$$f" || { echo "invalid JSON: $$f"; exit 1; }; \
	done
	@for f in components/*.qml tests/*.qml tools/*.qml; do \
		$(QT_BIN)/qmllint --max-warnings 0 "$$f" || { echo "qmllint failed: $$f"; exit 1; }; \
	done

# Same checks the shell runs at load time. Needs an Omarchy install.
validate:
	omarchy plugin validate .

# The popup with made-up windows. PNG=out.png saves a picture instead of opening a window.
preview:
ifdef PNG
	QT_QPA_PLATFORM=offscreen $(QT_BIN)/qml tools/preview.qml -- --png $(abspath $(PNG))
else
	$(QT_BIN)/qml tools/preview.qml
endif

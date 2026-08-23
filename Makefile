# FleetWidget — build and run
#
# Toolchain note: this package targets Swift 5.6 (Xcode 13.4.1). Avoid syntax
# introduced in 5.7+ (`if let x {` shorthand, regex literals, Duration/Clock).

APP_NAME  := FleetWidget
BUILD_DIR := .build
APP       := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := /Applications
ICONSET   := $(BUILD_DIR)/AppIcon.iconset
ICNS      := $(BUILD_DIR)/AppIcon.icns

.PHONY: all build release test selftest verify run icon app install-run install uninstall clean

all: build

## Debug build
build:
	swift build

## Optimized build
release:
	swift build -c release

## Unit tests (FleetWidgetCore only — no AppKit required)
test:
	swift test

## Checks the header controls are reachable. Their hit regions depend on runtime
## font metrics, which the headless core tests cannot see.
selftest: build
	./$(BUILD_DIR)/debug/$(APP_NAME) --self-test-interaction

## Everything that can be checked without a human at the screen
verify: test selftest

## Run straight from the build products, no bundle.
## Activation policy is set in code, so there is still no Dock icon.
run:
	swift run $(APP_NAME)

## Generate the app icon from the same pixel bitmap the header uses
icon: build
	./$(BUILD_DIR)/debug/$(APP_NAME) --render-iconset "$(ICONSET)"
	iconutil -c icns "$(ICONSET)" -o "$(ICNS)"

## Assemble a launchable .app bundle
app: release icon
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BUILD_DIR)/release/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp "$(ICNS)" "$(APP)/Contents/Resources/AppIcon.icns"
	@echo "Built $(APP)"

## Build the bundle and launch it
install-run: app
	open "$(APP)"

## Copy the bundle to /Applications so it survives `make clean` and is
## reachable from Spotlight and Finder like any other app.
install: app
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed $(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Removed $(INSTALL_DIR)/$(APP_NAME).app"

clean:
	rm -rf $(BUILD_DIR)

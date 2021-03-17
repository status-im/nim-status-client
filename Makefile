# Copyright (c) 2019-2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

SHELL := bash # the shell used internally by Make

# used inside the included makefiles
BUILD_SYSTEM_DIR := vendor/nimbus-build-system

# we don't want an error here, so we can handle things later, in the ".DEFAULT" target
-include $(BUILD_SYSTEM_DIR)/makefiles/variables.mk

.PHONY: \
	all \
	bottles \
	bottles-dummy \
	bottles-macos \
	check-pkg-target-linux \
	check-pkg-target-macos \
	check-pkg-target-windows \
	clean \
	deps \
	fleets-remove \
	fleets-update \
	nim_status_client \
	nim_windows_launcher \
	pkg \
	pkg-linux \
	pkg-macos \
	pkg-windows \
	run \
	run-linux \
	run-macos \
	run-windows \
	set-status-macos-dev-icon \
	status-go \
	update

ifeq ($(NIM_PARAMS),)
# "variables.mk" was not included, so we update the submodules.
GIT_SUBMODULE_UPDATE := git submodule update --init --recursive
.DEFAULT:
	+@ echo -e "Git submodules not found. Running '$(GIT_SUBMODULE_UPDATE)'.\n"; \
		$(GIT_SUBMODULE_UPDATE); \
		echo
# Now that the included *.mk files appeared, and are newer than this file, Make will restart itself:
# https://www.gnu.org/software/make/manual/make.html#Remaking-Makefiles
#
# After restarting, it will execute its original goal, so we don't have to start a child Make here
# with "$(MAKE) $(MAKECMDGOALS)". Isn't hidden control flow great?

else # "variables.mk" was included. Business as usual until the end of this file.

all: nim_status_client

# must be included after the default target
-include $(BUILD_SYSTEM_DIR)/makefiles/targets.mk

ifeq ($(OS),Windows_NT)     # is Windows_NT on XP, 2000, 7, Vista, 10...
 detected_OS := Windows
else
 detected_OS := $(strip $(shell uname))
endif

ifeq ($(detected_OS),Darwin)
 BOTTLES_TARGET := bottles-macos
 CFLAGS := -mmacosx-version-min=10.13
 export CFLAGS
 CGO_CFLAGS := -mmacosx-version-min=10.13
 export CGO_CFLAGS
 LIBSTATUS_EXT := dylib
 MACOSX_DEPLOYMENT_TARGET := 10.13
 export MACOSX_DEPLOYMENT_TARGET
 PKG_TARGET := pkg-macos
 RUN_TARGET := run-macos
else ifeq ($(detected_OS),Windows)
 BOTTLES_TARGET := bottles-dummy
 LIBSTATUS_EXT := dll
 PKG_TARGET := pkg-windows
 QRCODEGEN_MAKE_PARAMS := CC=gcc
 RUN_TARGET := run-windows
 SIGNTOOL ?= C:\\Program Files (x86)\\Windows Kits\\10\\bin\\10.0.17763.0\\x64\\signtool.exe
 VCINSTALLDIR ?= C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\BuildTools\\VC\\
 export VCINSTALLDIR
else
 BOTTLES_TARGET := bottles-dummy
 LIBSTATUS_EXT := so
 PKG_TARGET := pkg-linux
 RUN_TARGET := run-linux
endif

check-pkg-target-linux:
ifneq ($(detected_OS),Linux)
	$(error The pkg-linux target must be run on Linux)
endif

check-pkg-target-macos:
ifneq ($(detected_OS),Darwin)
	$(error The pkg-macos target must be run on macOS)
endif

check-pkg-target-windows:
ifneq ($(detected_OS),Windows)
	$(error The pkg-windows target must be run on Windows)
endif

bottles: $(BOTTLES_TARGET)

bottles-dummy: ;

BOTTLE_OPENSSL := bottles/openssl/INSTALL_RECEIPT.json

$(BOTTLE_OPENSSL):
	echo -e "\e[92mFetching:\e[39m bottles for macOS"
	rm -rf bottles/Downloads/openssl* bottles/openssl*
	mkdir -p bottles/Downloads
	cd bottles/Downloads && \
	wget -O openssl.tar.gz "https://bintray.com/homebrew/bottles/download_file?file_path=openssl%401.1-1.1.1g.high_sierra.bottle.tar.gz" && \
	tar xzf openssl* && \
	mv openssl@1.1/1.1.1g ../openssl

BOTTLE_PCRE := bottles/pcre/INSTALL_RECEIPT.json

$(BOTTLE_PCRE):
	rm -rf bottles/Downloads/pcre* bottles/pcre*
	mkdir -p bottles/Downloads
	cd bottles/Downloads && \
	wget -O pcre.tar.gz "https://bintray.com/homebrew/bottles/download_file?file_path=pcre-8.44.high_sierra.bottle.tar.gz" && \
	tar xzf pcre* && \
	mv pcre/8.44 ../pcre

bottles-macos: | $(BOTTLE_OPENSSL) $(BOTTLE_PCRE)
	rm -rf bottles/Downloads

deps: | deps-common bottles

update: | update-common

# Qt5 dirs (we can't indent with tabs here)
ifneq ($(detected_OS),Windows)
 QT5_PCFILEDIR := $(shell pkg-config --variable=pcfiledir Qt5Core 2>/dev/null)
 QT5_LIBDIR := $(shell pkg-config --variable=libdir Qt5Core 2>/dev/null)
 ifeq ($(QT5_PCFILEDIR),)
  ifeq ($(QTDIR),)
   $(error Cannot find your Qt5 installation. Please run "$(MAKE) QTDIR=/path/to/your/Qt5/installation/prefix ...")
  else
   QT5_PCFILEDIR := $(QTDIR)/lib/pkgconfig
   QT5_LIBDIR := $(QTDIR)/lib
   # some manually installed Qt5 instances have wrong paths in their *.pc files, so we pass the right one to the linker here
   ifeq ($(detected_OS),Darwin)
    NIM_PARAMS += -L:"-framework Foundation -framework Security -framework IOKit -framework CoreServices"
    # Fix for failures due to 'can't allocate code signature data for'
    NIM_PARAMS += --passL:"-headerpad_max_install_names"
    NIM_PARAMS += --passL:"-F$(QT5_LIBDIR)"
    export QT5_LIBDIR
   else
    NIM_PARAMS += --passL:"-L$(QT5_LIBDIR)"
   endif
  endif
 endif
 DOTHERSIDE := vendor/DOtherSide/build/lib/libDOtherSideStatic.a
 DOTHERSIDE_CMAKE_PARAMS := -DENABLE_DYNAMIC_LIBS=OFF -DENABLE_STATIC_LIBS=ON
 DOTHERSIDE_BUILD_CMD := $(MAKE) VERBOSE=$(V) $(HANDLE_OUTPUT)
 # order matters here, due to "-Wl,-as-needed"
 NIM_PARAMS += --passL:"$(DOTHERSIDE)" --passL:"$(shell PKG_CONFIG_PATH="$(QT5_PCFILEDIR)" pkg-config --libs Qt5Core Qt5Qml Qt5Gui Qt5Quick Qt5QuickControls2 Qt5Widgets Qt5Svg)"
else
 DOTHERSIDE := vendor/DOtherSide/build/lib/Release/DOtherSide.dll
 DOTHERSIDE_CMAKE_PARAMS := -T"v141" -A x64 -DENABLE_DYNAMIC_LIBS=ON -DENABLE_STATIC_LIBS=OFF
 DOTHERSIDE_BUILD_CMD := cmake --build . --config Release $(HANDLE_OUTPUT)
 NIM_PARAMS += -L:$(DOTHERSIDE)
 NIM_EXTRA_PARAMS := --passL:"-lsetupapi -lhid"
endif

# TODO: control debug/release builds with a Make var
# We need `-d:debug` to get Nim's default stack traces.
NIM_PARAMS += --outdir:./bin -d:debug
# Enable debugging symbols in DOtherSide, in case we need GDB backtraces from it.
CFLAGS += -g
CXXFLAGS += -g

# TODO: control debug/release builds with a Make var
$(DOTHERSIDE): | deps
	echo -e $(BUILD_MSG) "DOtherSide"
	+ cd vendor/DOtherSide && \
		mkdir -p build && \
		cd build && \
		rm -f CMakeCache.txt && \
		cmake $(DOTHERSIDE_CMAKE_PARAMS) \
			-DCMAKE_BUILD_TYPE=Debug \
			-DENABLE_DOCS=OFF \
			-DENABLE_TESTS=OFF \
			.. $(HANDLE_OUTPUT) && \
		$(DOTHERSIDE_BUILD_CMD)

STATUSGO := vendor/status-go/build/bin/libstatus.$(LIBSTATUS_EXT)
STATUSGO_LIBDIR := $(shell pwd)/$(shell dirname "$(STATUSGO)")
export STATUSGO_LIBDIR

status-go: $(STATUSGO)
$(STATUSGO): | deps
	echo -e $(BUILD_MSG) "status-go"
	+ cd vendor/status-go && \
	  $(MAKE) statusgo-shared-library $(HANDLE_OUTPUT)

QRCODEGEN := vendor/QR-Code-generator/c/libqrcodegen.a

$(QRCODEGEN): | deps
	echo -e $(BUILD_MSG) "QR-Code-generator"
	+ cd vendor/QR-Code-generator/c && \
	  $(MAKE) $(QRCODEGEN_MAKE_PARAMS)

FLEETS := fleets.json
$(FLEETS):
	echo -e $(BUILD_MSG) "Getting latest $(FLEETS)"
	curl -s https://fleets.status.im/ \
		| jq --indent 4 --sort-keys . \
		> $(FLEETS)

fleets-remove:
	rm -f $(FLEETS)

fleets-update: fleets-remove $(FLEETS)

rcc:
	echo -e $(BUILD_MSG) "resources.rcc"
	rm -f ./resources.rcc
	rm -f ./ui/resources.qrc
	./ui/generate-rcc.sh
	rcc -binary ui/resources.qrc -o ./resources.rcc

# default token is a free-tier token with limited capabilities and usage
# limits; our docs should include directions for community contributor to setup
# their own Infura account and token instead of relying on this default token
# during development
DEFAULT_TOKEN := 220a1abb4b6943a093c35d0ce4fb0732
INFURA_TOKEN ?= $(DEFAULT_TOKEN)
NIM_PARAMS += -d:INFURA_TOKEN:"$(INFURA_TOKEN)"

nim_status_client: | $(DOTHERSIDE) $(STATUSGO) $(QRCODEGEN) $(FLEETS) rcc deps
	echo -e $(BUILD_MSG) "$@" && \
		$(ENV_SCRIPT) nim c $(NIM_PARAMS) --passL:"-L$(STATUSGO_LIBDIR)" --passL:"-lstatus" $(NIM_EXTRA_PARAMS) --passL:"$(QRCODEGEN)" --passL:"-lm" src/nim_status_client.nim && \
		[[ $$? = 0 ]] && \
		(([[ $(detected_OS) = Darwin ]] && \
		install_name_tool -change \
			libstatus.dylib \
			@rpath/libstatus.dylib \
			bin/nim_status_client) || true)

_APPIMAGE_TOOL := appimagetool-x86_64.AppImage
APPIMAGE_TOOL := tmp/linux/tools/$(_APPIMAGE_TOOL)

$(APPIMAGE_TOOL):
	echo -e "\e[92mFetching:\e[39m appimagetool"
	rm -rf tmp/linux
	mkdir -p tmp/linux/tools
	wget https://github.com/AppImage/AppImageKit/releases/download/continuous/$(_APPIMAGE_TOOL)
	mv $(_APPIMAGE_TOOL) tmp/linux/tools/
	chmod +x $(APPIMAGE_TOOL)

STATUS_CLIENT_APPIMAGE ?= pkg/NimStatusClient-x86_64.AppImage

$(STATUS_CLIENT_APPIMAGE): nim_status_client $(APPIMAGE_TOOL) nim-status.desktop
	rm -rf pkg/*.AppImage
	rm -rf tmp/linux/dist
	mkdir -p tmp/linux/dist/usr/bin
	mkdir -p tmp/linux/dist/usr/lib
	mkdir -p tmp/linux/dist/usr/qml

	# General Files
	cp bin/nim_status_client tmp/linux/dist/usr/bin
	cp nim-status.desktop tmp/linux/dist/.
	cp status.svg tmp/linux/dist/status.svg
	cp status.svg tmp/linux/dist/usr/.
	cp -R resources.rcc tmp/linux/dist/usr/.
	cp -R $(FLEETS) tmp/linux/dist/usr/.
	mkdir -p tmp/linux/dist/usr/i18n
	cp ui/i18n/* tmp/linux/dist/usr/i18n

	# Libraries
	cp -r /usr/lib/x86_64-linux-gnu/nss tmp/linux/dist/usr/lib/
	cp vendor/status-go/build/bin/libstatus.so tmp/linux/dist/usr/lib/

	echo -e $(BUILD_MSG) "AppImage"
	linuxdeployqt tmp/linux/dist/nim-status.desktop -no-copy-copyright-files -qmldir=ui -qmlimport=$(QTDIR)/qml -bundle-non-qt-libs

	rm tmp/linux/dist/AppRun
	cp AppRun tmp/linux/dist/.

	mkdir -p pkg
	$(APPIMAGE_TOOL) tmp/linux/dist $(STATUS_CLIENT_APPIMAGE)

DMG_TOOL := node_modules/.bin/create-dmg

$(DMG_TOOL):
	echo -e "\e[92mInstalling:\e[39m create-dmg"
	npm i

MACOS_OUTER_BUNDLE := tmp/macos/dist/Status.app
MACOS_INNER_BUNDLE := $(MACOS_OUTER_BUNDLE)/Contents/Frameworks/QtWebEngineCore.framework/Versions/Current/Helpers/QtWebEngineProcess.app

STATUS_CLIENT_DMG ?= pkg/Status.dmg

$(STATUS_CLIENT_DMG): nim_status_client $(DMG_TOOL)
	rm -rf tmp/macos pkg/*.dmg
	mkdir -p $(MACOS_OUTER_BUNDLE)/Contents/MacOS
	mkdir -p $(MACOS_OUTER_BUNDLE)/Contents/Resources
	cp Info.plist $(MACOS_OUTER_BUNDLE)/Contents/
	cp bin/nim_status_client $(MACOS_OUTER_BUNDLE)/Contents/MacOS/
	cp nim_status_client.sh $(MACOS_OUTER_BUNDLE)/Contents/MacOS/
	chmod +x $(MACOS_OUTER_BUNDLE)/Contents/MacOS/nim_status_client.sh
	cp status.icns $(MACOS_OUTER_BUNDLE)/Contents/Resources/
	cp status.svg $(MACOS_OUTER_BUNDLE)/Contents/
	cp -R resources.rcc $(MACOS_OUTER_BUNDLE)/Contents/
	cp -R $(FLEETS) $(MACOS_OUTER_BUNDLE)/Contents/
	mkdir -p $(MACOS_OUTER_BUNDLE)/Contents/i18n
	cp ui/i18n/* $(MACOS_OUTER_BUNDLE)/Contents/i18n

	echo -e $(BUILD_MSG) "app"
	macdeployqt \
		$(MACOS_OUTER_BUNDLE) \
		-executable=$(MACOS_OUTER_BUNDLE)/Contents/MacOS/nim_status_client \
		-qmldir=ui
	cp Info.runner.plist $(MACOS_OUTER_BUNDLE)/Contents/Info.plist
	macdeployqt \
		$(MACOS_INNER_BUNDLE) \
		-executable=$(MACOS_INNER_BUNDLE)/Contents/MacOS/QtWebEngineProcess

	# if MACOS_CODESIGN_IDENT is not set then the outer and inner .app
	# bundles are not signed
ifdef MACOS_CODESIGN_IDENT
	scripts/sign-macos-pkg.sh $(MACOS_OUTER_BUNDLE) $(MACOS_CODESIGN_IDENT)
	scripts/sign-macos-pkg.sh $(MACOS_INNER_BUNDLE) $(MACOS_CODESIGN_IDENT) \
		--entitlements QtWebEngineProcess.plist
endif
	echo -e $(BUILD_MSG) "dmg"
	mkdir -p pkg
	# See: https://github.com/sindresorhus/create-dmg#dmg-icon
	# GraphicsMagick must be installed for create-dmg to make the custom
	# DMG icon based on app icon, but should otherwise work without it
	npx create-dmg \
		--identity="NOBODY" \
		$(MACOS_OUTER_BUNDLE) \
		pkg || true
	# We ignore failure above create-dmg can't skip signing.
	# To work around that a dummy identity - 'NOBODY' - is specified.
	# This causes non-zero exit code despite DMG being created.
	# It is just not signed, hence the next command should succeed.
	mv "`ls pkg/*.dmg`" $(STATUS_CLIENT_DMG)

ifdef MACOS_CODESIGN_IDENT
	scripts/sign-macos-pkg.sh $(STATUS_CLIENT_DMG) $(MACOS_CODESIGN_IDENT)
endif

NIM_WINDOWS_PREBUILT_DLLS ?= tmp/windows/tools/pcre.dll

$(NIM_WINDOWS_PREBUILT_DLLS):
	echo -e "\e[92mFetching:\e[39m prebuilt DLLs from nim-lang.org"
	rm -rf tmp/windows
	mkdir -p tmp/windows/tools
	cd tmp/windows/tools && \
	wget https://nim-lang.org/download/dlls.zip && \
	unzip dlls.zip

nim_windows_launcher: | deps
	$(ENV_SCRIPT) nim c -d:debug --outdir:./bin --passL:"-static-libgcc -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive" src/nim_windows_launcher.nim

ifneq ($(WINDOWS_CODESIGN_TIMESTAMP_URL),)
 WINDOWS_CODESIGN_TIMESTAMP_PARAM := -t $(WINDOWS_CODESIGN_TIMESTAMP_URL)
endif

STATUS_CLIENT_ZIP ?= pkg/Status.zip

$(STATUS_CLIENT_ZIP): nim_status_client nim_windows_launcher $(NIM_WINDOWS_PREBUILT_DLLS)
	rm -rf pkg/*.zip
	rm -rf tmp/windows/dist
	mkdir -p tmp/windows/dist/Status/bin
	mkdir -p tmp/windows/dist/Status/resources
	mkdir -p tmp/windows/dist/Status/vendor
	cp windows-install.txt tmp/windows/dist/Status/INSTALL.txt
	unix2dos -k tmp/windows/dist/Status/INSTALL.txt
	# cp LICENSE tmp/windows/dist/Status/LICENSE.txt
	# unix2dos -k tmp/windows/dist/Status/LICENSE.txt
	cp status.ico tmp/windows/dist/Status/resources/
	cp status.svg tmp/windows/dist/Status/resources/
	cp resources.rcc tmp/windows/dist/Status/resources/
	cp $(FLEETS) tmp/windows/dist/Status/resources/
	cp bin/nim_status_client.exe tmp/windows/dist/Status/bin/Status.exe
	cp bin/nim_windows_launcher.exe tmp/windows/dist/Status/Status.exe
	rcedit \
		tmp/windows/dist/Status/bin/Status.exe \
		--set-icon tmp/windows/dist/Status/resources/status.ico
	rcedit \
		tmp/windows/dist/Status/Status.exe \
		--set-icon tmp/windows/dist/Status/resources/status.ico
	cp $(DOTHERSIDE) tmp/windows/dist/Status/bin/
	cp $(STATUSGO) tmp/windows/dist/Status/bin/
	cp tmp/windows/tools/*.dll tmp/windows/dist/Status/bin/
	mkdir -p tmp/windows/dist/Status/resources/i18n
	cp ui/i18n/* tmp/windows/dist/Status/resources/i18n
	cp "$(shell which libgcc_s_seh-1.dll)" tmp/windows/dist/Status/bin/
	cp "$(shell which libwinpthread-1.dll)" tmp/windows/dist/Status/bin/

	echo -e $(BUILD_MSG) "deployable folder"
	windeployqt \
		--compiler-runtime \
		--qmldir ui \
		--release \
		tmp/windows/dist/Status/bin/DOtherSide.dll
	mv tmp/windows/dist/Status/bin/vc_redist.x64.exe tmp/windows/dist/Status/vendor/

	# if WINDOWS_CODESIGN_PFX_PATH is not set then DLLs, EXEs are not signed
ifdef WINDOWS_CODESIGN_PFX_PATH
	find ./tmp/windows/dist/Status -type f \
		| /usr/bin/egrep -i "\.(dll|exe)$$" \
		| /usr/bin/xargs -I{} /usr/bin/bash -c \
			"if ! '$(SIGNTOOL)' verify -pa {} &>/dev/null; then echo {}; fi" \
		| /usr/bin/xargs -I{} "$(SIGNTOOL)" \
			sign \
			-v \
			-f $(WINDOWS_CODESIGN_PFX_PATH) \
			$(WINDOWS_CODESIGN_TIMESTAMP_PARAM) \
			{}
endif

	echo -e $(BUILD_MSG) "zip"
	mkdir -p pkg
	cd tmp/windows/dist/Status && \
	7z a ../../../../$(STATUS_CLIENT_ZIP) *

pkg: $(PKG_TARGET)

pkg-linux: check-pkg-target-linux $(STATUS_CLIENT_APPIMAGE)

pkg-macos: check-pkg-target-macos $(STATUS_CLIENT_DMG)

pkg-windows: check-pkg-target-windows $(STATUS_CLIENT_ZIP)

clean: | clean-common
	rm -rf bin/* node_modules pkg/* tmp/* $(STATUSGO)
	+ $(MAKE) -C vendor/DOtherSide/build --no-print-directory clean

run: rcc $(RUN_TARGET)

ICON_TOOL := node_modules/.bin/fileicon

$(ICON_TOOL):
	echo -e "\e[92mInstalling:\e[39m fileicon"
	npm i

NIM_STATUS_CLIENT_DEV ?= t
STATUS_PORT ?= 30306

set-status-macos-dev-icon: $(ICON_TOOL)
	npx fileicon set bin/nim_status_client status-dev.icns

run-linux:
	echo -e "\e[92mRunning:\e[39m bin/nim_status_client"
	NIM_STATUS_CLIENT_DEV="$(NIM_STATUS_CLIENT_DEV)" \
	LD_LIBRARY_PATH="$(QT5_LIBDIR)":"$(STATUSGO_LIBDIR)" \
	STATUS_PORT="$(STATUS_PORT)" \
	./bin/nim_status_client

run-macos: set-status-macos-dev-icon
	echo -e "\e[92mRunning:\e[39m bin/nim_status_client"
	NIM_STATUS_CLIENT_DEV="$(NIM_STATUS_CLIENT_DEV)" \
	STATUS_PORT="$(STATUS_PORT)" \
	./bin/nim_status_client

run-windows: $(NIM_WINDOWS_PREBUILT_DLLS)
	echo -e "\e[92mRunning:\e[39m bin/nim_status_client.exe"
	NIM_STATUS_CLIENT_DEV="$(NIM_STATUS_CLIENT_DEV)" \
	PATH="$(shell pwd)"/"$(shell dirname "$(DOTHERSIDE)")":"$(STATUSGO_LIBDIR)":"$(shell pwd)"/"$(shell dirname "$(NIM_WINDOWS_PREBUILT_DLLS)")":"$(PATH)" \
	STATUS_PORT="$(STATUS_PORT)" \
	./bin/nim_status_client.exe

endif # "variables.mk" was not included

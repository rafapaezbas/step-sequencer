RAYLIB = $(shell brew --prefix raylib)
PORTMIDI = $(shell brew --prefix portmidi)

ifeq ($(OS),Windows_NT)
PLATFORM := windows
ARCH ?= x86_64
EXE := .exe
else
PLATFORM := $(shell uname -s | tr A-Z a-z)
ARCH ?= $(shell uname -m)
EXE :=
endif

SRC := main.c midi.c
BIN := build/step-sequencer$(EXE)
APP := build/StepSequencer.app

DEPS := $(abspath build/deps/$(PLATFORM)-$(ARCH))
DEPLOYMENT_TARGET := 11.0
RAYLIB_VERSION := 6.0
PORTMIDI_VERSION := v2.0.7

compile: | build
	gcc -Wall -Werror -Wpedantic -o $(BIN) $(SRC) -isystem . \
		-I$(RAYLIB)/include -L$(RAYLIB)/lib -lraylib \
		-I$(PORTMIDI)/include -L$(PORTMIDI)/lib -lportmidi -lpthread

ifeq ($(PLATFORM),darwin)
RELEASE_FLAGS := -arch $(ARCH) -mmacosx-version-min=$(DEPLOYMENT_TARGET)
RELEASE_LIBS := -framework Cocoa -framework IOKit -framework CoreVideo -framework OpenGL \
	-framework CoreMIDI -framework CoreAudio -framework CoreFoundation -framework CoreServices \
	-lpthread
CMAKE_PLATFORM_FLAGS := -DCMAKE_OSX_DEPLOYMENT_TARGET=$(DEPLOYMENT_TARGET) -DCMAKE_OSX_ARCHITECTURES=$(ARCH)
else ifeq ($(PLATFORM),linux)
RELEASE_FLAGS :=
RELEASE_LIBS := -lGL -lm -lpthread -ldl -lrt -lX11 -lasound
CMAKE_PLATFORM_FLAGS :=
else ifeq ($(PLATFORM),windows)
RELEASE_FLAGS := -mwindows -static
RELEASE_LIBS := -lopengl32 -lgdi32 -lwinmm -lpthread
CMAKE_PLATFORM_FLAGS :=
endif

release: deps | build
	gcc -Wall -Werror -Wpedantic -O2 $(RELEASE_FLAGS) -o $(BIN) $(SRC) -isystem . \
		-isystem $(DEPS)/include $(DEPS)/lib/libraylib.a $(DEPS)/lib/libportmidi.a \
		$(RELEASE_LIBS)

deps: $(DEPS)/lib/libraylib.a $(DEPS)/lib/libportmidi.a

$(DEPS)/lib/libraylib.a:
	rm -rf build/src/raylib
	git clone --depth 1 --branch $(RAYLIB_VERSION) https://github.com/raysan5/raylib.git build/src/raylib
	cmake -S build/src/raylib -B build/src/raylib/build \
		-DCMAKE_BUILD_TYPE=Release $(CMAKE_PLATFORM_FLAGS) -DCMAKE_INSTALL_PREFIX=$(DEPS) \
		-DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF
	cmake --build build/src/raylib/build --target install

$(DEPS)/lib/libportmidi.a:
	rm -rf build/src/portmidi
	git clone --depth 1 --branch $(PORTMIDI_VERSION) https://github.com/PortMidi/portmidi.git build/src/portmidi
	cmake -S build/src/portmidi -B build/src/portmidi/build \
		-DCMAKE_BUILD_TYPE=Release $(CMAKE_PLATFORM_FLAGS) -DCMAKE_INSTALL_PREFIX=$(DEPS) \
		-DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=OFF
	cmake --build build/src/portmidi/build --target install

app: release build/icon.icns
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/
	cp Info.plist $(APP)/Contents/
	cp build/icon.icns $(APP)/Contents/Resources/

build/icon.icns: icon.png | build
	rm -rf build/icon.iconset
	mkdir build/icon.iconset
	for s in 16 32 128 256 512; do \
		sips -z $$s $$s icon.png --out build/icon.iconset/icon_$${s}x$${s}.png > /dev/null; \
		sips -z $$((s * 2)) $$((s * 2)) icon.png --out build/icon.iconset/icon_$${s}x$${s}@2x.png > /dev/null; \
	done
	iconutil -c icns build/icon.iconset -o $@

run: compile
	./$(BIN)

build:
	mkdir -p build

format:
	clang-format -i *.c *.h

.PHONY: compile release deps app run format

# Makefile for dlGrep (GNU make, Windows).  Replaces rebuild.cmd.
#
#   make            build everything (stops a running dlGrep first)
#   make test       build, then run the unit tests
#   make run        build, then start dlGrep
#   make clean      remove build output
#   make help       list the targets
#
# The C++ project (dnGREP.ContextMenu) is not part of this build, which is why this
# builds the projects one by one instead of building the whole solution.

PYTHON  ?= python
CONFIG  ?= Debug
PLATFORM ?= x64
APP     := dlGrep

# MSBuild wants the folder of this Makefile as a Windows path ending in a slash.
# Cygwin/MSYS make report CURDIR as /cygdrive/d/... or /d/...; convert those.
ifneq ($(filter /%,$(CURDIR)),)
ROOT := $(shell cygpath -m '$(CURDIR)')
else
ROOT := $(CURDIR)
endif
SD := $(ROOT)/

DOTNET_FLAGS := -c $(CONFIG) -p:Platform=$(PLATFORM) -p:SolutionDir="$(SD)"

ENGINES := dnGREP.OpenXmlEngine/dnGREP.OpenXmlEngine.csproj \
           dnGREP.PdfEngine/dnGREP.PdfEngine.csproj \
           dnGREP.WordEngine/dnGREP.WordEngine.csproj
WPF     := dnGREP.WPF/dnGREP.WPF.csproj
EXE     := dnGREP.WPF/bin/$(PLATFORM)/$(CONFIG)/net10.0-windows/$(APP).exe
CLEANS  := $(addprefix clean/,$(ENGINES) $(WPF))

.PHONY: all build stop engines wpf test run clean help $(ENGINES) $(CLEANS)

all: build

help:
	@echo "make         build everything"
	@echo "make test    build, then run the unit tests"
	@echo "make run     build, then start $(APP)"
	@echo "make stop    stop a running $(APP)"
	@echo "make clean   remove build output"

build: wpf

# the exe cannot be replaced while it is running; this stops it only if it is running
stop:
	@$(PYTHON) tools/stop_app.py $(APP)

engines: $(ENGINES)

# one rule for the three engine projects (no shell loop, so it works with any shell)
$(ENGINES): stop
	dotnet build $@ $(DOTNET_FLAGS)

wpf: engines
	dotnet build $(WPF) $(DOTNET_FLAGS)

test: build
	dotnet test --project Tests/Tests.csproj -p:Platform=$(PLATFORM)

run: build
	cmd /c start "" "$(subst /,\,$(EXE))"

clean: $(CLEANS)

$(CLEANS): clean/%:
	dotnet clean $* $(DOTNET_FLAGS)

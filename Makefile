# Makefile for dlGrep (GNU make, Windows).  Replaces rebuild.cmd.
#
#   make            build everything (stops a running dlGrep first)
#   make test       build, then run the unit tests
#   make run        build, then start dlGrep
#   make installer  build a Release exe, then the Inno Setup installer
#   make install    install silently with the setup that "make installer" built (builds nothing)
#   make version    show the version (the newest "## [x.yy]" header in CHANGELOG.md)
#   make dist       installer, zipped for upload
#   make release    first release of this version: tag, push, create the GitHub release
#   make update     refresh the release notes and the uploaded zip of an existing release
#   make retag      move the tag to HEAD (solo repo only);  make re-release = retag + update
#   make clean      remove build output
#   make help       list the targets
#
# The C++ project (dnGREP.ContextMenu) is not part of this build, which is why this
# builds the projects one by one instead of building the whole solution.

PYTHON  ?= python
CONFIG  ?= Debug
PLATFORM ?= x64
ISCC    ?= D:/InnoSetup7/iscc.exe
GH_REPO ?= DerellLicht/dlGrep
APP     := dlGrep

# The version lives only in CHANGELOG.md: the newest "## [x.yy]" header, for example 1.00.
# MSBuild reads the same header (see Directory.Build.props) for the assembly and About-dialog
# version; this copy feeds the installer, the tag and the GitHub release.
VERSION := $(shell grep -E '^## \[[0-9]+\.[0-9]+\]' CHANGELOG.md | head -n 1 | grep -oE '[0-9]+\.[0-9]+')
ifeq ($(VERSION),)
$(error no "## [x.yy]" version header found in CHANGELOG.md)
endif
TAG       = v$(VERSION)
SETUP     = installer/output/$(APP)V$(VERSION).setup.exe
SETUP_ZIP = installer/output/$(APP)V$(VERSION).setup.zip

# MSBuild wants the folder of this Makefile as a Windows path ending in a slash.
# Cygwin/MSYS make report CURDIR as /cygdrive/d/... or /d/...; convert those.
ifneq ($(filter /%,$(CURDIR)),)
ROOT := $(shell cygpath -m '$(CURDIR)')
else
ROOT := $(CURDIR)
endif
SD := $(ROOT)/

DOTNET_FLAGS = -c $(CONFIG) -p:Platform=$(PLATFORM) -p:SolutionDir="$(SD)"

ENGINES := dnGREP.OpenXmlEngine/dnGREP.OpenXmlEngine.csproj \
           dnGREP.PdfEngine/dnGREP.PdfEngine.csproj \
           dnGREP.WordEngine/dnGREP.WordEngine.csproj
WPF     := dnGREP.WPF/dnGREP.WPF.csproj
EXE     = dnGREP.WPF/bin/$(PLATFORM)/$(CONFIG)/net10.0-windows/$(APP).exe
CLEANS  := $(addprefix clean/,$(ENGINES) $(WPF))

.PHONY: all build stop engines wpf test run version installer install dist release update retag re-release check-clean sha256 clean help $(ENGINES) $(CLEANS)

all: build

help:
	@echo "make         build everything"
	@echo "make test    build, then run the unit tests"
	@echo "make run     build, then start $(APP)"
	@echo "make installer  build a Release exe and the installer ($(SETUP))"
	@echo "make install    install the built setup silently, no questions (builds nothing)"
	@echo "make version    show the version from CHANGELOG.md ($(VERSION))"
	@echo "make dist       the installer, zipped for upload"
	@echo "make release    first release of $(TAG): tag, push, GitHub release"
	@echo "make update     refresh the notes and zip of an existing release"
	@echo "make retag      move $(TAG) to HEAD;  make re-release = retag + update"
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

# The installer always packages a Release build; the target-specific CONFIG below also applies
# to everything installer depends on, so "make installer" does not disturb your Debug output.
installer: CONFIG := Release
installer: build
	"$(ISCC)" /Qp /DMyAppVersion=$(VERSION) installer/dlGrep.iss

# Only runs the setup program that "make installer" already built; it does not build anything.
# Silent: no wizard and no questions (an open dlGrep is closed first).  Setup then does not offer
# to start dlGrep; use "make run" or the Start Menu.
install:
	@test -f "$(SETUP)" || { echo "$(SETUP) not found -- run 'make installer' first."; exit 1; }
	"$(SETUP)" /SILENT /SUPPRESSMSGBOXES /NORESTART

version:
	@echo $(VERSION)

dist: installer
	zip -j $(SETUP_ZIP) $(SETUP)

sha256:
	certutil -hashfile $(subst /,\,$(SETUP_ZIP)) SHA256

# Refuses to release from a tree with uncommitted changes, so the tag matches what was built.
check-clean:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "ERROR: uncommitted changes present -- commit before releasing."; \
		git status --short; \
		exit 1; \
	fi

# First release of a version: tag HEAD, push the tag, create the GitHub release with the notes
# from CHANGELOG.md and the zipped installer.  Fails at "git tag" if the tag already exists;
# use "make update" for that.  Needs the gh CLI, signed in.
release: check-clean dist
	@echo Preparing GitHub release $(TAG)...
	$(PYTHON) tools/release_notes.py $(VERSION) > temp_notes.md
	git tag $(TAG)
	git push origin $(TAG)
	gh release create $(TAG) $(SETUP_ZIP) --title "$(TAG)" --notes-file temp_notes.md -R $(GH_REPO)
	rm temp_notes.md
	@echo Release $(TAG) uploaded to GitHub!

# Refreshes an existing release: replaces the notes and (with --clobber) the uploaded zip; creates
# the release if it does not exist yet.  Does not move the tag; see "retag".
update: check-clean dist
	@echo Updating release $(TAG)...
	$(PYTHON) tools/release_notes.py $(VERSION) > temp_notes.md
	@if gh release view $(TAG) -R $(GH_REPO) >/dev/null 2>&1; then \
		echo "Release $(TAG) exists -- updating notes."; \
		gh release edit $(TAG) --notes-file temp_notes.md -R $(GH_REPO); \
	else \
		echo "Release $(TAG) not found -- creating it."; \
		gh release create $(TAG) --title "$(TAG)" --notes-file temp_notes.md -R $(GH_REPO); \
	fi
	rm temp_notes.md
	gh release upload $(TAG) $(SETUP_ZIP) --clobber -R $(GH_REPO)
	@echo Release $(TAG) assets and notes updated on GitHub!

# Recovery for "released, then committed more": force-moves the tag to HEAD and re-pushes.
# Solo repo only (force-pushing a moved tag is unsafe once anyone else has fetched it).
retag: check-clean
	@if git rev-parse $(TAG) >/dev/null 2>&1; then \
		echo "Retagging existing tag $(TAG)."; \
	else \
		echo "Note: $(TAG) does not exist yet -- this will be its first release."; \
	fi
	git tag -f $(TAG)
	git push origin $(TAG) --force

re-release: retag update
	@echo Release $(TAG) retagged and re-released.

clean: $(CLEANS)
	rm -rf installer/output

$(CLEANS): clean/%:
	dotnet clean $* $(DOTNET_FLAGS)

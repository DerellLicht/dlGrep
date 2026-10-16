"""Stop a running Windows program by name, but only if it is running.

usage: python tools/stop_app.py dlGrep

The Windows build cannot replace dlGrep.exe while it is running, so the Makefile runs this
before building.  It looks for NAME.exe with tasklist, and only if it finds one does it call
taskkill, so a build with the program closed is quiet instead of printing a "process not found"
error.  Always exits 0: failing to stop the program is reported, and the build is left to
fail with its own (clearer) message if the file is really locked.
"""
import subprocess
import sys


def is_running(image):
    """Return True if a process with this image name (for example dlGrep.exe) is running.

    Uses tasklist with a filter, which prints one csv line per matching process, or an
    "INFO: No tasks are running..." message when there is none.  Any problem running tasklist
    (not Windows, command missing) counts as "not running".
    """
    try:
        out = subprocess.run(
            ["tasklist", "/FI", "IMAGENAME eq " + image, "/FO", "CSV", "/NH"],
            capture_output=True, text=True, check=False).stdout
    except OSError:
        return False
    return image.lower() in out.lower()


def stop(image):
    """Kill every process with this image name, returning True if taskkill reported success."""
    result = subprocess.run(["taskkill", "/IM", image, "/F"], capture_output=True, text=True, check=False)
    return result.returncode == 0


def main(argv):
    """Entry point: argv[1] is the program name, with or without .exe."""
    if len(argv) != 2:
        print(__doc__)
        return 0

    image = argv[1] if argv[1].lower().endswith(".exe") else argv[1] + ".exe"
    if not is_running(image):
        print(image + " is not running")
    elif stop(image):
        print("stopped " + image)
    else:
        print("could not stop " + image + " (try closing it by hand)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

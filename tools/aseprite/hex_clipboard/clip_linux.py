#!/usr/bin/env python3
"""Linux clipboard helper for the Aseprite Hex Clipboard extension.

Sets the X11 CLIPBOARD selection to the given text and holds ownership
until either another app takes the clipboard, or a 1-hour timeout fires.

Aseprite's Lua API does not expose a system text clipboard, and Ubuntu
does not ship xclip/xsel/wl-copy out of the box, so we use PyGObject+GTK
(preinstalled on GNOME-based distros) to own the X11 selection.

Usage: clip_linux.py <text>
"""
import sys
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib

TIMEOUT_SECONDS = 3600


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("usage: clip_linux.py <text>\n")
        sys.exit(2)
    text = sys.argv[1]

    clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    clipboard.set_text(text, -1)
    clipboard.store()

    state = {"first": True}

    def on_owner_change(*_):
        if state["first"]:
            state["first"] = False
            return
        Gtk.main_quit()

    clipboard.connect("owner-change", on_owner_change)
    GLib.timeout_add_seconds(TIMEOUT_SECONDS, Gtk.main_quit)
    Gtk.main()


if __name__ == "__main__":
    main()

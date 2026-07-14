#!/usr/bin/env python3
"""
pick_folder.py
Opens a GTK folder chooser dialog directly and prints the chosen path to stdout.
"""

import sys
import os
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

def main():
    # Initialize GTK
    Gtk.init(None)

    dialog = Gtk.FileChooserDialog(
        title="Select Wallpaper Folder",
        parent=None,
        action=Gtk.FileChooserAction.SELECT_FOLDER
    )
    dialog.add_buttons(
        Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
        Gtk.STOCK_OPEN, Gtk.ResponseType.OK
    )

    # Set default folder to user's Pictures or home if it exists
    default_dir = os.path.expanduser("~/Pictures")
    if not os.path.exists(default_dir):
        default_dir = os.path.expanduser("~")
    dialog.set_current_folder(default_dir)

    # Run the dialog
    response = dialog.run()
    chosen_path = None
    if response == Gtk.ResponseType.OK:
        chosen_path = dialog.get_filename()

    dialog.destroy()

    if chosen_path:
        print(chosen_path, flush=True)
        return 0
    else:
        return 1

if __name__ == '__main__':
    sys.exit(main())

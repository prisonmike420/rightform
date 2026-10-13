# dmgbuild settings for Stou's disk image: the branded background with the
# real Stou.app on the left of its arrow and a real link to Applications on
# the right, so dragging one onto the other installs Stou. Nothing else is
# shown: the background lives in the hidden .background folder.
#
# scripts/build-dmg.sh passes the app and the background (a TIFF holding the
# 1x and @2x images) with -D app=… -D background=….

import os

app = defines["app"]  # noqa: F821 — dmgbuild provides `defines`
app_name = os.path.basename(app)

format = "UDZO"
filesystem = "HFS+"

files = [app]
symlinks = {"Applications": "/Applications"}

background = defines["background"]  # noqa: F821

# The window is the background's size in points, 836 × 470.
window_rect = ((200, 120), (836, 470))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

icon_size = 112
text_size = 13
arrange_by = None
icon_locations = {
    app_name: (267, 260),
    "Applications": (580, 260),
}

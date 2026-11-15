import QtQuick

// Base for whatever WorkspaceTile draws inside a window: the tile sets `win`, one
// window from Model.occupiedWorkspaces, and the thumbnail fills itself.
Item {
  property var win: null
}

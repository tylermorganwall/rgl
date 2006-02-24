#ifndef RGL_W32_GUI_HPP
#define RGL_W32_GUI_HPP
// ---------------------------------------------------------------------------
// $Id: win32gui.hpp 376 2005-08-03 23:58:47Z dadler $
// ---------------------------------------------------------------------------
#include "gui.hpp"
// ---------------------------------------------------------------------------
#include <windows.h>
// ---------------------------------------------------------------------------
namespace gui {
// ---------------------------------------------------------------------------
class Win32GUIFactory : public GUIFactory
{
public:
  Win32GUIFactory();
  virtual ~Win32GUIFactory();
  WindowImpl* createWindowImpl(Window* window);
};
// ---------------------------------------------------------------------------
} // namespace gui
// ---------------------------------------------------------------------------
#endif // RGL_W32_GUI_HPP


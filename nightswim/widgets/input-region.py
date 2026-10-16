#!/usr/bin/env python3
"""Give the conky widget window a mouse input region.

conky makes undecorated/desktop windows fully click-through (empty XShape
input region), so `lua_mouse_hook` never sees a click. This sets the input
region of every WM_CLASS "Conky" window to the given rectangles: those areas
take clicks, the rest of the window stays click-through to the desktop.

usage: input-region.py X Y W H [X Y W H ...]   (window coordinates)
Run by widgets.lua once its window exists; X11 only.
"""
import ctypes
import ctypes.util
import sys

SHAPE_INPUT, SHAPE_SET, UNSORTED = 2, 0, 0
CLASS = b'Conky'


class XRectangle(ctypes.Structure):
    _fields_ = [('x', ctypes.c_short), ('y', ctypes.c_short),
                ('width', ctypes.c_ushort), ('height', ctypes.c_ushort)]


class XClassHint(ctypes.Structure):
    _fields_ = [('res_name', ctypes.c_void_p), ('res_class', ctypes.c_void_p)]


def main(argv):
    nums = [int(float(a)) for a in argv]
    if not nums or len(nums) % 4:
        sys.exit('usage: input-region.py X Y W H [X Y W H ...]')
    x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11') or 'libX11.so.6')
    xext = ctypes.cdll.LoadLibrary(ctypes.util.find_library('Xext') or 'libXext.so.6')
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    x11.XQueryTree.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong),
                               ctypes.POINTER(ctypes.c_ulong),
                               ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)),
                               ctypes.POINTER(ctypes.c_uint)]
    x11.XGetClassHint.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(XClassHint)]
    x11.XFree.argtypes = [ctypes.c_void_p]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    xext.XShapeCombineRectangles.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
                                             ctypes.c_int, ctypes.c_int,
                                             ctypes.POINTER(XRectangle), ctypes.c_int,
                                             ctypes.c_int, ctypes.c_int]

    dpy = x11.XOpenDisplay(None)
    if not dpy:
        sys.exit('input-region.py: cannot open display')

    def children(win):
        root, parent = ctypes.c_ulong(), ctypes.c_ulong()
        kids, n = ctypes.POINTER(ctypes.c_ulong)(), ctypes.c_uint()
        if not x11.XQueryTree(dpy, win, ctypes.byref(root), ctypes.byref(parent),
                              ctypes.byref(kids), ctypes.byref(n)):
            return []
        out = [kids[i] for i in range(n.value)]
        if kids:
            x11.XFree(kids)
        return out

    def is_conky(win):
        hint = XClassHint()
        if not x11.XGetClassHint(dpy, win, ctypes.byref(hint)):
            return False
        found = bool(hint.res_class) and ctypes.string_at(hint.res_class) == CLASS
        for ptr in (hint.res_name, hint.res_class):
            if ptr:
                x11.XFree(ptr)
        return found

    rects = (XRectangle * (len(nums) // 4))(
        *[XRectangle(*nums[i:i + 4]) for i in range(0, len(nums), 4)])
    # conky's window is a child of the root, or of a WM frame one level down.
    targets = []
    for win in children(x11.XDefaultRootWindow(dpy)):
        if is_conky(win):
            targets.append(win)
        else:
            targets += [kid for kid in children(win) if is_conky(kid)]
    for win in targets:
        xext.XShapeCombineRectangles(dpy, win, SHAPE_INPUT, 0, 0, rects, len(rects),
                                     SHAPE_SET, UNSORTED)
    x11.XFlush(dpy)
    x11.XCloseDisplay(dpy)
    if not targets:
        sys.exit('input-region.py: no Conky window found')


if __name__ == '__main__':
    main(sys.argv[1:])

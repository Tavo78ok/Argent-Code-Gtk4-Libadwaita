#!/usr/bin/env python3
"""
Argen Code v0.2.3 — editor premium para Open Argentos.
GTK4 + Libadwaita + GtkSourceView 5.

Cambios v0.2.3:
  - Corrección en la aplicación del esquema de color en nuevos buffers.
  - Limpieza de código duplicado en el panel de preferencias.
  - Compatibilidad segura para el diálogo de atajos de teclado.
"""

import os
import sys
import json
import subprocess
import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

try:
    gi.require_version('GtkSource', '5')
    from gi.repository import GtkSource
    HAS_GTK_SOURCE = True
except (ValueError, ImportError):
    HAS_GTK_SOURCE = False

from gi.repository import Gtk, Adw, Gio, GLib, Gdk, GObject


APP_VERSION = "0.2.3"
CONFIG_DIR = os.path.join(GLib.get_user_config_dir(), "argen-code")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")

DEFAULT_CONFIG = {
    "font_size": 11,
    "tab_width": 4,
    "scheme": "oblivion",
    "show_line_numbers": True,
    "show_minimap": True,
    "highlight_current_line": True,
    "auto_indent": True,
    "insert_spaces": True,
    "recent_files": [],
}

CSS_TEMPLATE = """
window {{ background-color: #1e1e1e; }}

.gtk-textview-fallback {{
    font-family: 'Monospace', 'Fira Code', 'DejaVu Sans Mono', monospace;
    font-size: {font_size}pt;
    background-color: #1e1e1e;
    color: #d4d4d4;
}}

.sidebar-box {{ background-color: #252526; border-right: 1px solid #333333; }}
.sidebar-title {{ color: #bbbbbb; font-size: 9pt; font-weight: bold; }}
.file-tree-view {{ background-color: #252526; color: #cccccc; font-size: 10pt; }}

.statusbar {{ background-color: #007acc; color: #ffffff; padding: 3px 10px; }}
.statusbar label {{ color: #ffffff; font-size: 9pt; }}

.source-map {{
    background-color: #1e1e1e;
    border-left: 1px solid #333333;
}}
"""

EXT_TO_LANG = {
    ".py": "python3",
    ".pyw": "python3",
    ".sh": "sh",
    ".bash": "sh",
    ".zsh": "sh",
    ".js": "javascript",
    ".mjs": "javascript",
    ".ts": "typescript",
    ".jsx": "javascript",
    ".tsx": "typescript",
    ".c": "c",
    ".h": "c",
    ".cpp": "cpp",
    ".cc": "cpp",
    ".hpp": "cpp",
    ".rs": "rust",
    ".go": "go",
    ".java": "java",
    ".rb": "ruby",
    ".php": "php",
    ".pl": "perl",
    ".lua": "lua",
    ".md": "markdown",
    ".rst": "rst",
    ".json": "json",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".toml": "toml",
    ".xml": "xml",
    ".html": "html",
    ".htm": "html",
    ".css": "css",
    ".scss": "scss",
    ".sql": "sql",
    ".ini": "ini",
    ".conf": "ini",
    ".desktop": "ini",
    ".cmake": "cmake",
    ".mk": "makefile",
    ".diff": "diff",
    ".patch": "diff",
}


def _detect_language(path, content, lang_mgr):
    if not HAS_GTK_SOURCE or lang_mgr is None:
        return None

    ext = os.path.splitext(path)[1].lower()
    lang_id = EXT_TO_LANG.get(ext)
    if lang_id:
        lang = lang_mgr.get_language(lang_id)
        if lang:
            return lang

    try:
        guess = lang_mgr.guess_language(path, None)
        if guess and guess.get_id() != "txt":
            return guess
    except Exception:
        pass

    return None


class FileEntry(GObject.Object):
    __gtype_name__ = "FileEntry"

    name = GObject.Property(type=str, default="")
    path = GObject.Property(type=str, default="")
    is_dir = GObject.Property(type=bool, default=False)

    def __init__(self, name="", path="", is_dir=False):
        super().__init__()
        self.name = name
        self.path = path
        self.is_dir = is_dir


class ArgenCodeWindow(Adw.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.set_title("Argen Code")
        self.set_default_size(1150, 740)
        self.set_icon_name("utilities-terminal-symbolic")

        self.config = self._load_config()
        self._page_paths = {}
        self._page_views = {}
        self._page_minimaps = {}
        self._page_titles = {}
        self._search_context = None
        self._last_paned_pos = 240
        self.current_folder = os.path.expanduser("~")

        try:
            Adw.StyleManager.get_default().set_color_scheme(
                Adw.ColorScheme.FORCE_DARK
            )
        except Exception:
            pass

        self._css_provider = Gtk.CssProvider()
        self._update_css()
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            self._css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(main_box)

        header = Adw.HeaderBar()
        main_box.append(header)
        self._install_header(header)

        self.paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        self.paned.set_vexpand(True)
        self.paned.set_hexpand(True)
        self.paned.set_position(self._last_paned_pos)
        main_box.append(self.paned)

        self.sidebar_box = self._build_sidebar()
        self.paned.set_start_child(self.sidebar_box)

        editor_area = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        editor_area.set_vexpand(True)
        editor_area.set_hexpand(True)

        self.tab_view = Adw.TabView()
        self.tab_view.set_vexpand(True)
        self.tab_view.set_hexpand(True)
        self.tab_view.connect("close-page", self._on_close_page)
        self.tab_view.connect("notify::selected-page", self._on_tab_changed)
        self.tab_view.connect("notify::n-pages", self._on_pages_changed)
        self.tab_view.connect("page-detached", self._on_page_detached)

        self.tab_bar = Adw.TabBar()
        self.tab_bar.set_view(self.tab_view)
        self.tab_bar.set_autohide(True)

        self.search_bar = self._build_search_bar()
        self.welcome = self._build_welcome()

        self.main_stack = Gtk.Stack()
        self.main_stack.set_vexpand(True)
        self.main_stack.set_hexpand(True)
        self.main_stack.add_named(self.welcome, "welcome")
        self.main_stack.add_named(self.tab_view, "tabs")
        self.main_stack.set_visible_child_name("welcome")

        editor_area.append(self.tab_bar)
        editor_area.append(self.search_bar)
        editor_area.append(self.main_stack)
        self.paned.set_end_child(editor_area)

        self._build_statusbar(main_box)

        self.populate_file_tree(self.current_folder)
        self._install_actions()
        self.connect("close-request", self._on_close_request)

    def _load_config(self):
        data = {}
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            pass
        cfg = dict(DEFAULT_CONFIG)
        for k in DEFAULT_CONFIG:
            if k in data:
                cfg[k] = data[k]
        return cfg

    def _save_config(self):
        try:
            os.makedirs(CONFIG_DIR, exist_ok=True)
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(self.config, f, indent=2)
        except Exception as e:
            print(f"[argen-code] no se pudo guardar config: {e}")

    def _update_css(self):
        css = CSS_TEMPLATE.format(font_size=self.config["font_size"])
        self._css_provider.load_from_data(css.encode("utf-8"))

    def _add_recent(self, path):
        abs_path = os.path.abspath(path)
        recents = [p for p in self.config.get("recent_files", []) if p != abs_path]
        recents.insert(0, abs_path)
        self.config["recent_files"] = recents[:12]
        self._save_config()
        self._refresh_recent_ui()

    def _install_header(self, header):
        theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default())

        def icon(*cands):
            for c in cands:
                if theme.has_icon(c):
                    return c
            return cands[-1]

        btn_toggle = Gtk.Button(icon_name=icon("sidebar-show-symbolic", "view-list-symbolic"))
        btn_toggle.set_tooltip_text("Mostrar/ocultar explorador (Ctrl+B)")
        btn_toggle.connect("clicked", self.on_toggle_sidebar)
        header.pack_start(btn_toggle)

        btn_new = Gtk.Button(icon_name=icon("document-new-symbolic"))
        btn_new.set_tooltip_text("Nuevo archivo (Ctrl+N)")
        btn_new.connect("clicked", lambda w: self.new_tab())
        header.pack_start(btn_new)

        btn_open = Gtk.Button(icon_name=icon("document-open-symbolic"))
        btn_open.set_tooltip_text("Abrir archivo (Ctrl+O)")
        btn_open.connect("clicked", self.on_open_clicked)
        header.pack_start(btn_open)

        btn_save = Gtk.Button(icon_name=icon("document-save-symbolic"))
        btn_save.set_tooltip_text("Guardar (Ctrl+S)")
        btn_save.connect("clicked", self.on_save_clicked)
        header.pack_start(btn_save)

        self._btn_search = Gtk.ToggleButton(icon_name=icon("edit-find-symbolic"))
        self._btn_search.set_tooltip_text("Buscar (Ctrl+F)")
        self._btn_search.connect("toggled", self._on_search_toggled)
        header.pack_end(self._btn_search)

        menu = Gio.Menu()
        sec1 = Gio.Menu()
        sec1.append("Nueva pestaña", "win.new-tab")
        sec1.append("Abrir archivo…", "win.open")
        sec1.append("Abrir carpeta…", "win.open-folder")
        sec1.append("Guardar", "win.save")
        sec1.append("Guardar como…", "win.save-as")
        menu.append_section(None, sec1)

        sec2 = Gio.Menu()
        sec2.append("Preferencias", "win.preferences")
        sec2.append("Atajos de teclado", "win.shortcuts")
        menu.append_section(None, sec2)

        sec3 = Gio.Menu()
        sec3.append("Acerca de Argen Code", "app.about")
        menu.append_section(None, sec3)

        btn_menu = Gtk.MenuButton()
        btn_menu.set_icon_name(icon("open-menu-symbolic"))
        btn_menu.set_menu_model(menu)
        btn_menu.set_tooltip_text("Menú principal")
        header.pack_end(btn_menu)

    def _install_actions(self):
        actions = {
            "open":           lambda *a: self.on_open_clicked(None),
            "open-folder":    lambda *a: self.on_open_folder_clicked(None),
            "save":           lambda *a: self.on_save_clicked(None),
            "save-as":        lambda *a: self._on_save_as(),
            "new-tab":        lambda *a: self.new_tab(),
            "close-tab":      lambda *a: self._close_current_tab(),
            "toggle-sidebar": lambda *a: self.on_toggle_sidebar(None),
            "search":         lambda *a: self._activate_search(),
            "preferences":    lambda *a: self._open_preferences(),
            "shortcuts":      lambda *a: self._show_shortcuts(),
        }
        for name, handler in actions.items():
            act = Gio.SimpleAction.new(name, None)
            act.connect("activate", handler)
            self.add_action(act)

    def _close_current_tab(self):
        page = self.tab_view.get_selected_page()
        if page:
            self.tab_view.close_page(page)

    def _build_sidebar(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.add_css_class("sidebar-box")

        title_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        title_row.set_margin_start(12)
        title_row.set_margin_end(6)
        title_row.set_margin_top(8)
        title_row.set_margin_bottom(8)

        lbl = Gtk.Label(label="EXPLORADOR")
        lbl.add_css_class("sidebar-title")
        lbl.set_halign(Gtk.Align.START)
        lbl.set_hexpand(True)
        title_row.append(lbl)

        btn_refresh = Gtk.Button(icon_name="view-refresh-symbolic")
        btn_refresh.add_css_class("flat")
        btn_refresh.set_tooltip_text("Refrescar")
        btn_refresh.connect(
            "clicked", lambda w: self.populate_file_tree(self.current_folder)
        )
        title_row.append(btn_refresh)
        box.append(title_row)

        self._file_store = Gio.ListStore.new(FileEntry)
        self._tree_model = Gtk.TreeListModel.new(
            self._file_store,
            False,
            False,
            self._create_tree_child,
        )

        self._selection = Gtk.SingleSelection.new(self._tree_model)
        self._selection.set_autoselect(False)
        self._selection.set_can_unselect(True)

        self.tree_view = Gtk.ListView.new(self._selection, None)
        self.tree_view.add_css_class("file-tree-view")
        self.tree_view.set_single_click_activate(False)

        factory = Gtk.SignalListItemFactory()
        factory.connect("setup", self._on_factory_setup)
        factory.connect("bind", self._on_factory_bind)
        self.tree_view.set_factory(factory)
        self.tree_view.connect("activate", self._on_tree_item_activated)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_child(self.tree_view)
        box.append(scrolled)
        return box

    def _on_factory_setup(self, factory, list_item):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        row.set_margin_start(6)
        row.set_margin_end(6)
        row.set_margin_top(2)
        row.set_margin_bottom(2)

        expander = Gtk.Image()
        expander.set_pixel_size(12)
        expander.set_valign(Gtk.Align.CENTER)
        row.append(expander)

        icon = Gtk.Image()
        icon.set_valign(Gtk.Align.CENTER)
        row.append(icon)

        label = Gtk.Label()
        label.set_halign(Gtk.Align.START)
        label.set_xalign(0)
        label.set_hexpand(True)
        try:
            import gi as _gi
            _gi.require_version("Pango", "1.0")
            from gi.repository import Pango
            label.set_ellipsize(Pango.EllipsizeMode.END)
        except Exception:
            pass
        row.append(label)

        list_item.set_child(row)

    def _on_factory_bind(self, factory, list_item):
        tree_row = list_item.get_item()
        row = list_item.get_child()
        expander = row.get_first_child()
        icon = expander.get_next_sibling()
        label = icon.get_next_sibling()

        entry = tree_row.get_item()
        icon.set_from_icon_name(self._icon_for_entry(entry.name, entry.is_dir))
        label.set_text(entry.name)

        if entry.is_dir:
            expander.set_visible(True)
            if tree_row.get_expanded():
                expander.set_from_icon_name("pan-down-symbolic")
            else:
                expander.set_from_icon_name("pan-end-symbolic")
        else:
            expander.set_visible(False)

    def _create_tree_child(self, obj):
        if isinstance(obj, Gtk.TreeListRow):
            entry = obj.get_item()
        else:
            entry = obj
        if entry is None or not entry.is_dir:
            return None
        try:
            names = os.listdir(entry.path)
        except (PermissionError, FileNotFoundError, OSError):
            return None
        children = []
        for name in names:
            if name.startswith("."):
                continue
            full = os.path.join(entry.path, name)
            children.append(
                FileEntry(name=name, path=full, is_dir=os.path.isdir(full))
            )
        children.sort(key=lambda e: (not e.is_dir, e.name.lower()))
        if not children:
            return None
        store = Gio.ListStore.new(FileEntry)
        for c in children:
            store.append(c)
        return store

    def _on_tree_item_activated(self, view, position):
        tree_row = self._tree_model.get_row(position)
        if tree_row is None:
            return
        entry = tree_row.get_item()
        if entry.is_dir:
            tree_row.set_expanded(not tree_row.get_expanded())
        else:
            self.open_file_path(entry.path)

    def _icon_for_entry(self, name, is_dir):
        if is_dir:
            return "folder-symbolic"
        theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default())
        cands = ["text-x-generic-symbolic"]
        if name.endswith(".py"):
            cands = ["text-x-python-symbolic", "text-x-generic-symbolic"]
        elif name.endswith((".sh", ".bash", ".zsh")):
            cands = ["utilities-terminal-symbolic", "text-x-generic-symbolic"]
        elif name.endswith((".json", ".yaml", ".yml", ".toml")):
            cands = ["application-json-symbolic", "text-x-generic-symbolic"]
        elif name.endswith((".md", ".rst")):
            cands = ["text-x-generic-symbolic"]
        for c in cands:
            if theme.has_icon(c):
                return c
        return "text-x-generic-symbolic"

    def populate_file_tree(self, folder_path):
        self._file_store.remove_all()
        root_name = os.path.basename(folder_path) or folder_path
        root = FileEntry(name=root_name, path=folder_path, is_dir=True)
        self._file_store.append(root)
        GLib.idle_add(self._expand_root)

    def _expand_root(self):
        row = self._tree_model.get_row(0)
        if row is not None:
            row.set_expanded(True)
        return False

    def on_toggle_sidebar(self, widget):
        if self.sidebar_box.get_visible():
            pos = self.paned.get_position()
            if pos > 0:
                self._last_paned_pos = pos
            self.sidebar_box.set_visible(False)
            self.paned.set_position(0)
        else:
            self.sidebar_box.set_visible(True)
            self.paned.set_position(self._last_paned_pos or 240)

    def _build_welcome(self):
        welcome = Adw.StatusPage()
        welcome.set_title("Argen Code")
        welcome.set_description("Editor de código potente y elegante para Open Argentos")
        welcome.set_icon_name("utilities-terminal-symbolic")

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        outer.set_halign(Gtk.Align.CENTER)

        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        actions.set_halign(Gtk.Align.CENTER)

        def make_btn(label, cb, suggested=False):
            b = Gtk.Button(label=label)
            b.add_css_class("pill")
            if suggested:
                b.add_css_class("suggested-action")
            b.connect("clicked", cb)
            actions.append(b)

        make_btn("Nuevo archivo", lambda w: self.new_tab(), True)
        make_btn("Abrir archivo", self.on_open_clicked)
        make_btn("Abrir carpeta", self.on_open_folder_clicked)

        outer.append(actions)

        self._recent_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self._recent_box.set_halign(Gtk.Align.CENTER)
        outer.append(self._recent_box)
        self._refresh_recent_ui()

        welcome.set_child(outer)
        return welcome

    def _refresh_recent_ui(self):
        if not hasattr(self, "_recent_box"):
            return
        for child in list(self._recent_box):
            self._recent_box.remove(child)

        recents = self.config.get("recent_files", [])
        if not recents:
            return

        title = Gtk.Label(label="Archivos recientes")
        title.add_css_class("dim-label")
        title.set_margin_top(12)
        self._recent_box.append(title)

        for path in recents[:6]:
            if not os.path.exists(path):
                continue
            b = Gtk.Button()
            b.add_css_class("flat")

            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            row.set_margin_start(8)
            row.set_margin_end(8)

            ic = Gtk.Image.new_from_icon_name("text-x-generic-symbolic")
            row.append(ic)

            textbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            textbox.set_hexpand(True)
            lbl = Gtk.Label(label=os.path.basename(path))
            lbl.set_halign(Gtk.Align.START)
            sub = Gtk.Label(label=os.path.dirname(path))
            sub.add_css_class("dim-label")
            sub.add_css_class("caption")
            sub.set_halign(Gtk.Align.START)
            textbox.append(lbl)
            textbox.append(sub)
            row.append(textbox)

            b.set_child(row)
            b.connect("clicked", lambda w, p=path: self.open_file_path(p))
            self._recent_box.append(b)

    def _build_search_bar(self):
        bar = Gtk.SearchBar()
        bar.set_show_close_button(True)

        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_hexpand(True)
        self.search_entry.set_placeholder_text("Buscar en el archivo…")
        self.search_entry.connect("search-changed", self._on_search_changed)
        self.search_entry.connect("activate", self._on_search_next)
        self.search_entry.connect("stop-search", self._on_search_entry_stop)
        self.search_entry.connect("next-match", self._on_search_next)
        self.search_entry.connect("previous-match", self._on_search_prev)

        bar.set_child(self.search_entry)
        bar.connect_entry(self.search_entry)
        bar.connect("notify::search-mode-enabled", self._on_search_mode_changed)
        return bar

    def _activate_search(self):
        if not HAS_GTK_SOURCE:
            self.lbl_status.set_text("Búsqueda no disponible (GtkSourceView ausente)")
            return
        self.search_bar.set_search_mode(True)
        self.search_entry.grab_focus()

    def _on_search_toggled(self, btn):
        self.search_bar.set_search_mode(btn.get_active())
        if btn.get_active():
            self.search_entry.grab_focus()
        else:
            self._clear_search()

    def _on_search_mode_changed(self, bar, pspec):
        active = bar.get_search_mode()
        if hasattr(self, "_btn_search") and self._btn_search.get_active() != active:
            self._btn_search.set_active(active)
        if not active:
            self._clear_search()

    def _on_search_entry_stop(self, entry):
        self.search_bar.set_search_mode(False)
        self._clear_search()

    def _clear_search(self):
        if self._search_context is not None:
            try:
                self._search_context.set_highlight(False)
            except Exception:
                pass
            self._search_context = None

    def _on_search_changed(self, entry):
        self._do_search(entry.get_text(), restart=True)

    def _on_search_next(self, *a):
        self._do_search(self.search_entry.get_text(), restart=False, backwards=False)

    def _on_search_prev(self, *a):
        self._do_search(self.search_entry.get_text(), restart=False, backwards=True)

    def _do_search(self, text, restart=False, backwards=False):
        if not HAS_GTK_SOURCE:
            return
        page = self.tab_view.get_selected_page()
        if page is None:
            return
        view = self._page_views.get(page)
        if view is None:
            return
        buf = view.get_buffer()

        if not text:
            self._clear_search()
            return

        if self._search_context is None or self._search_context.get_buffer() is not buf:
            settings = GtkSource.SearchSettings()
            self._search_context = GtkSource.SearchContext(
                buffer=buf, settings=settings
            )
            self._search_context.set_highlight(True)

        settings = GtkSource.SearchSettings()
        settings.set_search_text(text)
        settings.set_case_sensitive(False)
        settings.set_wrap_around(True)
        self._search_context.set_settings(settings)

        if restart:
            start = buf.get_end_iter() if backwards else buf.get_start_iter()
        else:
            start = buf.get_iter_at_mark(buf.get_insert())

        if backwards:
            self._search_context.backward_async(
                start, None, self._on_search_found_backward, view
            )
        else:
            self._search_context.forward_async(
                start, None, self._on_search_found_forward, view
            )

    def _on_search_found_forward(self, context, result, view):
        try:
            found, mstart, mend, wrapped = context.forward_finish(result)
        except GLib.Error:
            return
        if found and mstart is not None:
            buf = view.get_buffer()
            buf.select_range(mstart, mend)
            view.scroll_to_iter(mstart, 0.1, False, 0.0, 0.0)

    def _on_search_found_backward(self, context, result, view):
        try:
            found, mstart, mend, wrapped = context.backward_finish(result)
        except GLib.Error:
            return
        if found and mstart is not None:
            buf = view.get_buffer()
            buf.select_range(mstart, mend)
            view.scroll_to_iter(mstart, 0.1, False, 0.0, 0.0)

    def _apply_scheme_to_buffer(self, buffer):
        if not HAS_GTK_SOURCE:
            return
        manager = GtkSource.StyleSchemeManager.get_default()
        scheme = manager.get_scheme(self.config["scheme"])
        if scheme is None:
            for sid in ("oblivion", "classic-dark", "kate", "solarized-dark", "tango", "cobalt"):
                scheme = manager.get_scheme(sid)
                if scheme:
                    break
        if scheme:
            buffer.set_style_scheme(scheme)

    def _apply_scheme_to_all(self):
        for view in self._page_views.values():
            self._apply_scheme_to_buffer(view.get_buffer())

    def _apply_view_config(self, view):
        if not HAS_GTK_SOURCE:
            return
        cfg = self.config
        view.set_show_line_numbers(cfg["show_line_numbers"])
        view.set_highlight_current_line(cfg["highlight_current_line"])
        view.set_tab_width(cfg["tab_width"])
        view.set_indent_width(cfg["tab_width"])
        view.set_insert_spaces_instead_of_tabs(cfg["insert_spaces"])
        view.set_auto_indent(cfg["auto_indent"])

    def _apply_view_config_to_all(self):
        for v in self._page_views.values():
            self._apply_view_config(v)

    def new_tab(self, title="Sin título", content="", file_path=None):
        if HAS_GTK_SOURCE:
            buffer = GtkSource.Buffer()
            self._apply_scheme_to_buffer(buffer)

            source_view = GtkSource.View(buffer=buffer)
            self._apply_view_config(source_view)
            try:
                source_view.set_highlight_matching_brackets(True)
                source_view.set_smart_backspace(True)
                source_view.set_smart_home_end(
                    GtkSource.SmartHomeEndType.BEFORE_FIRST_NON_WHITESPACE
                )
            except AttributeError:
                pass
        else:
            buffer = Gtk.TextBuffer()
            source_view = Gtk.TextView(buffer=buffer)
            source_view.set_monospace(True)
            source_view.add_css_class("gtk-textview-fallback")

        buffer.set_text(content)
        buffer.set_modified(False)
        buffer.connect("notify::cursor-position", self._on_cursor_changed)
        buffer.connect("modified-changed", self._on_modified_changed)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_hexpand(True)
        scrolled.set_child(source_view)

        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        hbox.set_vexpand(True)
        hbox.set_hexpand(True)
        hbox.append(scrolled)

        minimap = None
        if HAS_GTK_SOURCE:
            minimap = GtkSource.Map()
            minimap.set_view(source_view)
            minimap.set_size_request(70, -1)
            minimap.set_visible(self.config["show_minimap"])
            hbox.append(minimap)

        page = self.tab_view.append(hbox)
        self._page_paths[page] = file_path
        self._page_views[page] = source_view
        self._page_minimaps[page] = minimap
        self._page_titles[page] = title
        self._update_page_title(page)

        if file_path and HAS_GTK_SOURCE:
            lang_mgr = GtkSource.LanguageManager.get_default()
            lang = _detect_language(file_path, content, lang_mgr)
            if lang:
                buffer.set_language(lang)

        self.tab_view.set_selected_page(page)
        return source_view, buffer

    def _buffer_for_page(self, page):
        view = self._page_views.get(page)
        return view.get_buffer() if view else None

    def _find_page_for_buffer(self, buffer):
        for page, view in self._page_views.items():
            if view.get_buffer() is buffer:
                return page
        return None

    def _update_page_title(self, page):
        base = self._page_titles.get(page, "Sin título")
        buf = self._buffer_for_page(page)
        mod = buf.get_modified() if buf else False
        page.set_title(("• " if mod else "") + base)

    def _on_modified_changed(self, buffer):
        page = self._find_page_for_buffer(buffer)
        if page is not None:
            self._update_page_title(page)

    def _get_empty_untitled_page(self):
        model = self.tab_view.get_pages()
        if model.get_n_items() != 1:
            return None
        page = model.get_item(0)
        if self._page_paths.get(page) is not None:
            return None
        buf = self._buffer_for_page(page)
        if buf is None or buf.get_modified():
            return None
        start, end = buf.get_bounds()
        if buf.get_text(start, end, False).strip():
            return None
        return page

    def open_file_path(self, path):
        abs_path = os.path.abspath(path)
        for page, ppath in self._page_paths.items():
            if ppath and os.path.abspath(ppath) == abs_path:
                self.tab_view.set_selected_page(page)
                return
        try:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
        except (UnicodeDecodeError, OSError) as e:
            self.lbl_status.set_text(f"Error al abrir {path}: {e}")
            return

        empty_page = self._get_empty_untitled_page()
        self.new_tab(os.path.basename(path), content, path)
        if empty_page is not None:
            self.tab_view.close_page(empty_page)

        self._add_recent(abs_path)
        self.lbl_status.set_text(f"Archivo abierto: {path}")

    def _on_cursor_changed(self, buffer, pspec):
        page = self.tab_view.get_selected_page()
        if page is None:
            return
        if self._buffer_for_page(page) is not buffer:
            return
        it = buffer.get_iter_at_offset(buffer.get_property("cursor-position"))
        ln = it.get_line() + 1
        col = it.get_line_offset() + 1
        sel = ""
        if buffer.get_has_selection():
            s, e = buffer.get_selection_bounds()
            sel = f" (Sel {e.get_offset() - s.get_offset()})"
        self.lbl_cursor.set_text(f"Ln {ln}, Col {col}{sel}")

    def _on_tab_changed(self, tab_view, pspec):
        page = tab_view.get_selected_page()
        self._clear_search()

        if page is None:
            self.set_title("Argen Code")
            self.lbl_cursor.set_text("")
            self.lbl_language.set_text("—")
            return

        path = self._page_paths.get(page)
        subtitle = f" — {path}" if path else ""
        base = self._page_titles.get(page, page.get_title())
        self.set_title(f"{base}{subtitle} — Argen Code")

        buf = self._buffer_for_page(page)
        if buf is not None:
            self._on_cursor_changed(buf, None)

        self._update_language_label(page)

    def _update_language_label(self, page):
        if not HAS_GTK_SOURCE:
            self.lbl_language.set_text("Texto plano")
            return
        buf = self._buffer_for_page(page)
        if buf is None:
            self.lbl_language.set_text("—")
            return
        lang = buf.get_language()
        self.lbl_language.set_text(lang.get_name() if lang else "Texto plano")

    def _on_pages_changed(self, *a):
        n = self.tab_view.get_pages().get_n_items()
        self.main_stack.set_visible_child_name("tabs" if n > 0 else "welcome")

    def _on_page_detached(self, tab_view, page, position):
        self._page_paths.pop(page, None)
        self._page_views.pop(page, None)
        self._page_minimaps.pop(page, None)
        self._page_titles.pop(page, None)

    def _on_close_page(self, tab_view, page):
        buf = self._buffer_for_page(page)
        if buf is not None and buf.get_modified():
            def on_response(dialog, response):
                if response == "discard":
                    buf.set_modified(False)
                    tab_view.close_page_finish(page, True)
                else:
                    tab_view.close_page_finish(page, False)

            self._confirm_discard(
                on_response,
                f"«{self._page_titles.get(page, page.get_title())}» "
                f"tiene cambios sin guardar.",
            )
            return True
        return False

    def _get_modified_pages(self):
        model = self.tab_view.get_pages()
        result = []
        for i in range(model.get_n_items()):
            p = model.get_item(i)
            buf = self._buffer_for_page(p)
            if buf is not None and buf.get_modified():
                result.append(p)
        return result

    def _on_close_request(self, *_):
        modified = self._get_modified_pages()
        if not modified:
            return False

        def on_response(dialog, response):
            if response == "discard":
                for p in modified:
                    buf = self._buffer_for_page(p)
                    if buf is not None:
                        buf.set_modified(False)
                self.close()

        self._confirm_discard(
            on_response,
            f"Hay {len(modified)} archivo(s) con cambios sin guardar. "
            f"¿Salir de todos modos?",
        )
        return True

    def _confirm_discard(self, on_response, message):
        try:
            dlg = Adw.AlertDialog(heading="Cambios sin guardar", body=message)
            dlg.add_response("cancel", "Cancelar")
            dlg.add_response("discard", "Descartar")
            try:
                dlg.set_response_appearance(
                    "discard", Adw.ResponseAppearance.DESTRUCTIVE
                )
            except AttributeError:
                pass
            dlg.set_default_response("cancel")
            dlg.set_close_response("cancel")
            dlg.connect("response", on_response)
            dlg.present(self)
            return
        except AttributeError:
            pass

        dlg = Gtk.MessageDialog(
            transient_for=self, modal=True,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.NONE,
            text=message,
        )
        dlg.add_button("Cancelar", Gtk.ResponseType.CANCEL)
        dlg.add_button("Descartar", Gtk.ResponseType.OK)

        def _resp(d, r):
            try:
                d.destroy()
            except Exception:
                pass
            on_response(None, "discard" if r == Gtk.ResponseType.OK else "cancel")

        dlg.connect("response", _resp)
        dlg.present()

    def on_open_clicked(self, widget):
        dialog = Gtk.FileDialog()
        try:
            f = Gtk.FileFilter()
            f.set_name("Código fuente")
            for pat in ("*.py", "*.js", "*.ts", "*.c", "*.h", "*.cpp", "*.hpp",
                        "*.rs", "*.go", "*.java", "*.rb", "*.php", "*.sh",
                        "*.bash", "*.md", "*.json", "*.yaml", "*.yml", "*.toml",
                        "*.html", "*.css", "*.xml", "*.txt"):
                f.add_pattern(pat)
            allf = Gtk.FileFilter()
            allf.set_name("Todos los archivos")
            allf.add_pattern("*")
            filters = Gio.ListStore.new(Gtk.FileFilter)
            filters.append(f)
            filters.append(allf)
            dialog.set_filters(filters)
            try:
                dialog.set_default_filter(f)
            except AttributeError:
                pass
            dialog.set_initial_folder(Gio.File.new_for_path(self.current_folder))
        except Exception:
            pass
        dialog.open(self, None, self.on_file_opened)

    def on_file_opened(self, dialog, result):
        try:
            file = dialog.open_finish(result)
            if file:
                self.open_file_path(file.get_path())
        except GLib.Error:
            pass
        except Exception as e:
            self.lbl_status.set_text(f"Error abriendo archivo: {e}")

    def on_open_folder_clicked(self, widget):
        dialog = Gtk.FileDialog()
        dialog.select_folder(self, None, self.on_folder_selected)

    def on_folder_selected(self, dialog, result):
        try:
            folder = dialog.select_folder_finish(result)
            if folder:
                path = folder.get_path()
                self.current_folder = path
                self.populate_file_tree(path)
                self.lbl_status.set_text(f"Carpeta: {path}")
        except GLib.Error:
            pass
        except Exception as e:
            self.lbl_status.set_text(f"Error abriendo carpeta: {e}")

    def on_save_clicked(self, widget):
        page = self.tab_view.get_selected_page()
        if page is None:
            return
        path = self._page_paths.get(page)
        if path:
            self.write_to_file(path, page)
        else:
            self._on_save_as()

    def _on_save_as(self):
        page = self.tab_view.get_selected_page()
        if page is None:
            return
        dialog = Gtk.FileDialog()
        try:
            dialog.set_initial_name(self._page_titles.get(page, "sin-titulo.txt"))
            dialog.set_initial_folder(Gio.File.new_for_path(self.current_folder))
        except Exception:
            pass
        dialog.save(self, None, self.on_file_saved)

    def on_file_saved(self, dialog, result):
        try:
            file = dialog.save_finish(result)
            if file:
                page = self.tab_view.get_selected_page()
                if page is not None:
                    self.write_to_file(file.get_path(), page)
        except GLib.Error:
            pass
        except Exception as e:
            self.lbl_status.set_text(f"Error guardando: {e}")

    def write_to_file(self, path, page):
        try:
            view = self._page_views.get(page)
            if view is None:
                return
            buf = view.get_buffer()
            s, e = buf.get_bounds()
            text = buf.get_text(s, e, True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)

            buf.set_modified(False)
            self._page_paths[page] = path
            self._page_titles[page] = os.path.basename(path)
            self._update_page_title(page)

            if HAS_GTK_SOURCE:
                lang_mgr = GtkSource.LanguageManager.get_default()
                lang = _detect_language(path, text, lang_mgr)
                if lang:
                    buf.set_language(lang)

            self._on_tab_changed(self.tab_view, None)
            self._add_recent(path)
            self.lbl_status.set_text(f"Guardado: {path}")
        except Exception as e:
            self.lbl_status.set_text(f"Error al guardar: {e}")

    def _build_statusbar(self, parent):
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        bar.add_css_class("statusbar")

        self.lbl_status = Gtk.Label(label="Listo")
        self.lbl_status.set_hexpand(True)
        self.lbl_status.set_halign(Gtk.Align.START)

        self.lbl_language = Gtk.Label(label="—")
        self.lbl_encoding = Gtk.Label(label="UTF-8")
        self.lbl_indent = Gtk.Label(label=f"Espacios: {self.config['tab_width']}")
        self.lbl_cursor = Gtk.Label(label="Ln 1, Col 1")

        bar.append(self.lbl_status)
        bar.append(self.lbl_language)
        bar.append(self.lbl_encoding)
        bar.append(self.lbl_indent)
        bar.append(self.lbl_cursor)
        parent.append(bar)

    def _open_preferences(self):
        try:
            dlg = Adw.PreferencesDialog()
            dlg.set_title("Preferencias")
            dlg.add(self._build_prefs_page())
            dlg.present(self)
        except AttributeError:
            win = Adw.PreferencesWindow()
            win.set_transient_for(self)
            win.set_modal(True)
            win.set_title("Preferencias")
            win.add(self._build_prefs_page())
            win.present()

    def _build_prefs_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Editor")
        page.set_icon_name("preferences-system-symbolic")

        group = Adw.PreferencesGroup()
        group.set_title("Apariencia")

        row = Adw.SpinRow.new_with_range(8, 24, 1)
        row.set_title("Tamaño de fuente")
        row.set_subtitle("Puntos")
        row.set_value(self.config["font_size"])

        def on_font(r, pspec):
            self.config["font_size"] = int(r.get_value())
            self._update_css()
            self._save_config()

        row.connect("notify::value", on_font)
        group.add(row)

        if HAS_GTK_SOURCE:
            ids = ["oblivion", "classic-dark", "kate", "solarized-dark", "tango", "cobalt"]
            try:
                manager = GtkSource.StyleSchemeManager.get_default()
                real_ids = manager.get_scheme_ids()
                if real_ids:
                    ids = sorted(real_ids)
            except Exception:
                pass

            if ids:
                crow = Adw.ComboRow()
                crow.set_title("Esquema de color")
                crow.set_subtitle("Resaltado de sintaxis")
                crow.set_model(Gtk.StringList.new(ids))

                current = self.config["scheme"]
                if current in ids:
                    crow.set_selected(ids.index(current))
                elif ids:
                    crow.set_selected(0)
                    self.config["scheme"] = ids[0]

                def on_scheme(r, pspec):
                    idx = r.get_selected()
                    if 0 <= idx < len(ids):
                        self.config["scheme"] = ids[idx]
                        self._apply_scheme_to_all()
                        self._save_config()

                crow.connect("notify::selected", on_scheme)
                group.add(crow)

        page.add(group)

        group2 = Adw.PreferencesGroup()
        group2.set_title("Editor")

        def add_switch(title, key, callback):
            sw = Adw.SwitchRow()
            sw.set_title(title)
            sw.set_active(self.config[key])

            def on_change(r, pspec):
                self.config[key] = r.get_active()
                callback()
                self._save_config()

            sw.connect("notify::active", on_change)
            group2.add(sw)

        def apply_views():
            self._apply_view_config_to_all()

        def apply_minimap():
            for mm in self._page_minimaps.values():
                if mm is not None:
                    mm.set_visible(self.config["show_minimap"])

        add_switch("Números de línea", "show_line_numbers", apply_views)
        add_switch("Minimapa", "show_minimap", apply_minimap)
        add_switch("Resaltar línea actual", "highlight_current_line", apply_views)
        add_switch("Indentación automática", "auto_indent", apply_views)
        add_switch("Insertar espacios (no tabs)", "insert_spaces", apply_views)

        row = Adw.SpinRow.new_with_range(2, 8, 1)
        row.set_title("Ancho de tabulación")
        row.set_subtitle("Espacios")
        row.set_value(self.config["tab_width"])

        def on_tab(r, pspec):
            self.config["tab_width"] = int(r.get_value())
            self.lbl_indent.set_text(f"Espacios: {self.config['tab_width']}")
            apply_views()
            self._save_config()

        row.connect("notify::value", on_tab)
        group2.add(row)

        page.add(group2)

        group3 = Adw.PreferencesGroup()
        group3.set_title("Acerca de")
        arow = Adw.ActionRow()
        arow.set_title("Argen Code")
        arow.set_subtitle(f"Versión {APP_VERSION} — Open Argentos")
        btn = Gtk.Button(label="Ver detalles")
        btn.add_css_class("flat")
        btn.connect("clicked", self._show_about)
        arow.add_suffix(btn)
        group3.add(arow)
        page.add(group3)

        return page

    def _show_about(self, *a):
        try:
            about = Adw.AboutDialog()
            about.set_application_name("Argen Code")
            about.set_application_icon("utilities-terminal-symbolic")
            about.set_developer_name("Open Argentos")
            about.set_version(APP_VERSION)
            about.set_comments("Editor de código minimalista para Open Argentos")
            about.set_license_type(Gtk.License.MIT_X11)
            about.present(self)
        except AttributeError:
            about = Adw.AboutWindow()
            about.set_transient_for(self)
            about.set_application_name("Argen Code")
            about.set_application_icon("utilities-terminal-symbolic")
            about.set_developer_name("Open Argentos")
            about.set_version(APP_VERSION)
            about.set_comments("Editor de código minimalista para Open Argentos")
            about.present()

    def _show_shortcuts(self, *a):
        try:
            dialog = Adw.ShortcutsDialog()
            file_sec = Adw.ShortcutsSection()
            file_sec.set_title("Archivo")
            file_sec.set_section_name("file")
            for title, accel in [
                ("Nueva pestaña", "<Control>n"),
                ("Abrir archivo", "<Control>o"),
                ("Abrir carpeta", "<Control><Shift>o"),
                ("Guardar", "<Control>s"),
                ("Guardar como", "<Control><Shift>s"),
                ("Cerrar pestaña", "<Control>w"),
                ("Salir", "<Control>q"),
            ]:
                item = Adw.ShortcutsItem()
                item.set_title(title)
                item.set_accelerator(accel)
                file_sec.add(item)
            dialog.add(file_sec)

            edit_sec = Adw.ShortcutsSection()
            edit_sec.set_title("Edición")
            edit_sec.set_section_name("edit")
            for title, accel in [
                ("Buscar", "<Control>f"),
                ("Mostrar/ocultar explorador", "<Control>b"),
                ("Preferencias", "<Control>p"),
            ]:
                item = Adw.ShortcutsItem()
                item.set_title(title)
                item.set_accelerator(accel)
                edit_sec.add(item)
            dialog.add(edit_sec)

            dialog.present(self)
        except AttributeError:
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            box.set_margin_top(20)
            box.set_margin_bottom(20)
            box.set_margin_start(20)
            box.set_margin_end(20)

            box.append(Gtk.Label(label="Atajos de teclado", css_classes=["title-1"]))

            shortcuts = [
                ("Nueva pestaña", "Ctrl+N"),
                ("Abrir archivo", "Ctrl+O"),
                ("Abrir carpeta", "Ctrl+Shift+O"),
                ("Guardar", "Ctrl+S"),
                ("Guardar como", "Ctrl+Shift+S"),
                ("Cerrar pestaña", "Ctrl+W"),
                ("Buscar", "Ctrl+F"),
                ("Mostrar/ocultar explorador", "Ctrl+B"),
                ("Preferencias", "Ctrl+P"),
                ("Salir", "Ctrl+Q"),
            ]

            grid = Gtk.Grid(row_spacing=8, column_spacing=20)
            for i, (name, key) in enumerate(shortcuts):
                lbl_name = Gtk.Label(label=name, xalign=0)
                lbl_key = Gtk.Label(label=key, xalign=1)
                lbl_key.add_css_class("dim-label")
                grid.attach(lbl_name, 0, i, 1, 1)
                grid.attach(lbl_key, 1, i, 1, 1)

            box.append(grid)

            win = Gtk.Window(title="Atajos de teclado")
            win.set_transient_for(self)
            win.set_modal(True)
            win.set_child(box)
            win.present()


class ArgenCodeApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id="org.openargentos.argencode",
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS,
        )
        self.set_accels_for_action("win.new-tab", ["<Control>n"])
        self.set_accels_for_action("win.open", ["<Control>o"])
        self.set_accels_for_action("win.open-folder", ["<Control><Shift>o"])
        self.set_accels_for_action("win.save", ["<Control>s"])
        self.set_accels_for_action("win.save-as", ["<Control><Shift>s"])
        self.set_accels_for_action("win.close-tab", ["<Control>w"])
        self.set_accels_for_action("win.toggle-sidebar", ["<Control>b"])
        self.set_accels_for_action("win.search", ["<Control>f"])
        self.set_accels_for_action("win.preferences", ["<Control>p"])
        self.set_accels_for_action("app.quit", ["<Control>q"])

        about = Gio.SimpleAction.new("about", None)
        about.connect("activate", self._on_about)
        self.add_action(about)

    def _on_about(self, *a):
        win = self.props.active_window
        if win:
            win._show_about()

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = ArgenCodeWindow(application=self)
        win.present()


if __name__ == "__main__":
    app = ArgenCodeApp()
    app.run(sys.argv)
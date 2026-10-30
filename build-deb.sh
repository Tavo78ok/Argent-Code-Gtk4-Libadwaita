#!/bin/bash
set -e

APP_NAME="argen-code"
VERSION="0.2.3"
ARCH="all"
BUILD_DIR="${APP_NAME}_${VERSION}_${ARCH}"

echo "==> Iniciando construcción del paquete Debian (.deb) con tu icono..."

# 1. Limpiar construcciones anteriores
rm -rf "$BUILD_DIR" "${BUILD_DIR}.deb"

# 2. Crear estructura de directorios Debian
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/usr/share/icons/hicolor/scalable/apps"

# 3. Crear archivo de control DEBIAN/control (dependencias corregidas)
cat << EOF > "$BUILD_DIR/DEBIAN/control"
Package: ${APP_NAME}
Version: ${VERSION}
Section: editors
Priority: optional
Architecture: ${ARCH}
Depends: python3, python3-gi, gir1.2-gtksource-5, libgtksourceview-5-0, libadwaita-1-0, gir1.2-adw-1, gir1.2-gtk-4.0
Maintainer: Open Argentos <soporte@openargentos.org>
Description: Editor de código premium y liviano para Open Argentos.
 Desarrollado en GTK4, Libadwaita y GtkSourceView 5.
EOF

# 4. Copiar ejecutable principal
if [ -f "argent-code.py" ]; then
    cp "argent-code.py" "$BUILD_DIR/usr/bin/argen-code"
elif [ -f "argen-code" ]; then
    cp "argen-code" "$BUILD_DIR/usr/bin/argen-code"
else
    echo "Error: No se encontró 'argent-code.py' ni 'argen-code' en el directorio actual."
    exit 1
fi
chmod +x "$BUILD_DIR/usr/bin/argen-code"

# 5. Copiar tu icono SVG personalizado
if [ -f "argen-code.svg" ]; then
    cp "argen-code.svg" "$BUILD_DIR/usr/share/icons/hicolor/scalable/apps/argen-code.svg"
else
    echo "Aviso: No se encontró 'argen-code.svg'. Se usará un icono por defecto."
fi

# 6. Crear el archivo .desktop apuntando al nombre del icono
cat << EOF > "$BUILD_DIR/usr/share/applications/org.openargentos.argencode.desktop"
[Desktop Entry]
Name=Argen Code
Comment=Editor de código para Open Argentos
Exec=/usr/bin/argen-code %U
Icon=argen-code
Terminal=false
Type=Application
Categories=Development;TextEditor;IDE;
MimeType=text/plain;text/x-python;application/x-shellscript;
StartupNotify=true
StartupWMClass=org.openargentos.argencode
EOF

# 7. Compilar el paquete .deb corregido
dpkg-deb --build --root-owner-group "$BUILD_DIR"

echo "==> ¡Paquete generado con éxito con tu icono!"
echo "Archivo: ${BUILD_DIR}.deb"
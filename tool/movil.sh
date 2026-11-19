#!/usr/bin/env sh
# Prueba la app en el móvil.
#
#   ./tool/movil.sh        móvil Android conectado por USB (o wifi): instala y
#                          abre la app con hot reload (r = recargar, q = salir).
#                          Si no hay móvil, cae al modo web.
#   ./tool/movil.sh web    sirve la app por red: ábrela en el navegador del
#                          móvil (misma wifi o Tailscale). Sin hot reload en el
#                          móvil: recarga la página tras guardar con `r`.
set -e
cd "$(dirname "$0")/.."

modo="${1:-auto}"

if [ "$modo" != "web" ]; then
  # `-d android` no vale: hay que pasar el id del dispositivo. Se saca de la
  # línea de `flutter devices` cuya plataforma es android-*.
  id="$(flutter devices 2>/dev/null | grep "android-" | head -n1 | awk -F'•' '{gsub(/ /,"",$2); print $2}')"
  if [ -n "$id" ]; then
    exec flutter run -d "$id"
  fi
  if [ "$modo" = "android" ]; then
    echo "No veo ningún móvil Android. Conéctalo por USB con la depuración USB activada." >&2
    exit 1
  fi
  echo "No hay móvil Android conectado: sirvo la web."
fi

puerto=8080
echo
echo "Abre en el móvil:"
for ip in $(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1); do
  echo "  http://$ip:$puerto"
done
echo
exec flutter run -d web-server --web-hostname 0.0.0.0 --web-port "$puerto"

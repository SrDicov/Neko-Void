#!/bin/sh
# check-workflows.sh: el script que se ejecuta DENTRO del contenedor de cada
# workflow tiene que ser shell valido.
#
# ponytail: con `sh -c '...'` (comillas simples) cualquier comilla simple
# dentro del script (un comentario con 'jq', un -name '*patron*') CIERRA la
# cadena: el contenedor recibe un script truncado, no hace nada y sale con 0.
# El build 'pasa' sin generar la ISO. Por eso el script va en un heredoc
# (<<'EOS'), donde las comillas son literales, y este check lo extrae y lo
# valida con 'sh -n'.
#
# Uso: sh tools/check-workflows.sh

set -eu

cd "$(dirname "$0")/.."
WORKFLOWS=".github/workflows"

errors=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for wf in "$WORKFLOWS"/*.yml; do
	name="$(basename "$wf")"

	# El contenedor no debe usar la forma frágil con comillas simples.
	if grep -q "sh -c '" "$wf"; then
		echo "ERROR: $name usa 'sh -c ...' para el script del contenedor." >&2
		echo "       Usa un heredoc (<<'EOS') : las comillas simples dentro" >&2
		echo "       del script truncarian el comando en silencio." >&2
		errors=$((errors + 1))
		continue
	fi

	# Extrae cada heredoc EOS y lo valida.
	awk -v out="$tmp" '
		/<<.EOS./ { inh = 1; n++; file = out "/script." n; next }
		inh && /^[[:space:]]*EOS[[:space:]]*$/ { inh = 0; next }
		inh { print > file }
	' "$wf"

	for f in "$tmp"/script.*; do
		[ -f "$f" ] || continue
		# Dedent: el heredoc de un run: de YAML conserva la indentacion.
		sed -e 's/^[[:space:]]*//' "$f" > "$f.flat"
		if ! sh -n "$f.flat" 2>"$f.err"; then
			echo "ERROR: $name: el script del contenedor no es shell valido:" >&2
			sed 's/^/    /' "$f.err" >&2
			errors=$((errors + 1))
		fi
	done
	rm -f "$tmp"/script.*
done

if [ "$errors" -ne 0 ]; then
	echo "$errors problema(s) en los workflows" >&2
	exit 1
fi
echo "Workflows: los scripts del contenedor son shell valido."

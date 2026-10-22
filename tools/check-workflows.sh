#!/bin/sh
# check-workflows.sh: el script que se ejecuta DENTRO del contenedor de cada
# workflow tiene que ser shell valido, y su heredoc tiene que cerrar.
#
# ponytail: dos trampas, las dos bitten el dia que esto se escribio:
#
#  1) Con `sh -c '...'` (comillas simples) cualquier comilla simple dentro
#     del script (un comentario con 'jq', un -name '*patron*') CIERRA la
#     cadena: el contenedor recibe un script truncado, no hace nada y sale
#     con 0. El build 'pasa' sin generar la ISO. El script va en un heredoc
#     (<<'EOS'), donde las comillas son literales.
#
#  2) El terminador del heredoc tiene que estar en la columna 0 del script
#     que se ejecuta, es decir en la indentacion base del bloque `run: |`
#     (no en la del comando que lo abre). Si no, bash avisa "here-document
#     delimited by end-of-file" y el script se trunca igual de silencioso.
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

	# 1) el contenedor no debe usar la forma fragil con comillas simples
	if grep -q "sh -c '" "$wf"; then
		echo "ERROR: $name usa 'sh -c ...' para el script del contenedor." >&2
		echo "       Usa un heredoc (<<'EOS'): las comillas simples dentro" >&2
		echo "       del script truncan el comando en silencio." >&2
		errors=$((errors + 1))
		continue
	fi

	# 1b) si el script va por heredoc, el docker run necesita -i (stdin).
	#     Sin -i, sh -s lee un script vacio: el contenedor sale con 0 y el
	#     build 'pasa' sin generar la ISO.
	if grep -q "<<'EOS'" "$wf"; then
		grep -E '^[[:space:]]*docker run' "$wf" | grep -qv -- '-i' &&
			{
				echo "ERROR: $name: el script del contenedor va por heredoc pero el" >&2
				echo "       'docker run' no tiene -i: sh -s leeria un script vacio." >&2
				errors=$((errors + 1))
				continue
			}
	fi

	# 2) heredocs bien cerrados y cuerpo del bloque con shell valido
	rm -f "$tmp/body"
	awk -v out="$tmp" -v wf="$name" '
		function indent(s) { match(s, /^ */); return RLENGTH }
		function fail(msg) { printf "ERROR: %s: %s\n", wf, msg > "/dev/stderr"; bad = 1 }
		/^[[:space:]]*run: \|[[:space:]]*$/ { inrun = 1; base = -1; inh = 0; next }
		inrun && /^[[:space:]]*$/ { next }
		inrun && base < 0 { base = indent($0) }
		inrun && indent($0) < base {
			if (inh) fail("el heredoc no tiene terminador EOS")
			inrun = 0; next
		}
		inrun && /<<.EOS./ { inh = 1; next }
		inrun && /^[[:space:]]*EOS[[:space:]]*$/ {
			if (indent($0) != base)
				fail(sprintf("el terminador EOS esta a %d espacios y el bloque run: a %d (el heredoc no cierra)", indent($0), base))
			inh = 0; next
		}
		inrun { print > (out "/body") }
		END { if (inh) fail("el heredoc no tiene terminador EOS"); exit (bad ? 1 : 0) }
	' "$wf" 2>"$tmp/err" || {
		cat "$tmp/err" >&2
		errors=$((errors + 1))
		continue
	}

	# El cuerpo (ya dedentado por el bloque) tiene que ser shell.
	if [ -s "$tmp/body" ]; then
		if ! sh -n "$tmp/body" 2>"$tmp/shn.err"; then
			echo "ERROR: $name: el script del contenedor no es shell valido:" >&2
			sed 's/^/    /' "$tmp/shn.err" >&2
			errors=$((errors + 1))
		fi
	fi
done

if [ "$errors" -ne 0 ]; then
	echo "$errors problema(s) en los workflows" >&2
	exit 1
fi
echo "Workflows: heredocs bien cerrados y scripts del contenedor validos."

#!/usr/bin/env bash
# Lists installed packages of one source as TSV (one line per package):
#   source  name  version  size_bytes  reason(explicit|dep)  repo  kind  epoch  description
# kind/epoch say when the package was last run, judged from the access time of its executables:
#   used  <epoch>  an executable was accessed after the package was (re)installed
#   idle  <epoch>  nothing was accessed since the install/update at <epoch>
#   ""    0        no executables to judge by (libraries, data)
# Usage: list.sh pacman|flatpak|npm|bun|cargo|pipx|go|dotnet|sdkman|nvm
# "pacman" prints both repo packages (source pacman) and foreign ones (source aur).
export LC_ALL=C
export PATH="$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/.local/bin:$HOME/.dotnet/tools:/usr/local/go/bin:$HOME/go/bin:$PATH"
for d in "$HOME"/.nvm/versions/node/*/bin; do [ -d "$d" ] && PATH="$d:$PATH"; done

have() { command -v "$1" >/dev/null 2>&1; }

# An install/update sets atime = ctime (3057 of ~4100 executables here; the rest of the exact matches
# are off by 1-2 s). Anything later than SLACK seconds is a real access.
SLACK=2
# Minutes in which this many files were all accessed at once are scans (backup, indexer, pacman -Qkk), not use.
BULK=25

# usage_of FILE... -> "kind<TAB>epoch" from the newest access among the files.
usage_of() {
    local now a c best_a=0 best_c=0 any=0
    now=$(date +%s)
    while read -r a c; do
        any=1
        (( c > best_c )) && best_c=$c
        (( a > c + SLACK && a <= now && a > best_a )) && best_a=$a
    done < <(stat -L -c '%X %Z' "$@" 2>/dev/null)
    if (( ! any )); then printf '\t0'
    elif (( best_a )); then printf 'used\t%s' "$best_a"
    else printf 'idle\t%s' "$best_c"; fi
}

# pkg<TAB>kind<TAB>epoch for every pacman package that ships executables.
pacman_usage() {
    local list stats
    list=$(pacman -Ql 2>/dev/null | awk '{ p = $1; sub(/^[^ ]+ /, ""); if ($0 ~ /^\/(usr\/(s?bin|local\/bin)|opt\/[^\/]+\/bin)\/[^\/]+$/) print p "\t" $0 }')
    stats=$(cut -f2 <<<"$list" | tr '\n' '\0' | xargs -0 stat -L -c '%n|%X|%Z' 2>/dev/null)
    awk -v now="$(date +%s)" -v slack="$SLACK" -v bulk="$BULK" '
        BEGIN { FS = "\t" }
        FNR == 1 { fi++ }
        fi == 1 { owner[$2] = $1; next }
        {
            n = split($0, f, "|"); c = f[n]; a = f[n - 1]
            path = substr($0, 1, length($0) - length(a) - length(c) - 2)
            if (!(path in owner)) next
            k++; P[k] = path; A[k] = a; C[k] = c
            if (a > c + slack && a <= now) bucket[int(a / 60)]++
        }
        END {
            for (i = 1; i <= k; i++) {
                p = owner[P[i]]; has[p] = 1
                if (C[i] > ref[p]) ref[p] = C[i]
                if (A[i] > C[i] + slack && A[i] <= now && bucket[int(A[i] / 60)] < bulk && A[i] > used[p]) used[p] = A[i]
            }
            for (p in has) printf "%s\t%s\t%d\n", p, (used[p] ? "used" : "idle"), (used[p] ? used[p] : ref[p])
        }' <(printf '%s\n' "$list") <(printf '%s\n' "$stats")
}

list_pacman() {
    have pacman || return
    awk '
        function tobytes(s,   a, n) {
            split(s, a, " "); n = a[1]
            if (a[2] == "KiB") n *= 1024; else if (a[2] == "MiB") n *= 1048576; else if (a[2] == "GiB") n *= 1073741824
            return int(n)
        }
        function val(   v) { v = $0; sub(/^[^:]*: */, "", v); return v }
        function flush(   r) {
            if (name == "") return
            r = repo[name]
            printf "%s\t%s\t%s\t%d\t%s\t%s\t%s\t%d\t%s\n", (r == "" ? "aur" : "pacman"), name, ver, size, reason, r, ukind[name], uepoch[name], desc
            name = ""
        }
        FNR == 1 { fi++ }
        # Split by hand: changing FS mid-file would only apply from the next record on.
        fi == 1 { split($0, u, "\t"); ukind[u[1]] = u[2]; uepoch[u[1]] = u[3]; next }
        fi == 2 { split($0, r, " "); repo[r[2]] = r[1]; next }
        /^Name +:/ { flush(); name = val(); ver = ""; desc = ""; size = 0; reason = "explicit"; next }
        /^Version +:/ { ver = val(); next }
        /^Description +:/ { desc = val(); next }
        /^Installed Size +:/ { size = tobytes(val()); next }
        /^Install Reason +:/ { reason = ($0 ~ /Explicitly/) ? "explicit" : "dep"; next }
        END { flush() }
    ' <(pacman_usage) <(pacman -Sl 2>/dev/null) <(pacman -Qi 2>/dev/null)
}

list_flatpak() {
    have flatpak || return
    local kind id loc map
    # Apps only: id<TAB>kind<TAB>epoch, judged from the files in the app's bin/ directory.
    map=$(flatpak list --app --columns=application 2>/dev/null | while read -r id; do
        loc=$(flatpak info --show-location "$id" 2>/dev/null)
        printf '%s\t%s\n' "$id" "$(usage_of "$loc"/files/bin/*)"
    done)
    for kind in app runtime; do
        flatpak list "--$kind" --columns=name,application,version,branch,size,description 2>/dev/null |
        awk -F'\t' -v kind="$kind" -v map="$map" '
            function tobytes(s,   a, n) {
                gsub("\302\240", " ", s)   # flatpak puts a no-break space before the unit
                n = split(s, a, " "); if (n < 2) return 0
                if (a[2] == "kB") return int(a[1] * 1e3); if (a[2] == "MB") return int(a[1] * 1e6)
                if (a[2] == "GB") return int(a[1] * 1e9); if (a[2] == "bytes") return int(a[1])
                return 0
            }
            BEGIN {
                n = split(map, lines, "\n")
                for (i = 1; i <= n; i++) { split(lines[i], f, "\t"); uk[f[1]] = f[2]; ue[f[1]] = f[3] }
            }
            {
                # Runtimes share display names across branches (Mesa, Mesa...): show the ID instead.
                name = (kind == "app") ? $1 : $2
                ver = ($3 != "") ? $3 : $4
                desc = (kind == "app") ? $2 : $1 " (" $4 ")"
                if ($6 != "") desc = desc " — " $6
                printf "flatpak\t%s\t%s\t%d\t%s\t\t%s\t%d\t%s\n", name, ver, tobytes($5), (kind == "app" ? "explicit" : "dep"), (kind == "app" ? uk[$2] : ""), (kind == "app" ? ue[$2] : 0), desc
            }'
    done
}

list_npm() {
    have npm && have node || return
    local root
    root=$(npm root -g 2>/dev/null) || return
    node -e '
        const fs = require("fs"), p = require("path"), r = process.argv[1];
        for (const n of fs.readdirSync(r)) {
            const dirs = n.startsWith("@") ? fs.readdirSync(p.join(r, n)).map(x => p.join(n, x)) : [n];
            for (const d of dirs) {
                try {
                    const j = JSON.parse(fs.readFileSync(p.join(r, d, "package.json")));
                    console.log(["npm", j.name || d, j.version || "", 0, "explicit", "", "", 0, (j.description || "")].join("\t"));
                } catch {}
            }
        }' "$root" 2>/dev/null
}

list_bun() {
    have bun || return
    bun pm ls -g 2>/dev/null | sed -nE 's/^[├└]── (.+)@([^@]+)$/bun\t\1\t\2\t0\texplicit\t\t\t0\t/p'
}

list_cargo() {
    have cargo || return
    cargo install --list 2>/dev/null | awk '/^[^ ]/ { v = $2; sub(/^v/, "", v); sub(/:$/, "", v); printf "cargo\t%s\t%s\t0\texplicit\t\t\t0\t\n", $1, v }'
}

# Read the venv metadata directly: `pipx list` hides venvs whose interpreter is gone.
list_pipx() {
    have jq || return
    local base="${PIPX_HOME:-$HOME/.local/share/pipx}/venvs" m
    [ -d "$base" ] || return
    for m in "$base"/*/pipx_metadata.json; do
        [ -f "$m" ] || continue
        jq -r --arg d "$(basename "$(dirname "$m")")" '["pipx", $d, (.main_package.package_version // ""), 0, "explicit", "", "", 0, ""] | @tsv' "$m"
    done
}

list_go() {
    have go || return
    local dir f info
    dir=${GOBIN:-$(go env GOPATH 2>/dev/null)/bin}
    [ -d "$dir" ] || return
    for f in "$dir"/*; do
        [ -f "$f" ] || continue
        info=$(go version -m "$f" 2>/dev/null | awk '$1 == "path" { p = $2 } $1 == "mod" { v = $3 } END { printf "%s\t%s", v, p }')
        printf 'go\t%s\t%s\t%s\texplicit\t\t%s\t%s\n' "$(basename "$f")" "${info%%$'\t'*}" "$(stat -c %s "$f")" \
            "$(usage_of "$f")" "${info#*$'\t'}"
    done
}

list_dotnet() {
    have dotnet || return
    dotnet tool list -g 2>/dev/null | awk 'NR > 2 && NF >= 2 { printf "dotnet\t%s\t%s\t0\texplicit\t\t\t0\t%s\n", $1, $2, $3 }'
}

# SDKMAN candidates: ~/.sdkman/candidates/<name>/<version>
list_sdkman() {
    local base="$HOME/.sdkman/candidates" c v cur
    [ -d "$base" ] || return
    for c in "$base"/*/; do
        c=${c%/}
        cur=$(readlink "$c/current" 2>/dev/null)
        for v in "$c"/*/; do
            v=${v%/}; [ -L "$v" ] && continue
            printf 'sdkman\t%s\t%s\t%s\texplicit\t\t%s\t%s\n' "$(basename "$c")" "$(basename "$v")" \
                "$(du -sb "$v" 2>/dev/null | cut -f1)" "$(usage_of "$v"/bin/*)" \
                "$([ "$(basename "$v")" = "$(basename "$cur")" ] && echo "current")"
        done
    done
}

# Node versions installed through nvm.
list_nvm() {
    local base="$HOME/.nvm/versions/node" v def
    [ -d "$base" ] || return
    def=$(cat "$HOME/.nvm/alias/default" 2>/dev/null)
    for v in "$base"/*/; do
        v=${v%/}
        printf 'nvm\tnode\t%s\t%s\texplicit\t\t%s\t%s\n' "$(basename "$v")" "$(du -sb "$v" 2>/dev/null | cut -f1)" \
            "$(usage_of "$v/bin/node")" \
            "$([[ "$(basename "$v")" == v${def#v}* ]] && echo "default")"
    done
}

case "$1" in
    pacman|flatpak|npm|bun|cargo|pipx|go|dotnet|sdkman|nvm) "list_$1" ;;
    *) echo "usage: $0 pacman|flatpak|npm|bun|cargo|pipx|go|dotnet|sdkman|nvm" >&2; exit 2 ;;
esac

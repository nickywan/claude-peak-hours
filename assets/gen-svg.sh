#!/bin/bash
# Generate SVG screenshots from statusline ANSI output
# Usage: bash assets/gen-svg.sh

cd "$(dirname "$0")/.."

MOCK_INPUT='{"model":{"display_name":"Opus 4.6 (1M context)"},"cwd":"/home/nickywan/dev/projects/claude/plugin/claude-peak-hours","context_window":{"remaining_percentage":87},"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":1774944000},"seven_day":{"used_percentage":31,"resets_at":1775228400}}}'

ansi_to_svg() {
    local output_file="$1"
    local width="${2:-950}"
    shift 2
    # Remaining args are lines of ANSI text
    local lines=("$@")

    node -e '
const lines = JSON.parse(process.argv[1]);
const width = parseInt(process.argv[2]);
const outFile = process.argv[3];

const lineHeight = 20;
const padY = 14;
const padX = 14;
const totalHeight = padY * 2 + lines.length * lineHeight;

function parseAnsi(text) {
    let spans = "";
    let color = "#d4d4d4";
    let isBold = false;
    let isDim = false;

    const parts = text.split(/(\x1b\[[0-9;]*m)/);
    for (const part of parts) {
        if (part.startsWith("\x1b[")) {
            const code = part.slice(2, -1);
            if (code === "0") { color = "#d4d4d4"; isBold = false; isDim = false; continue; }
            if (code === "1") { isBold = true; continue; }
            if (code === "2") { isDim = true; continue; }
            const m = code.match(/^38;2;(\d+);(\d+);(\d+)$/);
            if (m) { color = `rgb(${m[1]},${m[2]},${m[3]})`; continue; }
        } else if (part.length > 0) {
            const esc = part.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
            const op = isDim ? "0.55" : "1";
            const fw = isBold ? "bold" : "normal";
            spans += `<tspan fill="${color}" font-weight="${fw}" opacity="${op}">${esc}</tspan>`;
        }
    }
    return spans;
}

let textEls = "";
for (let i = 0; i < lines.length; i++) {
    const y = padY + (i + 1) * lineHeight - 4;
    textEls += `<text x="${padX}" y="${y}" font-family="Menlo,Monaco,Consolas,\x27Courier New\x27,monospace" font-size="13" fill="#d4d4d4">${parseAnsi(lines[i])}</text>\n`;
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${totalHeight}">
<rect width="100%" height="100%" rx="8" fill="#1e1e1e"/>
${textEls}</svg>`;

require("fs").writeFileSync(outFile, svg);
console.log("Generated:", outFile, `(${lines.length} lines, ${width}x${totalHeight})`);
' "$(printf '%s\n' "${lines[@]}" | jq -R . | jq -s .)" "$width" "$output_file"
}

echo "=== Generating SVG screenshots ==="

# Minimal off-peak FR 24h
echo "1/4: minimal off-peak (FR, 24h)"
output=$(echo "$MOCK_INPUT" | bash bin/statusline.sh --24h --lang fr 2>/dev/null)
ansi_to_svg "assets/minimal-offpeak-fr.svg" 950 "$output"

# Minimal off-peak EN 12h
echo "2/4: minimal off-peak (EN, 12h)"
output=$(echo "$MOCK_INPUT" | bash bin/statusline.sh --12h --lang en 2>/dev/null)
ansi_to_svg "assets/minimal-offpeak-en.svg" 950 "$output"

# Full mode FR 24h
echo "3/4: full mode (FR, 24h)"
full_output=$(echo "$MOCK_INPUT" | bash bin/statusline.sh --full --24h --lang fr 2>/dev/null)
line1=$(echo "$full_output" | sed -n '1p')
line2=$(echo "$full_output" | sed -n '3p')
line3=$(echo "$full_output" | sed -n '4p')
ansi_to_svg "assets/full-fr.svg" 950 "$line1" "" "$line2" "$line3"

# Full mode EN 12h
echo "4/4: full mode (EN, 12h)"
full_output=$(echo "$MOCK_INPUT" | bash bin/statusline.sh --full --12h --lang en 2>/dev/null)
line1=$(echo "$full_output" | sed -n '1p')
line2=$(echo "$full_output" | sed -n '3p')
line3=$(echo "$full_output" | sed -n '4p')
ansi_to_svg "assets/full-en.svg" 950 "$line1" "" "$line2" "$line3"

echo "=== Done ==="

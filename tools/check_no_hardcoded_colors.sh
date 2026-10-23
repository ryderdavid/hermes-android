#!/usr/bin/env bash
# Fails when app code hardcodes a color instead of using the color scheme.
#
#   tools/check_no_hardcoded_colors.sh [ROOT]     (default ROOT: lib)
#
# Flags `Color(0x…)`, `Color.fromARGB/fromRGBO(…)` and `Colors.<name>` in Dart
# files under ROOT. Allowed:
#   - the theme module (core/theme/) and generated l10n (l10n/), where colors
#     are defined;
#   - Colors.transparent, which is the absence of a color;
#   - a line ending in `// allow-hardcoded-color`, for deliberate exceptions
#     such as a black media viewer.
set -euo pipefail

root="${1:-lib}"
pattern='Color\(0x|Color\.from(ARGB|RGBO)\(|Colors\.[a-zA-Z]'

matches=$(grep -rnE --include='*.dart' "$pattern" "$root" \
  | grep -vE '(^|/)core/theme/|(^|/)l10n/' \
  | grep -vE 'allow-hardcoded-color' \
  | grep -vE 'Colors\.transparent' || true)

# A line can mix an allowed and a forbidden use; re-check what is left.
offenders=$(printf '%s\n' "$matches" \
  | sed -E 's/Colors\.transparent//g' \
  | grep -E "$pattern" || true)

if [[ -n "$offenders" ]]; then
  echo "Hardcoded colors found; use Theme.of(context).colorScheme or HermesTokens:" >&2
  printf '%s\n' "$offenders" >&2
  exit 1
fi
echo "No hardcoded colors under $root."

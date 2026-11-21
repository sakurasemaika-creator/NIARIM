#!/bin/bash
# Probe the local wrangler dev Worker for routing / 404 / canonical behaviour.
B=http://127.0.0.1:8802
probe() {
  local m="$1" p="$2"
  local out
  out=$(curl -s -o /tmp/claude-0/-home-user/c76781dd-e3f8-52a1-af75-d04751258bd4/scratchpad/r2-web/w017body -D - -X "$m" --path-as-is "$B$p" 2>/dev/null)
  local code loc robots ctype canon title
  code=$(printf '%s' "$out" | head -1 | awk '{print $2}')
  loc=$(printf '%s' "$out" | grep -i '^location:' | tr -d '\r' | cut -c11-)
  robots=$(printf '%s' "$out" | grep -i '^x-robots-tag:' | tr -d '\r' | cut -c15-)
  ctype=$(printf '%s' "$out" | grep -i '^content-type:' | tr -d '\r' | cut -c15- | cut -d';' -f1)
  canon=$(grep -o '<link rel="canonical" href="[^"]*"' /tmp/claude-0/-home-user/c76781dd-e3f8-52a1-af75-d04751258bd4/scratchpad/r2-web/w017body 2>/dev/null | head -1 | cut -d'"' -f4)
  title=$(grep -o '<title>[^<]*' /tmp/claude-0/-home-user/c76781dd-e3f8-52a1-af75-d04751258bd4/scratchpad/r2-web/w017body 2>/dev/null | head -1 | cut -c8-)
  robotsMeta=$(grep -o '<meta name="robots" content="[^"]*"' /tmp/claude-0/-home-user/c76781dd-e3f8-52a1-af75-d04751258bd4/scratchpad/r2-web/w017body 2>/dev/null | head -1 | cut -d'"' -f4)
  printf '%-5s %-42s %s loc=%s xrobots=%s meta=%s type=%s canon=%s title=%s\n' "$m" "$p" "$code" "$loc" "$robots" "$robotsMeta" "$ctype" "$canon" "$title"
}
for p in /account-deletion/ /account-deletion /font-licenses/ "/account-deletion/?lang=ko" /api/account-deletion/ /api/account-deletion/config / /about/ /about /about/index.html /index.html /about/?lang=fr '/about/?lang=xx' /ABOUT/ /no-such-page /no-such-page/ /about/extra /features/foo.html /404.html /404 '/%E3%81%82' '/%E0%A4%A' '/about/?lang=%ZZ' '//about/' '/about//' '/../etc/passwd' /api/ /api/unknown /api/contact /robots.txt /sitemap.xml /favicon.ico /js/main.js /js/none.js /css/none.css /assets/none.png; do
  probe GET "$p"
done
for p in / /about/ /no-such-page /api/contact; do probe HEAD "$p"; done
probe POST /about/
rm -f /tmp/claude-0/-home-user/c76781dd-e3f8-52a1-af75-d04751258bd4/scratchpad/r2-web/w017body

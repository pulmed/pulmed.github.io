#!/usr/bin/env bash
set -euo pipefail

slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g'
}

trim() {
  echo "$1" | sed -E 's/^\s+|\s+$//g'
}

normalize_name() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9 ]+/ /g; s/[[:space:]]+/ /g; s/^ //; s/ $//'
}

name_initial() {
  local first_token
  first_token="$(echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z ]+/ /g; s/[[:space:]]+/ /g; s/^ //; s/ .*//')"
  echo "${first_token:0:1}"
}

declare -A AUTHOR_FULL_MAP=()
declare -A AUTHOR_LASTINIT_COUNT=()
declare -A AUTHOR_LASTINIT_MAP=()
declare -A AUTHOR_ALIAS_MAP=()

load_author_aliases() {
  local aliases_file="scripts/author-aliases.tsv"
  [[ -f "$aliases_file" ]] || return 0

  while IFS=$'\t' read -r alias_name slug; do
    alias_name="$(trim "${alias_name:-}")"
    slug="$(trim "${slug:-}")"
    [[ -z "$alias_name" || -z "$slug" ]] && continue
    [[ "$alias_name" =~ ^# ]] && continue

    AUTHOR_ALIAS_MAP["$(normalize_name "$alias_name")"]="$slug"
  done < "$aliases_file"
}

load_local_authors() {
  local profile slug title first_name last_name full_name
  for profile in content/authors/*/_index.md; do
    [[ -f "$profile" ]] || continue

    slug="$(basename "$(dirname "$profile")")"
    title="$(sed -nE 's/^title:\s*(.*)$/\1/p' "$profile" | head -n1 | sed -E 's/^"|"$//g')"
    first_name="$(sed -nE 's/^first_name:\s*(.*)$/\1/p' "$profile" | head -n1 | sed -E 's/^"|"$//g')"
    last_name="$(sed -nE 's/^last_name:\s*(.*)$/\1/p' "$profile" | head -n1 | sed -E 's/^"|"$//g')"

    full_name="$title"
    if [[ -n "$first_name" && -n "$last_name" ]]; then
      full_name="${first_name} ${last_name}"
    fi

    for candidate in "$full_name" "$title"; do
      candidate="$(trim "$candidate")"
      [[ -z "$candidate" ]] && continue
      AUTHOR_FULL_MAP["$(normalize_name "$candidate")"]="$slug"
    done

    if [[ -n "$first_name" && -n "$last_name" ]]; then
      local first_initial last_key li_key count
      first_initial="$(name_initial "$first_name")"
      last_key="$(normalize_name "$last_name")"
      if [[ -n "$first_initial" && -n "$last_key" ]]; then
        li_key="${first_initial}|${last_key}"
        count="${AUTHOR_LASTINIT_COUNT[$li_key]:-0}"
        AUTHOR_LASTINIT_COUNT[$li_key]="$((count + 1))"
        AUTHOR_LASTINIT_MAP[$li_key]="$slug"
      fi
    fi
  done
}

resolve_author_slug() {
  local author_full="$1"
  local given_name="$2"
  local family_name="$3"
  local full_key alias_slug direct_slug first_initial last_key li_key

  full_key="$(normalize_name "$author_full")"
  alias_slug="${AUTHOR_ALIAS_MAP[$full_key]:-}"
  if [[ -n "$alias_slug" ]]; then
    echo "$alias_slug"
    return 0
  fi

  direct_slug="${AUTHOR_FULL_MAP[$full_key]:-}"
  if [[ -n "$direct_slug" ]]; then
    echo "$direct_slug"
    return 0
  fi

  if [[ -z "$family_name" && "$author_full" == *" "* ]]; then
    family_name="${author_full##* }"
    given_name="${author_full% ${family_name}}"
  fi

  first_initial="$(name_initial "$given_name")"
  last_key="$(normalize_name "$family_name")"
  if [[ -n "$first_initial" && -n "$last_key" ]]; then
    li_key="${first_initial}|${last_key}"
    if [[ "${AUTHOR_LASTINIT_COUNT[$li_key]:-0}" -eq 1 ]]; then
      echo "${AUTHOR_LASTINIT_MAP[$li_key]}"
      return 0
    fi
  fi

  return 1
}

load_author_aliases
load_local_authors

if [[ $# -eq 1 ]]; then
  # Simple mode: DOI only.
  doi="$1"
  publication_type="article-journal"
  abstract=""
  pdf_url=""
  source_url="https://doi.org/${doi}"

  bibtex_tmp="$(mktemp)"
  crossref_tmp="$(mktemp)"
  curl -fsSL -LH "Accept: application/x-bibtex" "https://doi.org/${doi}" > "$bibtex_tmp"
  curl -fsSL "https://api.crossref.org/works/${doi}" > "$crossref_tmp" || true

  bibtex_one_line="$(tr '\n' ' ' < "$bibtex_tmp" | sed -E 's/[[:space:]]+/ /g')"

  title="$(echo "$bibtex_one_line" | sed -nE 's/.*title=\{([^}]*)\}.*/\1/p')"
  journal="$(echo "$bibtex_one_line" | sed -nE 's/.*journal=\{([^}]*)\}.*/\1/p')"
  year="$(echo "$bibtex_one_line" | sed -nE 's/.*year=\{([0-9]{4})\}.*/\1/p')"
  month_raw="$(echo "$bibtex_one_line" | sed -nE 's/.*month=\{?([^,}\ ]+)\}?.*/\1/p')"
  authors_raw="$(echo "$bibtex_one_line" | sed -nE 's/.*author=\{([^}]*)\}.*/\1/p')"

  crossref_one_line="$(tr '\n' ' ' < "$crossref_tmp" | sed -E 's/[[:space:]]+/ /g')"
  abstract_raw="$(echo "$crossref_one_line" | sed -nE 's/.*"abstract":"([^"]+)".*/\1/p')"
  if [[ -n "$abstract_raw" ]]; then
    abstract="$(echo "$abstract_raw" \
      | sed -E 's/\\u003c/</g; s/\\u003e/>/g; s/\\n/ /g; s/\\"/"/g; s/<[^>]+>/ /g; s/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g; s/[[:space:]]+/ /g; s/^ //; s/ $//')"
  fi

  authors_yaml=""
  if [[ -n "$authors_raw" ]]; then
    while IFS= read -r author_entry; do
      local_slug=""
      given=""
      family=""
      author_entry="$(echo "$author_entry" | sed -E 's/^\s+|\s+$//g')"
      [[ -z "$author_entry" ]] && continue

      if [[ "$author_entry" == *,* ]]; then
        family="$(echo "$author_entry" | sed -E 's/,.*//')"
        given="$(echo "$author_entry" | sed -E 's/^[^,]+,\s*//')"
        author_full="${given} ${family}"
      else
        author_full="$author_entry"
      fi

      author_full="$(echo "$author_full" | sed -E 's/^\s+|\s+$//g')"
      [[ -z "$author_full" ]] && continue

      if local_slug="$(resolve_author_slug "$author_full" "$given" "$family")"; then
        authors_yaml+="  - ${local_slug}"$'\n'
      else
        safe_author="$(echo "$author_full" | sed -E 's/"/\\"/g')"
        authors_yaml+="  - \"${safe_author}\""$'\n'
      fi
    done < <(echo "$authors_raw" | sed -E 's/ and /\n/g')
  fi

  if [[ -z "$title" ]]; then
    title="Untitled publication"
  fi

  if [[ -z "$journal" ]]; then
    publication="*Unknown Journal*"
  else
    publication="*${journal}*"
  fi

  first_author="unknown"
  if [[ -n "$authors_raw" ]]; then
    first_author_entry="$(echo "$authors_raw" | sed -E 's/ and .*//')"
    first_author_candidate="$(echo "$first_author_entry" | sed -E 's/,.*//')"
    if [[ -n "$first_author_candidate" ]]; then
      first_author="$(slugify "$first_author_candidate")"
    fi
  fi

  if [[ -z "$year" ]]; then
    year="$(date -u +%Y)"
  fi

  month_num="01"
  case "$(echo "$month_raw" | tr '[:upper:]' '[:lower:]')" in
    jan|january) month_num="01" ;;
    feb|february) month_num="02" ;;
    mar|march) month_num="03" ;;
    apr|april) month_num="04" ;;
    may) month_num="05" ;;
    jun|june) month_num="06" ;;
    jul|july) month_num="07" ;;
    aug|august) month_num="08" ;;
    sep|sept|september) month_num="09" ;;
    oct|october) month_num="10" ;;
    nov|november) month_num="11" ;;
    dec|december) month_num="12" ;;
  esac

  pub_date="${year}-${month_num}-01"

  title_slug="$(echo "$title" | awk '{for (i=1; i<=NF && i<=8; i++) printf (i==1 ? $i : "-"$i)}')"
  title_slug="$(slugify "$title_slug")"
  if [[ -z "$title_slug" ]]; then
    title_slug="publication"
  fi

  slug="${first_author}-${year}-${title_slug}"
  slug="$(echo "$slug" | cut -c1-80)"

  target_dir="content/publications/manuscripts/${slug}"
  if [[ -e "$target_dir" ]]; then
    doi_slug="$(slugify "$doi")"
    slug="${first_author}-${year}-${doi_slug}"
    target_dir="content/publications/manuscripts/${slug}"
  fi

  if [[ -e "$target_dir" ]]; then
    echo "Error: $target_dir already exists"
    rm -f "$bibtex_tmp" "$crossref_tmp"
    exit 1
  fi

  mkdir -p "$target_dir"
  cp "$bibtex_tmp" "$target_dir/cite.bib"
  rm -f "$bibtex_tmp" "$crossref_tmp"

elif [[ $# -ge 4 && $# -le 5 ]]; then
  # Advanced mode: fully specified metadata.
  slug="$1"
  doi="$2"
  title="$3"
  publication="$4"
  publication_type="${5:-article-journal}"
  authors_yaml=""
  pub_date="$(date -u +%Y-%m-%d)"
  abstract=""
  pdf_url=""
  source_url="https://doi.org/${doi}"

  target_dir="content/publications/manuscripts/${slug}"
  if [[ -e "$target_dir" ]]; then
    echo "Error: $target_dir already exists"
    exit 1
  fi

  mkdir -p "$target_dir"

  # Fetch BibTeX from DOI resolver.
  curl -fsSL -LH "Accept: application/x-bibtex" "https://doi.org/${doi}" > "$target_dir/cite.bib"

else
  echo "Usage (simple):   $0 <doi>"
  echo "Usage (advanced): $0 <slug> <doi> <title> <publication> [publication_type]"
  echo "Example:          $0 10.1016/j.ejca.2025.116065"
  exit 1
fi

# Try to fetch a graphical abstract or social preview image from the DOI landing page.
# Note: always verify that you have rights to reuse the downloaded image.
doi_url="https://doi.org/${doi}"
landing_tmp="$(mktemp)"
resolved_doi_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "$doi_url" || true)"
curl -fsSL -L "$doi_url" -o "$landing_tmp" || true

# Try to capture source URL and PII from Elsevier redirect page.
encoded_redirect="$(sed -nE 's/.*name="redirectURL" value="([^"]+)".*/\1/p' "$landing_tmp" | head -n1 || true)"
pii="$(sed -nE 's/.*name="id" value="([^"]+)".*/\1/p' "$landing_tmp" | head -n1 || true)"
if [[ -n "$encoded_redirect" ]]; then
  source_url="$(printf '%b' "${encoded_redirect//%/\\x}")"
fi

# Prefer explicit PDF URL metadata if provided by the publisher page.
pdf_meta_tag="$(grep -ioE "<meta[^>]+(name|property)=[\"']citation_pdf_url[\"'][^>]*>" "$landing_tmp" | head -n1 || true)"
if [[ -n "$pdf_meta_tag" ]]; then
  pdf_candidate="$(echo "$pdf_meta_tag" | sed -nE "s/.*content=[\"']([^\"']+)[\"'].*/\1/p")"
  if [[ -n "$pdf_candidate" ]]; then
    pdf_url="$pdf_candidate"
  fi
fi

# Abstract fallback from landing page meta description.
if [[ -z "$abstract" ]]; then
  meta_desc="$(grep -ioE "<meta[^>]+(name|property)=[\"'](description|og:description)[\"'][^>]*>" "$landing_tmp" | head -n1 || true)"
  if [[ -n "$meta_desc" ]]; then
    abstract="$(echo "$meta_desc" | sed -nE "s/.*content=[\"']([^\"']+)[\"'].*/\1/p")"
  fi
fi
if [[ -z "$abstract" ]]; then
  abstract="Abstract not available from DOI metadata; please paste the abstract manually."
fi

# Build tags from DOI metadata keywords where available.
tag_candidates=""

# Ensure imported records can be filtered as manuscripts.
tag_candidates+="Manuscript"$'\n'

# 1) Crossref subjects (if available in simple mode).
if [[ -n "${crossref_one_line:-}" ]]; then
  subjects_block="$(echo "$crossref_one_line" | grep -oE '"subject":\[[^]]*\]' | head -n1 || true)"
  if [[ -n "$subjects_block" ]]; then
    subjects_raw="$(echo "$subjects_block" | sed -E 's/^"subject":\[//; s/\]$//')"
    while IFS= read -r s; do
      s="$(trim "$s")"
      s="$(echo "$s" | sed -E 's/^"|"$//g')"
      [[ -z "$s" ]] && continue
      tag_candidates+="$s"$'\n'
    done < <(echo "$subjects_raw" | sed -E 's/",\s*"/\n/g')
  fi
fi

# 2) Keywords from landing page meta tags.
while IFS= read -r meta_tag; do
  [[ -z "$meta_tag" ]] && continue
  meta_content="$(echo "$meta_tag" | sed -nE "s/.*content=[\"']([^\"']+)[\"'].*/\1/p")"
  [[ -z "$meta_content" ]] && continue
  meta_content="$(echo "$meta_content" | sed -E 's/[[:space:]]*[,;|][[:space:]]*/\n/g')"
  while IFS= read -r kw; do
    kw="$(trim "$kw")"
    [[ -z "$kw" ]] && continue
    tag_candidates+="$kw"$'\n'
  done < <(echo "$meta_content")
done < <(grep -ioE "<meta[^>]+(name|property)=[\"'](citation_keywords|keywords|dc.subject)[\"'][^>]*>" "$landing_tmp" || true)

# 3) Fallback: derive a few topic tags from title if DOI metadata has no keywords.
if [[ -z "$(trim "$tag_candidates")" ]]; then
  title_clean="$(echo "$title" | sed -E 's/[^A-Za-z0-9 -]/ /g')"

  # Acronyms such as ML, DNA, AI.
  while IFS= read -r ac; do
    ac="$(trim "$ac")"
    [[ -z "$ac" ]] && continue
    tag_candidates+="$ac"$'\n'
  done < <(echo "$title_clean" | tr ' ' '\n' | grep -E '^[A-Z0-9]{2,}$' || true)

  # Common cancer phrase fallback.
  if echo "$title_clean" | grep -qi 'colorectal cancer'; then
    tag_candidates+="Colorectal Cancer"$'\n'
  fi
  if echo "$title_clean" | grep -qi 'pancreatic cancer'; then
    tag_candidates+="Pancreatic Cancer"$'\n'
  fi

  # Topic words fallback.
  while IFS= read -r w; do
    w="$(trim "$w")"
    [[ -z "$w" ]] && continue
    case "$(echo "$w" | tr '[:upper:]' '[:lower:]')" in
      a|an|the|and|or|for|with|from|into|in|on|of|to|by|at|novel|study|analysis|prediction|framework)
        continue
        ;;
    esac
    # Capitalize first letter.
    tag_word="$(echo "$w" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
    tag_candidates+="$tag_word"$'\n'
  done < <(echo "$title_clean" | tr ' ' '\n' | awk 'length($0) >= 5' | head -n 12)
fi

# Dedupe tags and keep a compact list.
declare -A seen_tags=()
tags_yaml=""
tag_count=0
while IFS= read -r t; do
  t="$(trim "$t")"
  [[ -z "$t" ]] && continue
  key="$(slugify "$t")"
  [[ -z "$key" ]] && continue
  if [[ -n "${seen_tags[$key]+x}" ]]; then
    continue
  fi
  seen_tags[$key]=1
  tags_yaml+="  - ${t}"$'\n'
  tag_count=$((tag_count + 1))
  if [[ $tag_count -ge 8 ]]; then
    break
  fi
done < <(echo "$tag_candidates")

image_url=""
for meta_key in citation_graphical_abstract og:image twitter:image; do
  tag="$(grep -ioE "<meta[^>]+(name|property)=[\"']${meta_key}[\"'][^>]*>" "$landing_tmp" | head -n1 || true)"
  if [[ -n "$tag" ]]; then
    image_url="$(echo "$tag" | sed -nE "s/.*content=[\"']([^\"']+)[\"'].*/\1/p")"
    if [[ -n "$image_url" ]]; then
      break
    fi
  fi
done

if [[ -n "$image_url" ]]; then
  if [[ "$image_url" == //* ]]; then
    image_url="https:${image_url}"
  elif [[ "$image_url" == /* && -n "$resolved_doi_url" ]]; then
    base_host="$(echo "$resolved_doi_url" | sed -E 's#(https?://[^/]+).*#\1#')"
    image_url="${base_host}${image_url}"
  fi
fi

figure_name=""
if [[ -n "$image_url" ]]; then
  image_path="${image_url%%\?*}"
  ext="${image_path##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    jpg|jpeg|png|webp) ;;
    *) ext="jpg" ;;
  esac

  figure_name="featured.${ext}"
  if ! curl -fsSL -L "$image_url" -o "$target_dir/$figure_name"; then
    figure_name=""
  fi
fi

rm -f "$landing_tmp"

today="$(date -u +%Y-%m-%d)"

if [[ -z "${pub_date:-}" ]]; then
  pub_date="$today"
fi

# Keep metadata date from DOI, but publish immediately unless user changes it.
publish_date="$today"

if [[ -n "$tags_yaml" ]]; then
  tags_block=$'tags:\n'"$tags_yaml"
else
  tags_block='tags: []'
fi

cat > "$target_dir/index.md" <<EOF
---
title: "${title}"
# Authors
authors:
${authors_yaml:-  - admin}

# Author notes (optional)
author_notes: []

date: "${pub_date}T00:00:00Z"
doi: "${doi}"

# Schedule page publish date (NOT publication's date).
publishDate: "${publish_date}T00:00:00Z"

# Publication type.
publication_types: ["${publication_type}"]

# Publication name and optional abbreviated publication name.
publication: "${publication}"
publication_short: ""

abstract: "${abstract}"
summary: ""

${tags_block}
featured: false

url_pdf: "${pdf_url}"
url_code: ""
url_dataset: ""
url_poster: ""
url_project: ""
url_slides: ""
url_source: "${source_url}"
url_video: ""

image:
  caption: ""
  focal_point: ""
  preview_only: false

projects: []
slides: ""
---

{{% callout note %}}
Click the _Cite_ button above to export this publication to reference managers.
{{% /callout %}}

Add the publication's **full text** or **supplementary notes** here.

EOF

echo "Created publication in ${target_dir}"
if [[ -n "$figure_name" ]]; then
  echo "Downloaded figure: ${target_dir}/${figure_name}"
else
  echo "No graphical abstract/preview image was auto-detected from DOI metadata."
fi
echo "Next: fill in authors, abstract, and links (code/dataset/slides/source/video)."

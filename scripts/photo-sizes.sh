#!/usr/bin/env zsh
set -euo pipefail

# Generate the responsive variants for a photo.
#
#   scripts/photo-sizes.sh images/my-photo.jpg
#
# Drop the photo into images/ under its intended filename, then run this.
# The filename is used as the slug verbatim — it is not rewritten.
#
# Writes, relative to the repo root:
#   images/<name>        long edge 1920  (detail page)
#   images/1280/<name>   long edge 1280  (srcset)
#   images/960/<name>    long edge 960   (srcset)
#   images/720/<name>    long edge 720   (srcset, Atom feed embed)
#   images/480/<name>    long edge 480   (srcset, grid)
#
# Sizes bound the LONG edge, so portrait files come out narrower than the
# step name. The srcset descriptors in _includes/photo-figure.html and
# _includes/photos-grid.html are computed from the front matter width/height
# to match — see _docs/photos.md.

repo_root="${0:A:h:h}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 path/to/photo.jpg" >&2
  exit 1
fi

input_path="${1:A}"
if [[ ! -f "$input_path" ]]; then
  echo "Input file not found: $input_path" >&2
  exit 1
fi

name="${input_path:t}"
base="${name%.*}"
ext="${name##*.}"
output_name="${base}.${ext:l}"

read -r src_w src_h <<< "$(magick identify -format '%w %h' "$input_path")"
# A camera-rotated photo reports its raw grid here; %[EXIF:Orientation] 5-8 mean
# the displayed image is the transpose, which -auto-orient will produce.
orientation="$(magick identify -format '%[EXIF:Orientation]' "$input_path" 2>/dev/null || true)"
if [[ "$orientation" == (5|6|7|8) ]]; then
  tmp_w=$src_w; src_w=$src_h; src_h=$tmp_w
fi
if (( src_w > src_h )); then long_edge=$src_w; else long_edge=$src_h; fi

# Capture the EXIF timestamp before -strip discards it, rounded up to the next
# five minutes. The UTC offset is whatever was in effect locally on that date,
# so a photo taken in another timezone needs the offset corrected by hand.
exif_date=""
exif_time=""
shot_at="$(magick identify -format '%[EXIF:DateTimeOriginal]' "$input_path" 2>/dev/null || true)"
if [[ -n "$shot_at" && "$shot_at" != "0000:00:00 00:00:00" ]]; then
  if epoch=$(date -j -f "%Y:%m:%d %H:%M:%S" "$shot_at" "+%s" 2>/dev/null); then
    rounded=$(( (epoch + 299) / 300 * 300 ))
    offset=$(date -j -f "%s" "$rounded" "+%z")           # e.g. +0200
    offset="${offset:0:3}:${offset:3:2}"                 # e.g. +02:00
    exif_date="$(date -j -f "%s" "$rounded" "+%Y-%m-%d %H:%M:00") $offset"
    exif_time="$(date -j -f "%s" "$rounded" "+%H:%M")"
  fi
fi

if (( long_edge < 1920 )); then
  echo "Note: source long edge is ${long_edge}px, under 1920." >&2
  echo "      Variants above ${long_edge}px would be upscaled, so they are skipped." >&2
fi

# The 1920 render overwrites images/<name> when that is also the source, which
# would discard the untouched original. Keep a copy outside version control.
if [[ "$input_path" == "$repo_root/images/$output_name" ]]; then
  mkdir -p "$repo_root/images/_originals"
  if [[ ! -f "$repo_root/images/_originals/$output_name" ]]; then
    cp -p "$input_path" "$repo_root/images/_originals/$output_name"
    echo "Kept the original at images/_originals/$output_name"
  fi
fi

out_1920="$repo_root/images"
out_1280="$repo_root/images/1280"
out_960="$repo_root/images/960"
out_720="$repo_root/images/720"
out_480="$repo_root/images/480"
mkdir -p "$out_1920" "$out_1280" "$out_960" "$out_720" "$out_480"

# Quality rises with size: larger files carry more detail worth preserving,
# and the small steps are the ones where bytes matter most.
render() {
  local size="$1" quality="$2" dest="$3"
  if (( long_edge < size )); then
    echo "  skip ${size}px (source is only ${long_edge}px)"
    return
  fi
  local tmp="${dest}.tmp.${ext:l}"
  magick "$input_path" -auto-orient -strip -interlace Plane -sampling-factor 4:2:0 \
    -resize "${size}x${size}>" -quality "$quality" "$tmp"
  mv -f "$tmp" "$dest"
  echo "  $(magick identify -format '%wx%h' "$dest")  q${quality}  ${dest#$repo_root/}"
}

echo "Generating variants for ${output_name} (source ${src_w}x${src_h}):"
render 480  82 "$out_480/$output_name"
render 720  84 "$out_720/$output_name"
render 960  86 "$out_960/$output_name"
render 1280 88 "$out_1280/$output_name"
# Written last: when the source is already images/<name>, this overwrites it.
render 1920 92 "$out_1920/$output_name"

read -r final_w final_h <<< "$(magick identify -format '%w %h' "$out_1920/$output_name")"
echo
echo "Front matter values:"
if [[ -n "$exif_date" ]]; then
  echo "  date: ${exif_date}"
  echo "  time: \"${exif_time}\""
else
  echo "  date: (no EXIF timestamp in source — ask)"
  echo "  time: (no EXIF timestamp in source — ask)"
fi
echo "  image: /images/${output_name}"
echo "  width: ${final_w}"
echo "  height: ${final_h}"

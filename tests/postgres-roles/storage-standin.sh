#!/bin/sh
set -eu
IFS=' ' read -r method target protocol
length=0
encoding=
expect=
while IFS= read -r raw; do
  line=$(printf %s "$raw" | tr -d '\r')
  [ -n "$line" ] || break
  case "$line" in
    [Cc]ontent-[Ll]ength:*) length=${line#*:}; length=$(printf %s "$length" | tr -d ' ') ;;
    [Cc]ontent-[Ee]ncoding:*) encoding=${line#*:} ;;
    [Ee]xpect:*) expect=${line#*:} ;;
  esac
done
case "$expect" in *100-continue*) printf 'HTTP/1.1 100 Continue\r\n\r\n';; esac
case "$length" in *[!0-9]*|'') exit 1;; esac
[ "$length" -le 4096 ] || exit 1
if [ "$length" -gt 0 ]; then
  dd bs=1 count="$length" of=/tmp/fixture-s3-body 2>/dev/null
fi
case "$method" in
  PUT)
    case "$encoding" in
      *aws-chunked*) awk 'NR==2 {sub(/\r$/, ""); printf "%s", $0}' /tmp/fixture-s3-body > /tmp/fixture-s3-object ;;
      *) cp /tmp/fixture-s3-body /tmp/fixture-s3-object ;;
    esac
    printf 'HTTP/1.1 200 OK\r\nContent-Length: 0\r\nETag: "fixture"\r\nConnection: close\r\n\r\n' ;;
  GET|HEAD)
    if [ -f /tmp/fixture-s3-object ]; then
      size=$(wc -c < /tmp/fixture-s3-object | tr -d ' ')
      printf 'HTTP/1.1 200 OK\r\nContent-Length: %s\r\nConnection: close\r\n\r\n' "$size"
      [ "$method" != GET ] || cat /tmp/fixture-s3-object
    else
      printf 'HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
    fi ;;
  DELETE)
    rm -f /tmp/fixture-s3-object
    printf 'HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n' ;;
  *) printf 'HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n' ;;
esac

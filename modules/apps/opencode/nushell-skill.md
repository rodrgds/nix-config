---
name: nushell
description: Use when writing or running Nushell commands, scripts, or pipelines - via the Nushell MCP server (mcp__nushell__evaluate), via Bash (nu -c), or in .nu script files. Also use when working with structured data (JSON, YAML, TOML, CSV, Parquet, SQLite), doing ad-hoc data analysis or exploration, or when the user's shell is Nushell.
---

# Using Nushell

Nushell is a structured-data shell. Commands pass **tables, records, and lists** through pipelines - not text.

**Two execution paths:**
- **MCP server**: `mcp__nushell__evaluate` - persistent REPL (variables survive across calls)
- **Bash tool**: `nu -c '<code>'` - one-shot (use single quotes for outer wrapper)

## Critical Rules

**NEVER use bare `print` in MCP stdio mode.** Output will be lost (returns empty `[]`). Use `print -e "msg"` for stderr, or just return the value (implicit return).

**String interpolation uses parentheses, NOT curly braces:**
```nu
# WRONG:  $"hello {$name}"
# CORRECT: $"hello ($name)"
$"($env.HOME)/docs"    $"2 + 2 = (2 + 2)"    $"files: (ls | length)"
```
Gotcha: `$"(some text)"` errors - parens are evaluated as code. Escape literal parens: `\(text\)`.

**No bash syntax:** `cmd1; cmd2` not `&&`, `o+e>|` not `2>&1`, `$env.VAR` not `$VAR`, `(cmd)` not `$(cmd)`.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `$"hello {$name}"` | `$"hello ($name)"` |
| `print "msg"` in MCP | `print -e "msg"` or return value |
| `command 2>&1` | `command o+e>\| ...` |
| `$HOME/path` | `$env.HOME` or `$"($env.HOME)/path"` |
| `export FOO=bar` | `$env.FOO = "bar"` |
| Mutating in closure | Use `reduce`, `generate`, or `each` |
| `\u001b` for ANSI | `ansi strip` to remove, `char --unicode '1b'` for ESC |
| `where ($in.a > 1) and ($in.b > 2)` | Second `$in` rebinds to bool. Use bare cols: `where a > 1 and b > 2` |
| `where not ($in.col \| cmd)` | `not` breaks `$in`. Use `where ($in.col \| cmd) == false` |
| `where col \| cmd` (no parens) | Parsed as two pipeline stages. Use `where ($in.col \| cmd)` |

## When to Use Nushell

**Always prefer Nushell for:**
- Any structured data (JSON, YAML, TOML, CSV, Parquet, SQLite) - unifies all formats
- CLI tools with `--json` flags - pipe JSON output directly into Nushell for querying (e.g. `^gh pr list --json title,state | from json`)
- Ad-hoc data analysis and exploration - faster than Python setup
- Initial data science/analytics - histograms, tabular output, basic aggregations
- Polars plugin for large datasets - DataFrames without Python overhead

**Use Bash only when:** bash-specific tooling, MCP unavailable, or bash-syntax integrations.

## MCP Server Quick Notes

- `mcp__nushell__evaluate` - run code; `mcp__nushell__list_commands` - discover; `mcp__nushell__command_help` - help
- State persists between calls. `$history` stores prior results (access `$history.0`, etc.)
- Use `| to text` or `| to json` for large outputs. Use `ansi strip` for color removal.

# Nushell Advanced Patterns

## Custom Commands with Full Signatures

```nu
def search [
    pattern: string           # required positional
    path?: string             # optional positional
    --case-sensitive(-c)      # boolean flag (defaults false)
    --max-depth(-d): int      # flag with value
    ...extra: string          # rest params
]: nothing -> list<string> {
    # implementation
}
```

### Pipeline Input/Output Types
```nu
def "str stats" []: string -> record {
    let input = $in
    {length: ($input | str length), words: ($input | split words | length)}
}

# Multiple input types
def process []: [string -> record, list -> table] { ... }
```

### Environment-Modifying Commands
```nu
def --env goto [dir: string] {
    cd $dir
    $env.LAST_DIR = (pwd)
}
```

### Wrapped External Commands
```nu
def --wrapped mygrep [...rest] {
    ^grep --color=always ...$rest
}
```

## Modules

```nu
module utils {
    export def double [x: number] { $x * 2 }
    export def triple [x: number] { $x * 3 }
    export-env { $env.UTILS_LOADED = true }
}

use utils double         # import specific command
use utils *              # import all exports
use utils []             # import only environment
```

## Generate (Stateful Sequences)

Closure comes first, initial value second. Returns `{out: value, next: state}`. Omit `next` to stop.

```nu
# Fibonacci
generate {|fib| {out: $fib.0, next: [$fib.1, ($fib.0 + $fib.1)]}} [0, 1] | first 10

# Counter
generate {|i| if $i <= 5 { {out: $i, next: ($i + 1)} }} 0

# With input stream (two-arg closure)
1..5 | generate {|e, sum=0| let sum = $e + $sum; {out: $sum, next: $sum}}
```

## Functional Alternatives to Mutable State

```nu
# Instead of: mut sum = 0; for x in list { $sum += $x }
[1 2 3 4 5] | reduce {|it, acc| $acc + $it}

# With initial value
[2 3 4 5] | reduce --fold 1 {|it, acc| $acc * $it}

# Instead of: mut results = []; for x in list { $results = ($results | append (f $x)) }
$list | each {|x| process $x}

# Instead of: while with mutation
generate {|state| if $state.done { null } else { {out: $state.val, next: (advance $state)} }} $initial
```

## Error Handling

```nu
# Basic try/catch
try { open nonexistent.json } catch {|e| $"Failed: ($e.msg)" }

# With finally (v0.111.0+)
try { do-work } catch {|e| log-error $e.msg } finally { cleanup }

# Custom errors
error make {msg: "Value must be non-negative"}
error make {msg: "Bad value", label: {text: "here", span: (metadata $value).span}}
```

## External Commands

```nu
^external_cmd args              # explicit external invocation
ls | to text | ^grep pattern    # pipe structured data to external
^cmd arg1 arg2 o+e>| str trim  # capture stdout+stderr
^cmd | complete                 # get {exit_code, stdout, stderr} record
$env.LAST_EXIT_CODE             # check last exit code

# External output to structured data
^git log --oneline -5 | lines | parse "{hash} {message}"

# Pipe structured data to external
{data: "value"} | to json | ^curl -X POST -d @- https://api.example.com
```

## Background Jobs

```nu
job spawn { long_running_cmd }                    # returns job ID
job spawn --tag "server" { uvicorn main:app }     # with description
job list                                          # list running jobs
job kill $id                                      # terminate job

# Getting results back via mailbox (main thread = job 0)
job spawn { expensive_calc | job send 0 }; job recv
job spawn { cmd | job send 0 --tag 1 }; job recv --tag 1  # filtered
job recv --timeout 5sec                           # with timeout
```

**Key rules:** `job recv` reads from current job's mailbox only (no job ID arg). Background jobs send to main with `job send 0`. Use `--tag` for filtering.

## Environment & Configuration

```nu
$env.PATH                      # PATH (list with ENV_CONVERSIONS, string otherwise)
$env.Path                      # PATH on Windows
$env.PATH = ($env.PATH | append "/new/path")
$env.MY_VAR = "value"
$env.MY_VAR? | default "fallback"  # safe access with default
hide-env MY_VAR                # unset variable

# Configuration
$env.config.show_banner = false    # set individual config values
$nu.default-config-dir             # config directory path
$nu.home-dir                       # home directory
config nu                          # edit config in $EDITOR
```

## Using nu -c from Bash

```bash
# Simple command
nu -c 'ls | where size > 1mb | to json'

# String interpolation (outer single quotes to avoid $ conflicts)
nu -c 'let x = 42; $"answer: ($x)"'

# Multi-statement
nu -c 'let data = (open file.json); $data | get field'
```

Use single quotes for the outer wrapper since Nushell uses `$` for variables.

# Nushell Data Analysis Reference

## Format Conversion

Nushell unifies structured data formats. `open` auto-detects by extension:
csv, eml, ics, ini, json, nuon, ods, ssv, toml, tsv, url, vcf, xlsx/xls, xml, yaml/yml, SQLite

```nu
# Auto-detect
open data.json                  # parsed JSON -> table/record
open data.csv                   # parsed CSV -> table
open data.toml                  # parsed TOML -> record
open data.db                    # SQLite -> tables

# Explicit parsing from strings
'{"a":1}' | from json
"a,b\n1,2" | from csv
$toml_string | from toml
$yaml_string | from yaml

# Serialization
{a: 1} | to json
$table | to csv
{a: 1} | to toml
{a: 1} | to yaml
{a: 1} | to nuon               # Nushell Object Notation

# Raw text (skip parsing)
open --raw file.json            # byte stream, not parsed
```

## Leveraging External JSON Output

**If a CLI tool supports `--json` or similar structured output, prefer running it in Nushell** over Bash. The JSON is parsed automatically and queryable immediately:

```nu
# External tool with JSON output -> instant structured data
^cargo metadata --format-version 1 | from json | get packages | select name version
^gh pr list --json title,state | from json | where state == "OPEN"
^docker ps --format json | lines | each { from json } | select Names State
^kubectl get pods -o json | from json | get items | select metadata.name status.phase
```

This eliminates the need for `jq`, `grep`, or `awk` pipelines. Any tool that outputs JSON becomes a first-class data source in Nushell.

## HTTP Requests

```nu
# GET - result is auto-parsed from JSON
http get https://api.example.com/data
http get https://api.example.com/data | get field

# POST with JSON body
http post --content-type application/json https://api.example.com/endpoint {key: "val"}

# POST with headers
http post https://api.example.com/sync -H {X-API-Key: "secret"} (bytes build)

# POST with headers and body
http post --content-type application/json https://api.example.com/data -H {Authorization: "Bearer token"} {key: "value"}
```

## Data Manipulation Patterns

### Grouping and Aggregation
```nu
# group-by with --to-table for aggregation
# Note: the group column is named after the grouper (e.g. "category"), not "group"
$data | group-by category --to-table | each {|g|
    {
        category: $g.category
        count: ($g.items | length)
        total: ($g.items | get price | math sum)
        avg: ($g.items | get price | math avg)
    }
}
```

### Pivoting Data
```nu
# Record to table
{name: "test", age: 30, city: "NYC"} | transpose key value

# Table to record
[[key value]; [a 1] [b 2]] | into record
```

### Structured Log Parsing
```nu
# parse extracts named fields from text, returns a table (not a record)
"2025-01-15 ERROR auth: timeout" | parse "{date} {level} {service}: {message}"
# => table with one row: [{date: "2025-01-15", level: "ERROR", service: "auth", message: "timeout"}]
# Access first match: ... | parse "..." | first

# Multi-line logs
open server.log | lines | parse "{date} [{level}] {msg}" | where level == "ERROR"
```

### Joining and Merging
```nu
# Horizontal merge (add columns)
$table1 | merge $table2

# Vertical append (add rows)
$table1 | append $table2
$table1 ++ $table2

# Spread records
{...$base, ...$overrides, extra: "field"}
```

## SQLite

```nu
open database.db                         # lists tables
open database.db | get table_name        # get table data
open database.db | query db "SELECT * FROM users WHERE age > 25"
```

## Polars Plugin (Large Datasets)

For datasets too large for Nushell's built-in table handling:

```nu
plugin use polars

# Open file formats efficiently
polars open large.parquet | polars select name status | polars collect
polars open data.csv | polars first 5 | polars into-nu

# Convert Nushell table to DataFrame
ps | polars into-df | polars filter (polars col cpu > 50) | polars into-nu

# Aggregation
polars open sales.csv
    | polars group-by category
    | polars agg (polars col price | polars sum)
    | polars collect

# Summary statistics
$data | polars into-df | polars summary

# Save results
polars open input.parquet | polars select name status | polars save output.parquet
```

## Math/Statistics

```nu
[1 2 3 4 5] | math sum       # 15
[1 2 3 4 5] | math avg       # 3
[1 2 3 4 5] | math min       # 1
[1 2 3 4 5] | math max       # 5
[1 2 3 4 5] | math median    # 3
[1.5 2.7] | math round       # [2, 3]
[1.5 2.7] | math floor       # [1, 2]
[1.5 2.7] | math ceil        # [2, 3]
[-5 3] | math abs             # [5, 3]
```

## NUON (Nushell Object Notation)

A JSON superset supporting comments, optional commas, and Nushell literals:

```nuon
{
    name: "project"     # no quotes needed for simple keys
    created: 2025-01-15
    timeout: 5sec
    size: 1.5mb
    data: [1 2 3]       # commas optional
}
```

# Nushell Types and Syntax Reference

## Data Types

| Type | Literal | Example |
|------|---------|---------|
| int | decimal, hex, octal, binary | `42`, `0xff`, `0o77`, `0b1010`, `100_000` |
| float | decimal point, scientific | `3.14`, `-2.5e10`, `Infinity`, `NaN` |
| string | quotes | `'single'`, `"double\n"`, `` `backtick` ``, `r#'raw'#` |
| bool | literal | `true`, `false` |
| duration | number + unit | `5sec`, `3min`, `2hr`, `1day`, `500ms`, `100ns`, `2wk` |
| filesize | number + unit | `64mb`, `1.5gb`, `10kib`, `2gib` |
| date | ISO format | `2025-01-15`, `2025-01-15T10:30:00-05:00` |
| range | `..` syntax | `1..5`, `0..<10`, `5..1`, `0..2..10` (step) |
| list | `[]` | `[1 2 3]`, `["a", "b"]`, `["mixed" 42 true]` |
| record | `{}` | `{name: "nu", ver: 1}`, `{"spaced key": true}` |
| table | list of records | `[{a: 1}, {a: 2}]`, `[[a b]; [1 2] [3 4]]` |
| nothing | `null` | `null` |
| binary | `0x[]` | `0x[FF EE]`, `0o[377]`, `0b[11111111]` |
| closure | `{\|\| }` | `{\|x\| $x + 1}`, `{\|x, y\| $x + $y}` |
| cell-path | dot notation | `$.name`, `$.0`, `$.users.0.name`, `$.field?` |
| glob | backtick | `` `**/*.rs` `` |

## String Types in Detail

**Single-quoted** - no escape processing:
```nu
'C:\path\to\file'          # backslashes are literal
'no\nescape'               # literal \n, not newline
```

**Double-quoted** - C-style escapes:
```nu
"line1\nline2"             # newline
"tab\there"                # tab
"quote: \""                # escaped quote
"\u{1F600}"                # unicode codepoint
```
Escapes: `\"` `\'` `\\` `\/` `\b` `\f` `\r` `\n` `\t` `\u{X...}`

**Raw strings** - literal, can contain any quotes:
```nu
r#'Contains "double" and 'single' quotes'#
r##'Even r#'nested raw'# strings'##
```

**Backtick strings** - for paths/globs with spaces:
```nu
ls `./my directory`
ls `**/*.{rs,toml}`
```

**String interpolation** - `$"..."` or `$'...'`:
```nu
let name = "world"
$"Hello, ($name)!"                      # variable
$"2 + 2 = (2 + 2)"                      # expression
$"files: (ls | length)"                  # command
$"escaped parens: \(not code\)"          # literal parens
$'single-quote interp: ($name)'         # no escape processing
```

## Duration and Filesize Units

**Duration**: `ns` `us` `ms` `sec` `min` `hr` `day` `wk` - supports arithmetic: `5sec + 2min`

**Filesize (base-10)**: `b` `kb` `mb` `gb` `tb` `pb` `eb`
**Filesize (base-2)**: `kib` `mib` `gib` `tib` `pib` `eib` - supports arithmetic: `1gb + 500mb`

## Ranges

```nu
1..5                   # inclusive: [1, 2, 3, 4, 5]
0..<5                  # exclusive end: [0, 1, 2, 3, 4]
5..1                   # reverse: [5, 4, 3, 2, 1]
0..2..10               # step by 2: [0, 2, 4, 6, 8, 10]
```

## Variables

```nu
let x = 42           # immutable (preferred)
mut y = 0             # mutable (cannot be captured by closures)
const FILE = "a.nu"   # parse-time constant (use with source/use)
```

**Closures cannot capture `mut` variables.** Use `reduce`, `generate`, or `each` instead.

## Operators

### Arithmetic
`+` `-` `*` `/` `//` (floor div) `mod` `**` (power)

### Comparison
`==` `!=` `<` `<=` `>` `>=`

### String/Pattern
`=~` or `like` (regex match), `!~` or `not-like` (regex non-match)
`starts-with` `ends-with` `in` `not-in` `has` `not-has`

### Logical
`not` `and` `or` `xor` (all short-circuit except xor)

### Bitwise
`bit-and` `bit-or` `bit-xor` `bit-shl` `bit-shr`

### Assignment
`=` `+=` `-=` `*=` `/=` `++=` (append)

### Concatenation
`++` (append lists or strings)

### Precedence (high to low)
1. Parentheses
2. `**`
3. `*` `/` `//` `mod`
4. `+` `-`
5. `bit-shl` `bit-shr`
6. Comparison, membership, regex
7. `bit-and` -> `bit-xor` -> `bit-or`
8. `and` -> `xor` -> `or`
9. Assignment
10. `not`

## Control Flow

```nu
# if/else (returns value)
let size = if $x > 100 { "big" } else if $x > 10 { "medium" } else { "small" }

# match (pattern matching)
match $val {
    1..10 => "small"
    "hello" => "greeting"
    {name: $n} => $"found ($n)"     # record destructuring
    $x if $x > 100 => "big"        # guard clause
    _ => "other"                    # default
}

# loops (prefer each/par-each for functional style)
for item in $list { ... }
while $cond { ... }
loop { if $done { break }; ... }
```

## Accessing Structured Data

```nu
$record.field                  # record field
$list.2                        # list index
$table | get column            # column values as list
$table | select col1 col2      # subtable with columns
$data.users.0.name             # nested access
$data.field?                   # optional (returns null if missing)
$data.field? | default "fallback"  # with default
```

**`get` vs `select`**: `get name` returns a flat list of values. `select name` returns a table preserving column structure.

## Records

```nu
{a: 1, b: 2} | insert c 3     # add field
{a: 1, b: 2} | update a 10    # modify field
{a: 1, b: 2} | merge {c: 3}   # combine records
{...$rec1, ...$rec2, d: 4}    # spread syntax
{a: 1, b: 2} | transpose k v  # to table
{a: 1, b: 2} | items {|k,v| $"($k)=($v)"}  # iterate
{a: 1, b: 2} | columns        # ["a", "b"]
{a: 1, b: 2} | values         # [1, 2]
```

## Lists

```nu
[1 2 3] | append 4            # add to end
[1 2 3] | prepend 0           # add to start
[1 2 3] ++ [4 5]              # concatenate
[1 2 3] | insert 1 99         # insert at index
[1 2 3] | each {|x| $x * 2}  # transform
[1 2 3] | par-each {|x| $x * 2}  # parallel transform
[1 2 3] | where $it > 1       # filter
[1 2 3] | reduce {|it, acc| $acc + $it}  # fold
[1 2 3] | any {|x| $x > 2}   # test any
[1 2 3] | all {|x| $x > 0}   # test all
[1 [2 3] [4]] | flatten       # unnest
```

## Tables

```nu
$table | sort-by column_name
$table | group-by column --to-table
$table | rename new_col1 new_col2
$table | reject unwanted_col
$table | move col --after other_col
$table | enumerate | flatten   # add index column
```

## Special Variables

| Variable | Purpose |
|----------|---------|
| `$in` | Pipeline input to current expression |
| `$it` | Current item in `where` row conditions |
| `$env` | Environment variables and config |
| `$nu` | System info, paths, runtime (`$nu.home-dir`, `$nu.default-config-dir`, `$nu.os-info`, `$nu.pid`) |
| `$env.config` | Nushell configuration record |
| `$env.LAST_EXIT_CODE` | Last external command exit code |
| `$env.CMD_DURATION_MS` | Last command duration in ms |
| `$env.CURRENT_FILE` | Current script/module file path |
| `$env.PATH` / `$env.Path` | Executable search path (macOS-Linux / Windows); list with `ENV_CONVERSIONS`, string otherwise |

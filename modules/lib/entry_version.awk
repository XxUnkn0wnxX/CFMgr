# SPDX-License-Identifier: GPL-3.0-or-later
# Read one entry's version convention as data, never shell code.
# Caller supplies trusted immutable regular stdin, independently checked size,
# LC_ALL=C and no operands. Byte framing adds no acquisition or read deadline.
# Consumers must verify status, exact ledger bytes and output write completion.

BEGIN {
    if (ARGC != 1 || ENVIRON["LC_ALL"] != "C") cfmgr_entry_invalid_invocation()
    if (cfmgr_entry_size !~ /^[1-9][0-9]*$/ || length(cfmgr_entry_size) > 7) cfmgr_entry_invalid_invocation()
    expected_size = cfmgr_entry_size + 0
    if (expected_size < 1 || expected_size > 1048576) cfmgr_entry_invalid_invocation()

    # Retain LF and all unrelated source bytes. ASCII28 anywhere necessarily
    # shortens this first record; native AWKs truncating at NUL also fail size.
    RS = sprintf("%c", 28)
    if ((getline document) != 1 || length(document) != expected_size) cfmgr_entry_invalid_data()
    if ((getline extra_record) != 0) cfmgr_entry_invalid_data()
    # Host AWKs may preserve NUL, so reject it explicitly where representable.
    nul = sprintf("%c", 0)
    if (length(nul) && index(document, nul)) cfmgr_entry_invalid_data()

    # Match only line starts, using the host extractor's declaration convention.
    # Two bounded scans/copies avoid LF arrays and per-line suffix copying.
    candidate_pattern = "(^|\n)[ \t]*((export|readonly)[ \t]+)?CFMGR_VERSION="
    if (!match(document, candidate_pattern)) cfmgr_entry_invalid_data()
    candidate_start = RSTART
    if (substr(document, candidate_start, 1) == "\n") candidate_start++
    candidate_tail = substr(document, candidate_start)
    newline = index(candidate_tail, "\n")
    if (newline) {
        candidate = substr(candidate_tail, 1, newline - 1)
        if (match(substr(candidate_tail, newline + 1), candidate_pattern)) cfmgr_entry_invalid_data()
    } else candidate = candidate_tail

    version = substr(candidate, 15)
    if (length(version) > 128) cfmgr_entry_invalid_data()
    if (candidate !~ /^CFMGR_VERSION=(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/) cfmgr_entry_invalid_data()
    output_body = "entry-version\t" version "\n"
    printf "%s", output_body
    printf "end\t%d\n", length(output_body)
    exit 0
}

function cfmgr_entry_invalid_invocation() { exit 2 }
function cfmgr_entry_invalid_data() { exit 1 }

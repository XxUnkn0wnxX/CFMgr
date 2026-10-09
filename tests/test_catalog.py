"""Bounded source-catalog parsing and canonical-ledger evidence."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

LIB = Path(__file__).resolve().parents[1] / "modules/lib"
SOURCE = LIB / "catalog.awk"
PATH_HELPERS = LIB / "package_path.awk"
HOST_AWKS = sorted(
    {
        str(Path(path).resolve())
        for path in ("/usr/bin/awk", "/usr/local/bin/awk", shutil.which("awk"))
        if path and Path(path).is_file()
    }
)
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V32", evidence="host")]


def catalog(
    *,
    branch: str = "develop",
    repository: str = "https://github.com/Example-Org/CFMgr",
    manifest_path: str = "catalog/manifest.txt",
    files: tuple[tuple[str, str], ...] | None = None,
    prefix: tuple[str, ...] = (),
) -> bytes:
    raw_prefix = repository.replace("github.com", "raw.githubusercontent.com") + "/{commit}/"
    if files is None:
        files = (
            ("cfmgr.sh", raw_prefix + "cfmgr.sh"),
            ("modules/lib/common.sh", raw_prefix + "modules/lib/common.sh"),
        )
    lines = [*prefix, "catalog: 1", f"repository: {repository}", f"branch: {branch}"]
    lines.append(f"manifest: {raw_prefix}{manifest_path}")
    lines.extend(f"{destination}: {url}" for destination, url in files)
    return ("\n".join(lines) + "\n").encode("ascii")


def expected(data: bytes) -> str:
    metadata: dict[str, str] = {}
    files: list[tuple[str, str]] = []
    for raw_line in data.decode("ascii").splitlines():
        if not raw_line or raw_line.startswith("#"):
            continue
        key, value = raw_line.split(": ", 1)
        if key in {"catalog", "repository", "branch", "manifest"}:
            metadata[key] = value
        else:
            files.append((key, value))
    owner, repo = metadata["repository"].removeprefix("https://github.com/").split("/", 1)
    branch = metadata["branch"].lower() if len(metadata["branch"]) == 40 else metadata["branch"]
    body = "catalog\t1\n"
    body += f"repository\t{owner}\t{repo}\nbranch\t{branch}\nmanifest\t{metadata['manifest']}\n"
    body += "".join(f"file\t{destination}\t{url}\n" for destination, url in files)
    return body + f"end\t{len(files)}\t{len(body.encode('ascii'))}\n"


@pytest.fixture(params=HOST_AWKS, ids=lambda path: path)
def native_awk(router: RouterHarness, request: pytest.FixtureRequest) -> RouterHarness:
    router.path("bin/awk").symlink_to(request.param)
    router.write("work/package_path.awk", PATH_HELPERS.read_text(encoding="utf-8"))
    router.write("work/catalog.awk", SOURCE.read_text(encoding="utf-8"))
    return router


def invoke(
    router: RouterHarness,
    document: bytes,
    *,
    size: str | None = None,
    operands: tuple[str, ...] = (),
    locale: str = "C",
) -> ShellResult:
    assert len(document) <= router.FILE_LIMIT
    path = router.path("ram/catalog")
    path.write_bytes(document)
    path.chmod(0o600)
    args = []
    if size != "MISSING":
        args.extend(["-v", "cfmgr_catalog_size=" + (str(len(document)) if size is None else size)])
    args.extend(
        [
            "-f",
            str(router.path("work/package_path.awk")),
            "-f",
            str(router.path("work/catalog.awk")),
            *operands,
        ]
    )
    return router.run('awk "$@" < "$RAM_ROOT/catalog"\n', args, env={"LC_ALL": locale})


def reject(result: ShellResult, status: int = 1) -> None:
    assert result.returncode == status
    assert result.stdout == result.stderr == ""


def test_valid_catalog_comments_nested_sources_and_canonical_commit(
    native_awk: RouterHarness,
) -> None:
    document = catalog(
        branch="0123456789ABCDEF0123456789ABCDEF01234567",
        prefix=("# source selection only", ""),
        files=(
            (
                "cfmgr.sh",
                "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/entry/main.sh",
            ),
            (
                "modules/lib/common.sh",
                "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/core/common.sh",
            ),
            (
                "modules/helpers/update/deep.sh",
                "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/helpers/update/deep.sh",
            ),
        ),
    )
    result = invoke(native_awk, document)
    assert result.returncode == 0
    body = (
        "catalog\t1\n"
        "repository\tExample-Org\tCFMgr\n"
        "branch\t0123456789abcdef0123456789abcdef01234567\n"
        "manifest\thttps://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/catalog/manifest.txt\n"
        "file\tcfmgr.sh\thttps://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/entry/main.sh\n"
        "file\tmodules/lib/common.sh\thttps://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/core/common.sh\n"
        "file\tmodules/helpers/update/deep.sh\thttps://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/helpers/update/deep.sh\n"
    )
    assert result.stdout == body + f"end\t3\t{len(body.encode('ascii'))}\n"
    assert result.stderr == ""


def test_metadata_order_is_irrelevant_but_file_order_is_preserved(
    native_awk: RouterHarness,
) -> None:
    prefix = "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/"
    document = (
        f"modules/z.sh: {prefix}z.sh\n"
        f"manifest: {prefix}catalog/manifest.txt\n"
        "branch: main\n"
        f"repository: https://github.com/Example-Org/CFMgr\n"
        f"cfmgr.sh: {prefix}entry.sh\n"
        "catalog: 1\n"
    ).encode("ascii")
    result = invoke(native_awk, document)
    assert result.returncode == 0
    body = (
        "catalog\t1\n"
        "repository\tExample-Org\tCFMgr\n"
        "branch\tmain\n"
        f"manifest\t{prefix}catalog/manifest.txt\n"
        f"file\tmodules/z.sh\t{prefix}z.sh\n"
        f"file\tcfmgr.sh\t{prefix}entry.sh\n"
    )
    assert result.stdout == body + f"end\t2\t{len(body.encode('ascii'))}\n"


def test_catalog_size_and_invocation_are_independently_bounded(native_awk: RouterHarness) -> None:
    document = catalog()
    assert invoke(native_awk, document).stdout == expected(document)
    reject(invoke(native_awk, document, size="MISSING"), 2)
    reject(invoke(native_awk, document, size="00"), 2)
    reject(invoke(native_awk, document, size="32769"), 2)
    reject(invoke(native_awk, document, size=str(len(document) + 1)), 1)
    reject(invoke(native_awk, document, operands=("extra",)), 2)
    reject(invoke(native_awk, document, locale="C.UTF-8"), 2)


def test_exact_maximum_input_size_is_accepted(native_awk: RouterHarness) -> None:
    document = catalog()
    padding = bytearray()
    remaining = 32768 - len(document)
    while remaining:
        line_size = min(1024, remaining)
        assert line_size >= 2
        padding.extend(b"#" + b"x" * (line_size - 2) + b"\n")
        remaining -= line_size
    document += bytes(padding)
    assert len(document) == 32768
    result = invoke(native_awk, document)
    assert result.returncode == 0
    assert result.stdout == expected(catalog())
    assert result.stderr == ""


def test_safe_path_component_and_total_length_boundaries(native_awk: RouterHarness) -> None:
    prefix = "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/"
    boundary = "modules/" + "a" * 100 + "/" + "b" * 100 + "/" + "c" * 30
    assert len(boundary) == 240
    files = (("cfmgr.sh", prefix + "cfmgr.sh"), (boundary, prefix + boundary))
    document = catalog(files=files, branch="main")
    result = invoke(native_awk, document)
    assert result.returncode == 0
    assert result.stdout == expected(document)
    for unsafe in (boundary + "a", "modules/" + "a" * 101):
        bad_files = (("cfmgr.sh", prefix + "cfmgr.sh"), (unsafe, prefix + "source"))
        reject(invoke(native_awk, catalog(files=bad_files)))


def test_repository_owner_and_name_length_boundaries(native_awk: RouterHarness) -> None:
    owner39 = "a" + "b" * 37 + "z"
    repository100 = "R" + "s" * 99
    for owner, repository in (("a", "R"), (owner39, repository100)):
        repository_url = f"https://github.com/{owner}/{repository}"
        raw_prefix = f"https://raw.githubusercontent.com/{owner}/{repository}/{{commit}}/"
        document = catalog(
            repository=repository_url,
            files=(("cfmgr.sh", raw_prefix + "entry.sh"),),
        )
        result = invoke(native_awk, document)
        assert result.returncode == 0
        assert result.stdout == expected(document)
    for owner, repository in (("a" + "b" * 38 + "z", "R"), ("a", "R" + "s" * 100)):
        repository_url = f"https://github.com/{owner}/{repository}"
        raw_prefix = f"https://raw.githubusercontent.com/{owner}/{repository}/{{commit}}/"
        document = catalog(
            repository=repository_url,
            files=(("cfmgr.sh", raw_prefix + "entry.sh"),),
        )
        reject(invoke(native_awk, document))


@pytest.mark.parametrize(
    "mutate",
    [
        lambda data: data.replace(b"catalog: 1\n", b"catalog: 2\n"),
        lambda data: data.replace(b"branch: develop\n", b"branch: feature\n"),
        lambda data: data.replace(
            b"manifest: https://raw.githubusercontent.com/Example-Org/CFMgr/",
            b"manifest: https://evil.example/Example-Org/CFMgr/",
        ),
        lambda data: data.replace(b"Example-Org/CFMgr/{commit}", b"other/CFMgr/{commit}"),
        lambda data: data.replace(b"{commit}", b"develop"),
        lambda data: data.replace(b"modules/lib/common.sh", b"modules/../common.sh"),
        lambda data: data.replace(b"modules/lib/common.sh", b"modules//common.sh"),
        lambda data: data.replace(b"modules/lib/common.sh", b"modules/lib/common.sh?x=1"),
        lambda data: data.replace(b"modules/lib/common.sh", b"modules/lib/common%2fsh"),
        lambda data: data.replace(b"modules/lib/common.sh", b"modules/lib/common.sh "),
        lambda data: data.replace(b"modules/lib/common.sh", b"modules/lib/common\\\\sh"),
        lambda data: data.replace(
            b"{commit}/modules/lib/common.sh", b"{commit}/modules/../common.sh"
        ),
        lambda data: data.replace(
            b"Example-Org/CFMgr/{commit}/modules/lib/common.sh",
            b"example-org/CFMgr/{commit}/modules/lib/common.sh",
        ),
        lambda data: data.replace(
            b"https://github.com/Example-Org/CFMgr",
            b"https://user@github.com/Example-Org/CFMgr",
        ),
        lambda data: data.replace(
            b"https://github.com/Example-Org/CFMgr",
            b"https://github.com:443/Example-Org/CFMgr",
        ),
    ],
    ids=[
        "version",
        "branch",
        "external-host",
        "repository-mismatch",
        "per-file-ref",
        "dotdot",
        "empty-component",
        "query",
        "escape",
        "trailing-space",
        "backslash",
        "source-dotdot",
        "repository-case-mismatch",
        "userinfo",
        "port",
    ],
)
def test_invalid_selection_and_paths_are_quiet(native_awk: RouterHarness, mutate) -> None:
    document = mutate(catalog())
    reject(invoke(native_awk, document))


def test_duplicate_metadata_destinations_and_ancestor_collisions_reject_without_partial_output(
    native_awk: RouterHarness,
) -> None:
    duplicated = catalog(prefix=("catalog: 1",))
    reject(invoke(native_awk, duplicated))
    files = (
        ("cfmgr.sh", "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/cfmgr.sh"),
        ("modules/a", "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/a"),
        ("modules/a/b", "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/b"),
    )
    reject(invoke(native_awk, catalog(files=files)))
    duplicate_file = (*files[:2], files[1])
    reject(invoke(native_awk, catalog(files=duplicate_file)))


def test_reserved_destinations_and_descendants_reject(native_awk: RouterHarness) -> None:
    prefix = "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/"
    files = (("cfmgr.sh", prefix + "cfmgr.sh"),)
    for destination in (
        "modules/config",
        "modules/config/saved",
        "modules/catalog.txt",
        "modules/catalog.txt/backup",
        "config",
        "catalog.txt",
    ):
        reject(invoke(native_awk, catalog(files=files + ((destination, prefix + "source"),))))


def test_file_count_exact_bounds_and_required_entry(native_awk: RouterHarness) -> None:
    prefix = "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/"
    maximum = (("cfmgr.sh", prefix + "cfmgr.sh"),) + tuple(
        (f"modules/f{index:03d}", prefix + f"source/f{index:03d}") for index in range(127)
    )
    document = catalog(files=maximum)
    result = invoke(native_awk, document)
    assert result.returncode == 0
    assert result.stdout == expected(document)
    too_many = maximum + (("modules/f128", prefix + "source/f128"),)
    reject(invoke(native_awk, catalog(files=too_many)))
    no_entrypoint = tuple(
        (destination, url) for destination, url in maximum if destination != "cfmgr.sh"
    )
    reject(invoke(native_awk, catalog(files=no_entrypoint)))


@pytest.mark.parametrize(
    "document",
    [
        catalog()[:-1],
        catalog() + b"extra\n",
        catalog().replace(b"catalog: 1", b"catalog:\t1"),
        catalog().replace(b"catalog: 1", b"catalog: 1\r"),
        catalog() + b"bad\x00byte\n",
        catalog() + b"bad\x7fbyte\n",
        catalog() + b"x" * 1025 + b"\n",
        catalog().replace(b"branch: develop", b"branch: 0123456789abcdef0123456789abcdef0123456g"),
    ],
    ids=[
        "missing-final-lf",
        "unknown-field",
        "tab",
        "cr",
        "nul",
        "nonprintable",
        "long-line",
        "short-commit",
    ],
)
def test_framing_and_printable_ascii_are_exact(native_awk: RouterHarness, document: bytes) -> None:
    reject(invoke(native_awk, document))


@pytest.mark.busybox
@pytest.mark.matrix("V32", evidence="busybox")
def test_actual_busybox_catalog_record_framing_and_ledger(busybox_router: RouterHarness) -> None:
    busybox_router.busybox_applets("awk")
    busybox_router.write("work/package_path.awk", PATH_HELPERS.read_text(encoding="utf-8"))
    busybox_router.write("work/catalog.awk", SOURCE.read_text(encoding="utf-8"))
    document = catalog(branch="0123456789ABCDEF0123456789ABCDEF01234567")
    result = invoke(busybox_router, document)
    assert result.returncode == 0
    assert result.stdout == expected(document)
    reject(invoke(busybox_router, document + b"\x00"))

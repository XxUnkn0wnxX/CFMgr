"""Bounded native configuration staging inside the existing IO owner."""

from __future__ import annotations

import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
IO_SOURCE = ROOT / "modules/lib/io.sh"
SOURCE = ROOT / "modules/lib/native_config.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


class NativeConfigFixture:
    """Use real host tools; wrappers inject only the named failure under test."""

    def __init__(self, router: RouterHarness, *, busybox: bool = False):
        self.router = router
        self.busybox = busybox
        self.image = router.path("ram/tmp/image")
        self.image.mkdir(mode=0o700)
        self.source_root = router.path("work/source")
        (self.source_root / "etc").mkdir(parents=True, mode=0o700)
        self.hosts = self.source_root / "etc/hosts"
        self.resolver = self.source_root / "etc/resolv.conf"
        self.resolver_target = self.source_root / "etc/resolv.data"
        self.hosts.write_bytes(b"127.0.0.1\tlocalhost\\x\n\n")
        self.resolver_target.write_bytes(b"")
        self.resolver.symlink_to("resolv.data")
        if busybox:
            router.busybox_applets("cat", "wc", "printf", "mkdir", "rm", "[", "test")
        else:
            for name, path in {
                "cat": "/bin/cat",
                "wc": "/usr/bin/wc",
                "printf": "/usr/bin/printf",
                "mkdir": "/bin/mkdir",
            }.items():
                router.path(f"bin/{name}").symlink_to(path)
            router.fake_tool("test", 'exec /bin/sh -c \'test "$@"\' test "$@"\n')
        self.script = (
            f". {shlex.quote(str(IO_SOURCE))}\n"
            f". {shlex.quote(str(SOURCE))}\n"
            "cfmgr_fixture_callback() {\n"
            "  scratch=$1; shift\n"
            '  if [ "${3-}" = use-scratch ]; then\n'
            '    mkdir "$scratch/image"; set -- "$scratch/image" "$2" "$3"\n'
            "  fi\n"
            "  before_ifs=$IFS; before_options=$(set +o); before_pwd=$PWD\n"
            "  before_umask=$(umask); before_trap=$(trap)\n"
            '  cfmgr_native_config_test "$1" "$2"; stage_status=$?\n'
            '  if [ "$IFS" = "$before_ifs" ] && [ "$(set +o)" = "$before_options" ] &&\n'
            '    [ "$PWD" = "$before_pwd" ] && [ "$(umask)" = "$before_umask" ] &&\n'
            '    [ "$(trap)" = "$before_trap" ]; then\n'
            '    : >"$CFMGR_TEST_ROOT/work/helper-state-preserved"\n'
            '  else : >"$CFMGR_TEST_ROOT/work/helper-state-changed"; stage_status=1; fi\n'
            '  printf "%s\\n" "$stage_status" >"$CFMGR_TEST_ROOT/work/stage-status"\n'
            '  [ "${3-}" = fail-cleanup ] && : >"$CFMGR_TEST_ROOT/work/fail-cleanup"\n'
            '  return "$stage_status"\n'
            "}\n"
            'cfmgr_io_test "$1" "$2" workspace cfmgr_fixture_callback "$3" "$4" "${5-}"\n'
        )
        if not busybox:
            router.fake_tool(
                "rm",
                'if [ "${1-}" = -rf ] &&\n'
                '[ -f "$CFMGR_TEST_ROOT/work/fail-cleanup" ]; then exit 1; fi\n'
                'exec /bin/rm "$@"\n',
            )
        router.write("work/invoke.sh", self.script)

    def run(
        self,
        *args: str,
        timeout: float = 10,
        image_root: Path | str | None = None,
        source_root: Path | None = None,
    ) -> ShellResult:
        return self.router.run(
            'exec /bin/sh "$CFMGR_TEST_ROOT/work/invoke.sh" "$@"\n',
            [
                str(self.router.path("ram/tmp")),
                str(self.router.path("bin")),
                str(image_root or self.image),
                str(source_root or self.source_root),
                *args,
            ],
            timeout=timeout,
        )

    def stage_status(self) -> int:
        return int(self.router.read("work/stage-status").strip())

    def etc(self) -> Path:
        return self.image / "etc"


def quiet(result: ShellResult, status: int) -> None:
    assert result.returncode == status, result
    assert result.stdout == result.stderr == ""


def test_stages_exact_source_bytes_and_allows_resolver_symlink(router: RouterHarness) -> None:
    fixture = NativeConfigFixture(router)
    hosts = b"127.0.0.1\tlocalhost\\x\n\n"
    resolver = b""

    quiet(fixture.run(), 0)

    assert fixture.stage_status() == 0
    assert router.path("work/helper-state-preserved").is_file()
    assert not router.path("work/helper-state-changed").exists()
    assert (fixture.etc() / "hosts").read_bytes() == hosts
    assert (fixture.etc() / "resolv.conf").read_bytes() == resolver
    assert fixture.etc().stat().st_mode & 0o777 == 0o700
    assert (fixture.etc() / "hosts").stat().st_mode & 0o777 == 0o600
    assert (fixture.etc() / "resolv.conf").stat().st_mode & 0o777 == 0o600
    assert fixture.resolver.is_symlink()
    assert not list(router.path("ram/tmp").glob("cfmgr-io.*"))


@pytest.mark.parametrize("collision", ["directory", "file", "symlink"])
def test_preexisting_etc_is_never_adopted_or_removed(router: RouterHarness, collision: str) -> None:
    fixture = NativeConfigFixture(router)
    foreign = router.path("work/foreign")
    foreign.write_text("preserve me")
    etc = fixture.etc()
    if collision == "directory":
        etc.mkdir()
        (etc / "foreign").write_text("keep")
    elif collision == "file":
        etc.write_text("keep")
    else:
        etc.symlink_to(foreign)

    quiet(fixture.run(), 1)

    assert fixture.stage_status() == 1
    assert foreign.read_text() == "preserve me"
    if collision == "directory":
        assert (etc / "foreign").read_text() == "keep"
    elif collision == "file":
        assert etc.read_text() == "keep"
    else:
        assert etc.is_symlink() and etc.resolve() == foreign


@pytest.mark.parametrize(
    "bad_image", ["relative", "outside", "scratch", "ancestor-alias", "source-alias"]
)
def test_rejects_noncanonical_or_out_of_scope_image_paths(
    router: RouterHarness, bad_image: str
) -> None:
    fixture = NativeConfigFixture(router)
    if bad_image == "relative":
        image = "image"
    elif bad_image == "outside":
        image = str(router.path("opt/image"))
        Path(image).mkdir()
    elif bad_image == "scratch":
        image = str(fixture.image)
    elif bad_image == "ancestor-alias":
        alias = router.path("ram/tmp/alias")
        alias.symlink_to(router.path("ram/tmp"), target_is_directory=True)
        image = str(alias / "image")
    else:
        alias = router.path("work/source-alias")
        alias.symlink_to(fixture.source_root, target_is_directory=True)
        image = str(fixture.image)

    result = fixture.run(
        "use-scratch" if bad_image == "scratch" else "",
        image_root=image,
        source_root=alias if bad_image == "source-alias" else fixture.source_root,
    )
    quiet(result, 2)


def test_stage_requires_active_io_callback_context(router: RouterHarness) -> None:
    fixture = NativeConfigFixture(router)
    result = router.run(
        f". {shlex.quote(str(IO_SOURCE))}\n. {shlex.quote(str(SOURCE))}\n"
        'cfmgr_native_config_test "$1" "$2"\n',
        [str(fixture.image), str(fixture.source_root)],
    )
    quiet(result, 2)


def test_source_only_and_production_dispatch_preserve_fixed_contract(router: RouterHarness) -> None:
    result = router.run(
        f". {shlex.quote(str(IO_SOURCE))}\n"
        "IFS=x; set -f; umask 027; trap ':' TERM;\n"
        "before_options=$(set +o); before_trap=$(trap); before_pwd=$PWD\n"
        f". {shlex.quote(str(SOURCE))}\n"
        '[ "$IFS" = x ] && [ "$(umask)" = 0027 ] && [ "$before_options" = "$(set +o)" ] && '
        '[ "$before_trap" = "$(trap)" ] && [ "$before_pwd" = "$PWD" ] || exit 9\n'
        '_cfmgr_native_config_run() { printf \'%s\\n\' "$@" >"$CFMGR_TEST_ROOT/work/dispatch"; }\n'
        'cfmgr_native_config_stage "$1"; status=$?\n'
        '[ "$status" = 0 ] && [ "$IFS" = x ] && [ "$(umask)" = 0027 ] && '
        '[ "$before_options" = "$(set +o)" ] && [ "$before_pwd" = "$PWD" ]\n',
        [str(router.path("ram/tmp/image"))],
    )
    quiet(result, 0)
    assert router.read("work/dispatch").splitlines() == [
        "production",
        str(router.path("ram/tmp/image")),
        "/",
    ]


@pytest.mark.parametrize("source_kind", ["missing", "directory", "nonzero", "stderr"])
def test_source_capture_must_be_complete_clean_and_regular(
    router: RouterHarness, source_kind: str
) -> None:
    fixture = NativeConfigFixture(router)
    if source_kind == "missing":
        fixture.hosts.unlink()
    elif source_kind == "directory":
        fixture.hosts.unlink()
        fixture.hosts.mkdir()
    else:
        (router.root / "bin/cat").unlink()
        router.write("work/cat-mode", source_kind)
        router.fake_tool(
            "cat",
            'if [ -f "$CFMGR_TEST_ROOT/work/cat-mode" ] && [ "$1" = '
            f"{shlex.quote(str(fixture.hosts))}"
            ' ]; then : >"$CFMGR_TEST_ROOT/work/cat-source-reached"; /bin/cat "$1"; '
            + ("echo producer-error >&2; exit 0;\n" if source_kind == "stderr" else "exit 7;\n")
            + 'fi\nexec /bin/cat "$@"\n',
        )

    result = fixture.run()

    quiet(result, 1)
    assert fixture.stage_status() == 1
    assert not fixture.etc().exists()
    if source_kind in {"nonzero", "stderr"}:
        assert router.path("work/cat-source-reached").is_file()


@pytest.mark.parametrize("payload", [b"first\x00last", b"x" * 65537])
def test_rejects_nul_and_oversized_sources_before_image_mutation(
    router: RouterHarness, payload: bytes
) -> None:
    fixture = NativeConfigFixture(router)
    fixture.hosts.write_bytes(payload)

    quiet(fixture.run(), 1)

    assert fixture.stage_status() == 1
    assert not fixture.etc().exists()


def test_accepts_exact_capture_limit(router: RouterHarness) -> None:
    fixture = NativeConfigFixture(router)
    payload = b"x" * 65536
    fixture.hosts.write_bytes(payload)

    quiet(fixture.run(), 0)

    assert fixture.stage_status() == 0
    assert (fixture.etc() / "hosts").read_bytes() == payload


@pytest.mark.parametrize("corruption", ["short", "same-size"])
def test_zero_exit_inexact_publication_is_rejected_and_retained(
    router: RouterHarness, corruption: str
) -> None:
    fixture = NativeConfigFixture(router)
    (router.root / "bin/printf").unlink()
    router.fake_tool(
        "printf",
        'if [ "$#" = 2 ] && [ "${1-}" = %s ]; then\n'
        '  : >"$CFMGR_TEST_ROOT/work/short-publication-reached"\n'
        + (
            "  /usr/bin/printf x; exit 0\n"
            if corruption == "short"
            else '  /usr/bin/printf "X%s" "${2#?}"; exit 0\n'
        )
        + "fi\n"
        'exec /usr/bin/printf "$@"\n',
    )

    quiet(fixture.run(), 1)

    assert fixture.stage_status() == 1
    assert fixture.etc().is_dir()
    assert router.path("work/short-publication-reached").is_file()
    expected = b"x" if corruption == "short" else b"X27.0.0.1\tlocalhost\\x\n\n"
    assert (fixture.etc() / "hosts").read_bytes() == expected


def test_preconsumed_capture_slot_refuses_without_mutating_image(router: RouterHarness) -> None:
    fixture = NativeConfigFixture(router)
    fixture.script = fixture.script.replace(
        "scratch=$1; shift\n",
        'scratch=$1; shift\n: >"$scratch/0.status"\n',
    )
    router.write("work/invoke.sh", fixture.script)

    quiet(fixture.run(), 1)

    assert fixture.stage_status() == 1
    assert not fixture.etc().exists()


def test_outer_io_cleanup_failure_overrides_successful_stage(router: RouterHarness) -> None:
    fixture = NativeConfigFixture(router)

    result = fixture.run("fail-cleanup")

    quiet(result, 1)
    assert fixture.stage_status() == 0
    assert (fixture.etc() / "hosts").read_bytes() == b"127.0.0.1\tlocalhost\\x\n\n"
    assert list(router.path("ram/tmp").glob("cfmgr-io.*"))


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_stages_exact_configuration_bytes(busybox_router: RouterHarness) -> None:
    assert busybox_router.busybox is not None
    fixture = NativeConfigFixture(busybox_router, busybox=True)

    result = busybox_router.run(
        f"exec {shlex.quote(str(busybox_router.busybox))} sh "
        '"$CFMGR_TEST_ROOT/work/invoke.sh" "$@"\n',
        [
            str(busybox_router.path("ram/tmp")),
            str(busybox_router.path("bin")),
            str(fixture.image),
            str(fixture.source_root),
        ],
        timeout=20,
    )

    quiet(result, 0)
    assert fixture.stage_status() == 0
    assert (fixture.etc() / "hosts").read_bytes() == b"127.0.0.1\tlocalhost\\x\n\n"
    assert (fixture.etc() / "resolv.conf").read_bytes() == b""

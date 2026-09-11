"""Construction must reserve atomically, refund once, and bootstrap only new accounts."""
from pathlib import Path

import pytest
from lupa.lua51 import LuaRuntime


@pytest.fixture
def construction():
    lua = LuaRuntime(unpack_returned_tuples=True)
    path = Path(__file__).resolve().parents[1] / "gamemodes/gmod_factory/gamemode/core/sh_construction.lua"
    return lua, lua.execute(path.read_text())


def test_bootstrap_funds_a_complete_cell_and_building_material(construction):
    _, build = construction
    account = build.NewAccount()
    for name in ("gf_hub", "gf_extractor", "gf_separator", "gf_dispatch"):
        assert build.Reserve(account, build.Cost(name))
    assert [build.Available(account, kind) for kind in ("gravel", "sand", "clay", "mineral")] == [14, 18, 10, 22]
    assert build.Reserve(account, build.Cost("prop_physics"))
    assert build.Reserve(account, build.Cost("gmod_wire_expression2"))


def test_derived_totals_and_receipts_do_not_mutate_prices(construction):
    _, build = construction
    account = build.NewAccount()
    assert build.Reserve(account, build.Cost("gf_hub"))
    assert account.total.gravel == 40 and account.reserved.gravel == 8
    assert build.Cost("gf_hub").gravel == 8
    assert build.Available(build.NewAccount(), "gravel") == 40


def test_insufficient_resource_cannot_partially_pay(construction):
    lua, build = construction
    account = build.NewAccount(lua.table_from({"gravel": 100, "sand": 0, "clay": 100, "mineral": 100}))
    assert not build.Reserve(account, build.Cost("gf_hub"))
    assert account.reserved.gravel == account.reserved.mineral == account.reserved.clay == 0


def test_empty_saved_account_is_not_bootstrapped_again(construction):
    lua, build = construction
    account = build.NewAccount(lua.table())
    assert not build.CanAfford(account, build.PropCost)
    assert not build.CanAfford(account, build.WireCost)
    restored = build.NewAccount(account.total)
    assert restored.total.gravel == 0


def test_refund_releases_reserved_cost_without_minting_resources(construction):
    _, build = construction
    account = build.NewAccount()
    price = build.Cost("gf_separator")
    assert build.Reserve(account, price)
    assert build.Release(account, price)
    assert not build.Release(account, price)
    assert account.total.gravel == build.Available(account, "gravel") == 40


def test_two_builds_require_two_reservations(construction):
    lua, build = construction
    account = build.NewAccount(lua.table_from({"gravel": 1}))
    assert build.Reserve(account, build.PropCost)
    assert not build.Reserve(account, build.PropCost)
    assert build.Release(account, build.PropCost)
    assert build.Reserve(account, build.PropCost)


def test_hub_deposits_only_separated_resources(construction):
    _, build = construction
    account = build.NewAccount()
    for kind in (None, "soil", "blank", "component", "unknown"):
        assert not build.Credit(account, kind)
    assert build.Credit(account, "sand")
    assert account.total.sand == build.Available(account, "sand") == 31


def test_capacity_preserves_credits_and_reserved_materials(construction):
    lua, build = construction
    account = build.NewAccount(lua.table_from({"gravel": build.Cap}))
    build.Reserve(account, build.PropCost)
    assert not build.CanCredit(account, "gravel")
    assert not build.Credit(account, "gravel")
    assert build.Available(account, "gravel") == build.Cap - 1


def test_reload_releases_builds_because_world_is_not_persisted(construction):
    _, build = construction
    account = build.NewAccount()
    build.Credit(account, "mineral")
    build.Reserve(account, build.Cost("gf_extractor"))
    restored = build.NewAccount(account.total)
    assert restored.total.mineral == 41 and restored.reserved.mineral == 0
    assert restored.total.gravel == 40


@pytest.mark.parametrize("value", [-1, float("nan"), float("inf"), 0.5, "12"])
def test_bad_saved_values_and_costs_cannot_create_funds(construction, value):
    lua, build = construction
    account = build.NewAccount(lua.table_from({"gravel": value}))
    assert account.total.gravel == 0
    price = lua.table_from({"gravel": value})
    assert not build.Reserve(account, price)
    assert not build.Release(account, price)

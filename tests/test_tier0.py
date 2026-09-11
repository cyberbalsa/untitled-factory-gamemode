"""Terrain eligibility and material conservation, using the actual Lua rules."""
from pathlib import Path

import pytest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture
def tier0():
    lua = LuaRuntime(unpack_returned_tuples=True)
    rules = lua.execute((ROOT / "gamemodes/gmod_factory/gamemode/core/sh_tier0.lua").read_text())
    return lua, rules


def trace(lua, **changes):
    data = dict(Hit=True, HitWorld=True, HitTexture="**displacement**", MatType=85,
                HitNormal=lua.table_from({"z": 1}))
    data.update(changes)
    return lua.table_from(data)


@pytest.mark.parametrize("material", [68, 85])
def test_displacements_use_tags_without_texture_names(tier0, material):
    lua, rules = tier0
    assert rules.SoilSurface(trace(lua, MatType=material), "", None, True)[0]


@pytest.mark.parametrize("changes", [
    {"Hit": False}, {"HitWorld": False}, {"HitSky": True}, {"HitNoDraw": True},
    {"StartSolid": True}, {"AllSolid": True}, {"HitTexture": "**studio**"}
])
def test_props_void_and_hidden_surfaces_cannot_mine_even_with_override(tier0, changes):
    lua, rules = tier0
    assert not rules.SoilSurface(trace(lua, **changes), "dirt", True, True)[0]


def test_wall_and_ceiling_cannot_mine(tier0):
    lua, rules = tier0
    for slope in (-1, 0, 0.69):
        assert not rules.SoilSurface(trace(lua, HitNormal=lua.table_from({"z": slope})), "dirt", True, True)[0]


def test_surface_names_and_conservative_texture_fallback(tier0):
    lua, rules = tier0
    sample = trace(lua, MatType=88, HitTexture="custom/soil_01")
    assert rules.SoilSurface(sample, "default", None, True)[0]
    assert not rules.SoilSurface(sample, "default", None, False)[0]
    assert rules.SoilSurface(sample, "DIRT", None, False)[0]
    sample.MatType = 77  # An explicitly metal surface overrides a soil-looking filename.
    assert not rules.SoilSurface(sample, "metal", None, True)[0]
    sample.MatType, sample.HitTexture = 67, "concrete/concretefloor"
    assert not rules.SoilSurface(sample, "concrete", None, True)[0]


def test_map_override_can_accept_or_deny_only_valid_ground(tier0):
    lua, rules = tier0
    assert not rules.SoilSurface(trace(lua), "grass", False, True)[0]
    assert rules.SoilSurface(trace(lua, MatType=67), "concrete", True, True)[0]


def test_resource_ids_are_exact_and_unique(tier0):
    _, rules = tier0
    assert [rules.ResourceKind(i) for i in range(10, 15)] == ["soil", "gravel", "sand", "clay", "mineral"]
    for value in (None, "11", 11.5, -1, 0, 1, float("nan"), float("inf")):
        assert rules.ResourceKind(value) is None


def processed(rules):
    state = rules.NewSeparator()
    assert state.Load(state, "soil")
    assert state.Cycle(state, 0)
    state.Tick(state, 4)
    return state


def test_soil_needs_explicit_load_and_cycle(tier0):
    _, rules = tier0
    state = rules.NewSeparator()
    state.Tick(state, 100)
    assert state.Pending(state) == 0 and state.CanLoad(state)
    assert not state.Load(state, "gravel") and state.fault == 2
    state.Reset(state)
    assert state.Load(state, "soil")
    state.Tick(state, 100)
    assert state.soil and state.Pending(state) == 0 and state.Ready(state)


def test_one_batch_preserves_every_fraction_and_requires_emptying(tier0):
    _, rules = tier0
    state = processed(rules)
    assert not state.soil and not state.busy and state.Pending(state) == 4
    assert not state.Load(state, "soil") and not state.Cycle(state, 4)
    for resource, kind in ((13, "clay"), (11, "gravel"), (14, "mineral"), (12, "sand")):
        assert not state.CanLoad(state)
        assert state.Peek(state, resource, False) == kind
        assert state.inventory[kind] == 1  # Peek/failed engine spawn must not consume.
        state.CommitEject(state, kind)
        assert state.inventory[kind] == 0
    assert state.CanLoad(state) and state.Pending(state) == 0 and state.progress == 0
    assert state.Load(state, "soil")


def test_reset_preserves_soil_or_completed_outputs(tier0):
    _, rules = tier0
    state = rules.NewSeparator()
    state.Load(state, "soil")
    state.Cycle(state, 10)
    state.Tick(state, 13.9)
    state.Reset(state)
    state.Tick(state, 100)
    assert state.soil and state.Pending(state) == 0 and state.progress == 0
    assert state.Peek(state, 10, False) == "soil"
    assert state.Cycle(state, 100)
    state.Tick(state, 104)
    state.Reset(state)
    assert state.Pending(state) == 4


def test_busy_commands_cannot_restart_or_eject(tier0):
    _, rules = tier0
    state = rules.NewSeparator()
    state.Load(state, "soil")
    state.Cycle(state, 10)
    assert not state.Cycle(state, 13)
    assert not state.Load(state, "soil")
    assert state.Peek(state, 10, False) is None
    state.Tick(state, 14)
    assert state.Pending(state) == 4


def test_blocked_or_invalid_eject_never_loses_stock(tier0):
    _, rules = tier0
    state = processed(rules)
    assert state.Peek(state, 11, True) is None and state.fault == 3
    assert state.Pending(state) == 4
    state.Reset(state)
    assert state.Peek(state, 99, False) is None and state.fault == 5
    state.Reset(state)
    state.CommitEject(state, state.Peek(state, 11, False))
    assert state.Peek(state, 11, False) is None and state.fault == 4
    assert state.Pending(state) == 3


def test_unprocessed_soil_can_be_recovered(tier0):
    _, rules = tier0
    state = rules.NewSeparator()
    state.Load(state, "soil")
    kind = state.Peek(state, 10, False)
    assert kind == "soil"
    state.CommitEject(state, kind)
    assert not state.soil and state.CanLoad(state) and state.Pending(state) == 0

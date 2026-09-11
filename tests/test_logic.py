"""Run the actual production rules in Lua 5.1, independently of GMod rendering."""
from pathlib import Path

import pytest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
GM = ROOT / "gamemodes" / "gmod_factory"


@pytest.fixture
def rules():
    lua = LuaRuntime(unpack_returned_tuples=True)
    return lua, lua.execute((GM / "gamemode/core/sh_logic.lua").read_text())


def test_all_game_lua_compiles():
    lua = LuaRuntime(unpack_returned_tuples=True)
    compile_lua = lua.eval("function(source, name) local f, err = loadstring(source, name); assert(f, err) end")
    for path in list(GM.rglob("*.lua")) + list((ROOT / "lua").rglob("*.lua")):
        compile_lua(path.read_text(), str(path.relative_to(ROOT)))


def test_material_stays_idle_without_commands(rules):
    _, logic = rules
    press = logic.NewPress()
    assert press.Load(press, "blank")
    press.Tick(press, 100000)
    assert press.item == "blank"
    assert not press.done
    assert not press.busy


def test_complete_sequence_and_output_handoff(rules):
    _, logic = rules
    press = logic.NewPress()
    assert press.Load(press, "blank")
    press.SetClamp(press, True)
    assert press.Ready(press)
    assert press.Cycle(press, 10)
    press.Tick(press, 11.5)
    assert press.progress == 0.5
    assert press.item == "blank"
    press.Tick(press, 13)
    assert press.item == "component"
    assert press.done and not press.busy
    press.SetClamp(press, False)
    assert press.CanEject(press, False)
    assert press.item == "component"  # A failed entity spawn cannot erase the workpiece.
    assert press.CommitEject(press) == "component"
    assert press.item is None and not press.done


def test_cycle_requires_material_and_clamp(rules):
    _, logic = rules
    press = logic.NewPress()
    assert not press.Cycle(press, 0)
    assert press.fault == 1
    press.Reset(press)
    assert not press.Load(press, "component")
    assert press.fault == 4
    press.Reset(press)
    assert press.Load(press, "blank")
    assert not press.Cycle(press, 0)
    assert press.fault == 3


def test_releasing_clamp_aborts_without_free_product(rules):
    _, logic = rules
    press = logic.NewPress()
    press.Load(press, "blank")
    press.SetClamp(press, True)
    press.Cycle(press, 0)
    press.Tick(press, 2.9)
    press.SetClamp(press, False)
    press.Tick(press, 100)
    assert press.fault == 5
    assert press.item == "blank" and not press.done
    press.Reset(press)
    press.SetClamp(press, True)
    assert press.Cycle(press, 100)
    press.Tick(press, 102.9)
    assert not press.done
    press.Tick(press, 103)
    assert press.done


def test_blocked_ejection_preserves_product_until_recovery(rules):
    _, logic = rules
    press = logic.NewPress()
    press.Load(press, "blank")
    press.SetClamp(press, True)
    press.Cycle(press, 0)
    press.Tick(press, 3)
    assert not press.CanEject(press, False)
    assert press.fault == 2  # Clamp still holds the workpiece.
    press.SetClamp(press, False)
    press.Reset(press)
    assert not press.CanEject(press, True)
    assert press.fault == 6 and press.item == "component"
    press.Reset(press)
    assert press.CanEject(press, False)


def test_reset_cancels_active_cycle_but_keeps_blank(rules):
    _, logic = rules
    press = logic.NewPress()
    press.Load(press, "blank")
    press.SetClamp(press, True)
    press.Cycle(press, 0)
    press.Reset(press)
    press.Tick(press, 100)
    assert press.item == "blank" and not press.busy and not press.done


def test_busy_pulses_do_not_restart_clock_or_accept_extra_stock(rules):
    _, logic = rules
    press = logic.NewPress()
    press.Load(press, "blank")
    press.SetClamp(press, True)
    press.Cycle(press, 0)
    assert not press.Cycle(press, 2)
    assert not press.Load(press, "blank")
    press.Tick(press, 3)
    assert press.done


def test_actions_are_edge_triggered_and_rearm(rules):
    lua, logic = rules
    edges = lua.table()
    assert logic.Rising(edges, "Cycle", 1)
    assert not logic.Rising(edges, "Cycle", 1)
    assert not logic.Rising(edges, "Cycle", 10)
    assert not logic.Rising(edges, "Cycle", 0)
    assert logic.Rising(edges, "Cycle", 1)
    assert logic.Rising(edges, "Load", 1)


@pytest.mark.parametrize("value", [None, "1", float("nan"), float("inf"), -1, 0])
def test_invalid_signal_is_not_high(rules, value):
    assert not rules[1].High(value)


def test_contract_completion_and_restore(rules):
    _, logic = rules
    contract = logic.NewContract()
    assert logic.Quota(contract.order) == 10
    for _ in range(9):
        assert not logic.Deliver(contract)
    assert logic.Deliver(contract)
    assert contract.order == 2 and contract.favor == 100 and contract.delivered == 0
    assert logic.Quota(contract.order) == 15
    logic.Deliver(contract)
    restored = logic.NewContract(contract)
    assert restored.order == 2 and restored.delivered == 1 and restored.favor == 100


@pytest.mark.parametrize("saved", [None, "bad", False, 7])
def test_invalid_save_falls_back(rules, saved):
    contract = rules[1].NewContract(saved)
    assert contract.order == 1 and contract.delivered == 0 and contract.favor == 0


def test_saved_counters_are_bounded(rules):
    lua, logic = rules
    contract = logic.NewContract(lua.table_from({"order": -50, "delivered": 1e20, "favor": float("nan")}))
    assert contract.order == 1 and contract.delivered == 9 and contract.favor == 0

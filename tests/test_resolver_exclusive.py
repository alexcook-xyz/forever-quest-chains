"""ns.ResolveChain and exclusive quests (issue #56).

Core.lua needs the WoW client, so this test cuts the resolver out of the real
file (from the exclusive-quest helper to the checklist) and runs it in a Lua 5.1
runtime (lupa.lua51) with a fake `ns` that holds the quest state.
"""
from __future__ import annotations

import pathlib

import pytest

lua51 = pytest.importorskip("lupa.lua51")

CORE = (pathlib.Path(__file__).resolve().parent.parent / "MainStoryGuide" / "Core.lua").read_text(encoding="utf-8")
START = CORE.index("-- Exclusive quests (issue #56)")
END = CORE.index("-- Per-quest checklist for one chain")
RESOLVER = CORE[START:END]

HARNESS = """
local ns = { done = {}, log = {} }
ns.IsCompleted = function(id) return ns.done[id] and true or false end
ns.IsInLog = function(id) return ns.log[id] and true or false end
ns.EffectiveQuests = function(chain) return chain.quests end
ns.BreadcrumbBlockedIDs = function() return {} end
%s
return function(done, log, chain)
  ns.done, ns.log = {}, {}
  for _, id in ipairs(done) do ns.done[id] = true end
  for _, id in ipairs(log) do ns.log[id] = true end
  local r = ns.ResolveChain(chain)
  return r.state, r.done, r.total, r.target and r.target.id or 0, r.targetIndex or 0
end
"""


@pytest.fixture(scope="module")
def resolve():
    rt = lua51.LuaRuntime(unpack_returned_tuples=True)
    fn = rt.execute(HARNESS % RESOLVER)

    def run(done=(), log=(), chain=None):
        lua_chain = rt.table_from({"quests": chain}, recursive=True)
        return fn(rt.table_from(list(done)), rt.table_from(list(log)), lua_chain)

    return run


PAMELA = [{"id": 5142, "exclusiveWith": [5601]}, {"id": 5601, "exclusiveWith": [5142]}, {"id": 5149}, {"id": 5152}]


def test_pair_counts_as_one_step_before_any_choice(resolve):
    state, done, total, target, index = resolve(chain=PAMELA)
    assert (state, done, total, target, index) == ("PICKUP", 0, 3, 5142, 1)


@pytest.mark.parametrize("chosen", [5142, 5601])
def test_either_start_finishes_the_chain(resolve, chosen):
    state, done, total, _, _ = resolve(done=[chosen, 5149, 5152], chain=PAMELA)
    assert (state, done, total) == ("DONE", 3, 3)


def test_unchosen_start_is_not_a_gap(resolve):
    state, done, total, target, index = resolve(done=[5601], chain=PAMELA)
    assert (state, done, total, target, index) == ("PICKUP", 1, 3, 5149, 3)


def test_quest_in_log_is_the_current_step(resolve):
    state, done, total, target, _ = resolve(log=[5601], chain=PAMELA)
    assert (state, done, total, target) == ("IN_PROGRESS", 0, 3, 5601)


def test_done_start_wins_over_the_other_in_log(resolve):
    state, done, total, _, _ = resolve(done=[5142, 5149, 5152], log=[5601], chain=PAMELA)
    assert (state, done, total) == ("DONE", 3, 3)


def test_both_done_counts_once(resolve):
    _, done, total, _, _ = resolve(done=[5142, 5601], chain=PAMELA)
    assert (done, total) == (1, 3)


def test_chain_without_the_field_does_not_change(resolve):
    plain = [{"id": 1}, {"id": 2}, {"id": 3}]
    assert resolve(done=[1], chain=plain) == ("PICKUP", 1, 3, 2, 2)
    assert resolve(done=[1, 2, 3], chain=plain)[0] == "DONE"


def test_one_way_entry_still_pairs_both(resolve):
    one_way = [{"id": 5142, "exclusiveWith": [5601]}, {"id": 5601}, {"id": 5149}]
    assert resolve(chain=one_way) == ("PICKUP", 0, 2, 5142, 1)
    assert resolve(done=[5601, 5149], chain=one_way)[0] == "DONE"
    assert resolve(done=[5142, 5149], chain=one_way)[0] == "DONE"


def test_later_progress_beside_a_pair_is_a_gap(resolve):
    chain = [{"id": 1}, {"id": 2, "exclusiveWith": [3]}, {"id": 3, "exclusiveWith": [2]}, {"id": 4}]
    assert resolve(done=[4], chain=chain)[0] == "GAP"
    assert resolve(done=[1, 3, 4], chain=chain)[0] == "DONE"

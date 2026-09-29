// Monetary values are in the tournament currency; a documented zero is final.
export function tournamentRoundPrize(t: any, result: string, eventType = "singles") {
  const code = String(result || "").toUpperCase() === "CHAMPION" ? "W" : String(result || "").toUpperCase();
  const phase = eventType === "qualifying" ? "qualifying" : eventType === "doubles" ? "doubles" : "singles";
  const table = t[phase + "_prize_by_result"] || {};
  const aliases: Record<string, string> = { R24: "R32", R28: "R32", R48: "R64", R56: "R64", R96: "R128" };
  const key = Object.hasOwn(table, code) ? code : aliases[code];
  const estimated = t[phase + "_prize_is_estimate"] !== false;
  if (key && Object.hasOwn(table, key)) {
    return { amount: Math.max(0, Math.round((Number(table[key]) || 0) * 100) / 100), estimated, phase };
  }
  // Empty official tables (notably ITF qualifying) mean no payment. Never
  // invent a gain for a missing round inside an otherwise populated table.
  if (!estimated || Object.keys(table).length || Number(t.prize_money || 0) <= 0) {
    return { amount: 0, estimated, phase };
  }
  const weights: Record<string, number> = phase === "doubles"
    ? { W: .09, F: .055, SF: .032, QF: .018, R16: .007, R32: .004, R64: .002 }
    : phase === "qualifying" ? { Q1: .003, Q2: .004, Q3: .005 }
    : { W: .18, F: .10, SF: .055, QF: .03, R16: .015, R32: .008, R64: .003, R128: .0015 };
  return { amount: Math.max(0, Math.round(Number(t.prize_money || 0) * (weights[code] ?? weights[aliases[code]] ?? 0))), estimated: true, phase };
}


export function tournamentDoublesDrawConfig(t: any) {
  const singlesDraw = Math.max(8, Math.min(128, Number(t?.singles_draw_size || t?.draw_size || 32)));
  const drawSize = Math.max(4, Math.min(64, Number(t?.doubles_draw_size || Math.min(32, singlesDraw))));
  const seedCount = drawSize >= 64 ? 16 : drawSize >= 24 ? 8 : drawSize >= 16 ? 4 : Math.min(2, drawSize);
  return { drawSize, seedCount };
}


export function projectedTournamentCuts(t: any, main: any[] = [], qualifying: any[] = []) {
  const ranks = (rows: any[], method?: string) => rows
    .filter((x: any) => !method || String(x?.entry_method || "") === method)
    .map((x: any) => Number(x?.ranking))
    .filter((x: number) => Number.isFinite(x) && x > 0);
  const directRanks = ranks(main, "direct");
  const qualRanks = ranks(qualifying);
  const direct = directRanks.length ? Math.max(...directRanks) : null;
  const qual = qualRanks.length ? Math.max(...qualRanks) : null;
  return {
    ...t,
    projected_direct_cut: t?.direct_cut == null && direct != null ? direct : t?.projected_direct_cut ?? null,
    projected_qual_cut: t?.qual_cut == null && qual != null ? qual : t?.projected_qual_cut ?? null,
    projected_cut_model: direct != null || qual != null ? "eligible_field_v1" : t?.projected_cut_model ?? null
  };
}


export function juniorTournamentFormatRule(t: any) {
  const draw = Math.max(8, Math.min(128, Math.floor(Number(t?.singles_draw_size || t?.draw_size || 32))));
  const roundRobin = /round_robin_to_elimination/i.test(String(t?.junior_draw_format || ""));
  const byDraw = <T>(table: Record<number, T>, fallback: T) => table[draw] ?? fallback;
  const bracketSize = draw <= 8 ? 8 : draw <= 16 ? 16 : draw <= 32 ? 32 : draw <= 64 ? 64 : 128;
  const seedCount = byDraw({8:2,16:4,24:8,32:8,48:16,64:16,96:16,128:16}, Math.min(16, Math.max(2, bracketSize / 4)));
  const qualifierCount = roundRobin && draw === 32
    ? 8
    : byDraw({16:2,24:2,32:4,48:6,64:8,96:8,128:8}, Math.min(8, Math.max(2, Math.floor(draw / 8))));
  const wildcardCount = roundRobin && draw === 32
    ? 4
    : byDraw({16:2,24:2,32:4,48:6,64:8,96:8,128:8}, Math.min(8, Math.max(2, Math.floor(draw / 8))));
  const qualifyingDrawSize = Math.min(draw, Math.max(0, Math.floor(Number(t?.qualifying_draw_size || 0))));
  const doublesDrawSize = Math.max(4, Math.min(64, Math.floor(Number(t?.doubles_draw_size || Math.ceil(draw / 2)))));
  const rounds: string[] = [];
  if (roundRobin && draw === 32) {
    rounds.push("RR","QF","SF","F");
  } else {
    if (draw !== bracketSize) rounds.push("R" + draw);
    let size = draw === bracketSize ? draw : bracketSize / 2;
    while (size >= 16) { rounds.push("R" + size); size /= 2; }
    rounds.push("QF","SF","F");
  }
  return {
    rule_key: "JUNIOR_" + String(t?.category || "EVENT").replace(/[^A-Z0-9]+/gi, "_").toUpperCase() + "_" + draw + (roundRobin ? "_RR" : "_KO"),
    circuit: "Junior",
    category: String(t?.category || ""),
    main_draw_size: draw,
    bracket_size: bracketSize,
    qualifying_draw_size: qualifyingDrawSize,
    doubles_draw_size: doublesDrawSize,
    format_type: roundRobin ? "round_robin" : "knockout",
    seed_count: seedCount,
    qualifier_count: qualifyingDrawSize ? qualifierCount : 0,
    wildcard_count: wildcardCount,
    rounds,
    points_by_result: {},
    qualifying_points: {},
    source_label: "ITF 2026 World Tennis Tour Juniors Regulations · Regulations 45 & 47",
    source_url: "https://www.itftennis.com/media/15745/2026-itf-world-tennis-tour-juniors-regulations.pdf"
  };
}


export function qualifyingSectionPlan(drawSize: number, qualifierSlots: number) {
  const draw = Math.max(0, Math.floor(Number(drawSize) || 0));
  const slots = Math.max(0, Math.floor(Number(qualifierSlots) || 0));
  if (!draw || !slots || draw < slots) {
    return {
      drawSize: draw, qualifierSlots: slots, sectionCount: 0,
      sectionPlayers: 0, sectionSize: 0, bracketTotal: 0, byeCount: 0, rounds: 0
    };
  }
  const sectionPlayers = Math.max(2, Math.ceil(draw / slots));
  const rounds = Math.max(1, Math.ceil(Math.log2(sectionPlayers)));
  const sectionSize = 2 ** rounds;
  const bracketTotal = sectionSize * slots;
  return {
    drawSize: draw,
    qualifierSlots: slots,
    sectionCount: slots,
    sectionPlayers,
    sectionSize,
    bracketTotal,
    byeCount: Math.max(0, bracketTotal - draw),
    rounds
  };
}

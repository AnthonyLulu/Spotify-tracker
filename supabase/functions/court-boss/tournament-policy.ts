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

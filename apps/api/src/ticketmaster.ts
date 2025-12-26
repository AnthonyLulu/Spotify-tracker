import axios from "axios";

/**
 * Ticketmaster Discovery API v2
 * On va chercher des events "music" par keyword (nom d'artiste).
 */
const TM_BASE = "https://app.ticketmaster.com/discovery/v2";

export type TMEvent = {
  id: string;
  name: string;
  url: string;

  dates?: {
    start?: {
      dateTime?: string; // ex: "2026-02-12T19:00:00Z"
      localDate?: string; // ex: "2026-02-12"
    };
  };

  _embedded?: {
    venues?: Array<{
      name?: string;
      city?: { name?: string };
      country?: { countryCode?: string };
    }>;
  };
};

export async function searchTicketmasterEvents(params: {
  keyword: string;
  countryCode?: string; // ex "FR"
  classificationName?: string; // ex "music"
  size?: number; // nb de résultats
}) {
  const apiKey = process.env.TICKETMASTER_API_KEY;
  if (!apiKey) throw new Error("Missing TICKETMASTER_API_KEY in env");

  const res = await axios.get(`${TM_BASE}/events.json`, {
    params: {
      apikey: apiKey,
      keyword: params.keyword,
      countryCode: params.countryCode ?? process.env.TICKETMASTER_COUNTRY ?? "FR",
      classificationName: params.classificationName ?? process.env.TICKETMASTER_CLASSIFICATION ?? "music",
      size: params.size ?? 20
    }
  });

  // Ticketmaster met les events ici: _embedded.events
  const events: TMEvent[] = res.data?._embedded?.events ?? [];
  return events;
}

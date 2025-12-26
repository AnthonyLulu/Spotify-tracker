import axios from "axios";

type TMEvent = {
  id: string;
  url?: string;
  name?: string;
  dates?: { start?: { dateTime?: string; localDate?: string } };
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
  countryCode?: string; // "FR"
  size?: number;        // default 50
}): Promise<TMEvent[]> {
  const apiKey = process.env.TICKETMASTER_API_KEY;
  if (!apiKey) throw new Error("❌ TICKETMASTER_API_KEY manquant dans .env");

  const { keyword, countryCode = "FR", size = 50 } = params;

  const url = "https://app.ticketmaster.com/discovery/v2/events.json";
  const res = await axios.get(url, {
    params: {
      apikey: apiKey,
      keyword,
      countryCode,
      classificationName: "music",
      size
    }
  });

  const events = res.data?._embedded?.events ?? [];
  return events as TMEvent[];
}

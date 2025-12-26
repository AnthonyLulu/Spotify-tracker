import { Artist } from "../models/Artist";
import { Site } from "../models/Site";
import { EventType } from "../models/EventType";
import { Event } from "../models/Event";
import { searchTicketmasterEvents } from "../ticketmaster";

export async function syncTicketmasterForArtist(artistId: string) {
  const artist = await Artist.findById(artistId);
  if (!artist) throw new Error("Artist not found");

  // site "ticketmaster" en DB
  const site = await Site.findOne({ name: "ticketmaster" });
  if (!site) throw new Error("Site ticketmaster missing (seed sites)");

  // type "Concert" en DB (ou "concert", choisis un nom et reste constant)
  const concertType =
    (await EventType.findOne({ name: "Concert" })) ??
    (await EventType.create({ name: "Concert" }));

  // appel Ticketmaster
  const tmEvents = await searchTicketmasterEvents({ keyword: artist.name });

  let upserted = 0;

  for (const tmEvent of tmEvents) {
    const venue = tmEvent._embedded?.venues?.[0];
    const venueName = venue?.name ?? null;
    const cityName = venue?.city?.name ?? null;

    const dateStr = tmEvent.dates?.start?.dateTime ?? tmEvent.dates?.start?.localDate ?? null;
    const dateValue = dateStr ? new Date(dateStr) : null;

    await Event.findOneAndUpdate(
      { source: "ticketmaster", externalId: tmEvent.id },
      {
        source: "ticketmaster",
        externalId: tmEvent.id,
        siteId: site._id,
        artistId: artist._id,
        artistName: artist.name,
        url: tmEvent.url,
        venue: venueName,
        city: cityName,
        date: dateValue,
        eventTypeId: concertType._id,
        lastCheckAt: new Date()
      },
      { upsert: true, new: true }
    );

    upserted++;
  }

  return { artistId, artistName: artist.name, count: upserted };
}

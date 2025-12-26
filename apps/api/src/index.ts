import fs from "node:fs";
import path from "node:path";
import dotenv from "dotenv";
import express, { type Request, type Response } from "express";
import cors from "cors";

const cwd = process.cwd();
const envPath =
  fs.existsSync(path.join(cwd, ".env")) ? ".env" :
  fs.existsSync(path.join(cwd, ".env.local")) ? ".env.local" :
  undefined;

dotenv.config(envPath ? { path: envPath } : undefined);

import { connectDB } from "./db";
import { Artist } from "./models/Artist";
import { User } from "./models/User";
import { Event } from "./models/Event";
import { signJwt } from "./auth";
import { requireAuth, type AuthedRequest } from "./middleware/requireAuth";
import { exchangeCodeForToken, getMe, refreshAccessToken, searchArtistsSpotify } from "./spotify";
import { searchTicketmasterEvents } from "./ticketmaster";
import { Site } from "./models/Site";
import { EventType } from "./models/EventType";

const app = express();
app.use(cors());
app.use(express.json());

/**
 * ✅ Base URL API pour OAuth Spotify
 * Spotify refuse localhost en redirect_uri -> on force 127.0.0.1
 */
const port = Number(process.env.PORT ?? 3001);
const API_BASE_OAUTH = `http://127.0.0.1:${port}`;

function callbackUri(kind: "web" | "mobile") {
  return kind === "web"
    ? `${API_BASE_OAUTH}/auth/spotify/callback/web`
    : `${API_BASE_OAUTH}/auth/spotify/callback/mobile`;
}

app.get("/health", (_req: Request, res: Response) => {
  res.json({ ok: true, service: "api" });
});

/**
 * 0) GET artists (pour choper rapidement un artistId Mongo)
 * GET /artists?name=aya
 */
app.get("/artists", requireAuth, async (req: AuthedRequest, res: Response) => {
  const name = String(req.query.name ?? "").trim();
  if (!name) return res.json([]);

  const docs = await Artist.find({
    name: { $regex: name, $options: "i" }
  }).limit(20);

  return res.json(docs.map((a) => ({
    _id: String(a._id),
    name: a.name,
    spotifyId: a.spotifyId
  })));
});

/**
 * 1) LOGIN Spotify
 */
function buildAuthorizeUrl(kind: "web" | "mobile") {
  const redirectUri = callbackUri(kind);
  const scope = ["user-read-email", "user-read-private"].join(" ");

  const params = new URLSearchParams({
    client_id: process.env.SPOTIFY_CLIENT_ID ?? "",
    response_type: "code",
    redirect_uri: redirectUri,
    scope,
    show_dialog: "false"
  });

  console.log(`[OAuth] authorize (${kind}) redirect_uri=`, redirectUri);
  return `https://accounts.spotify.com/authorize?${params.toString()}`;
}

app.get("/auth/spotify/login/web", (_req, res) => res.redirect(buildAuthorizeUrl("web")));
app.get("/auth/spotify/login/mobile", (_req, res) => res.redirect(buildAuthorizeUrl("mobile")));

/**
 * 2) CALLBACK WEB
 */
app.get("/auth/spotify/callback/web", async (req: Request, res: Response) => {
  console.log("[OAuth] callback web query:", req.query);

  const code = String(req.query.code ?? "");
  const err = String(req.query.error ?? "");

  if (err) return res.status(400).send(`Spotify error: ${err}`);
  if (!code) return res.status(400).send("Missing code");

  const redirectUri = callbackUri("web");

  const token = await exchangeCodeForToken(code, redirectUri);
  console.log("[OAuth] exchange OK, refresh token present:", !!token.refresh_token);

  const me = await getMe(token.access_token);

  const user = await User.findOneAndUpdate(
    { spotifyUserId: me.id },
    { spotifyUserId: me.id, displayName: me.display_name, refreshToken: token.refresh_token },
    { upsert: true, new: true }
  );

  const jwt = signJwt({ userId: String(user._id) });

  const webUrl = process.env.WEB_APP_URL ?? "http://localhost:8081";
  return res.redirect(`${webUrl}/auth/callback?token=${encodeURIComponent(jwt)}`);
});

/**
 * 3) CALLBACK MOBILE
 */
app.get("/auth/spotify/callback/mobile", async (req: Request, res: Response) => {
  console.log("[OAuth] callback mobile query:", req.query);

  const code = String(req.query.code ?? "");
  const err = String(req.query.error ?? "");

  if (err) return res.status(400).send(`Spotify error: ${err}`);
  if (!code) return res.status(400).send("Missing code");

  const redirectUri = callbackUri("mobile");

  const token = await exchangeCodeForToken(code, redirectUri);
  const me = await getMe(token.access_token);

  const user = await User.findOneAndUpdate(
    { spotifyUserId: me.id },
    { spotifyUserId: me.id, displayName: me.display_name, refreshToken: token.refresh_token },
    { upsert: true, new: true }
  );

  const jwt = signJwt({ userId: String(user._id) });

  const scheme = process.env.MOBILE_SCHEME ?? "spotifytracker";
  return res.redirect(`${scheme}://auth/callback?token=${encodeURIComponent(jwt)}`);
});

/**
 * 4) SEARCH Spotify + save Artist en DB
 * GET /spotify/artists/search?q=drake
 */
app.get("/spotify/artists/search", requireAuth, async (req: AuthedRequest, res: Response) => {
  const q = String(req.query.q ?? "").trim();
  if (!q) return res.json([]);

  const user = await User.findById(req.userId);
  if (!user) return res.status(401).json({ error: "User not found" });

  const { access_token } = await refreshAccessToken(user.refreshToken);

  const data = await searchArtistsSpotify(access_token, q);
  const items = (data?.artists?.items ?? []) as any[];

  const mapped = items.map((a) => ({
    spotifyId: a.id,
    name: a.name,
    genres: a.genres ?? [],
    popularity: a.popularity,
    followers: a.followers?.total,
    image: a.images?.[0]?.url
  }));

  for (const doc of mapped) {
    await Artist.findOneAndUpdate({ spotifyId: doc.spotifyId }, doc, { upsert: true, new: true });
  }

  return res.json(mapped);
});

/**
 * ✅ Helpers "ensure" (Site / EventType)
 * (si t’as déjà des docs en DB tu peux adapter)
 */
async function ensureTicketmasterSite() {
  const doc = await Site.findOneAndUpdate(
    { name: "Ticketmaster" },
    { name: "Ticketmaster", urlBase: "https://www.ticketmaster.fr" },
    { upsert: true, new: true }
  );
  return doc;
}

async function ensureConcertEventType() {
  const doc = await EventType.findOneAndUpdate(
    { name: "Concert" },
    { name: "Concert" },
    { upsert: true, new: true }
  );
  return doc;
}

/**
 * 5) SYNC Ticketmaster -> Events
 * POST /integrations/ticketmaster/sync/:artistId
 */
app.post("/integrations/ticketmaster/sync/:artistId", requireAuth, async (req: AuthedRequest, res: Response) => {
  const artistId = String(req.params.artistId ?? "").trim();
  if (!artistId) return res.status(400).json({ error: "Missing artistId" });

  const artist = await Artist.findById(artistId);
  if (!artist) return res.status(404).json({ error: "Artist not found" });

  const site = await ensureTicketmasterSite();
  const typeConcert = await ensureConcertEventType();

  const tmEvents = await searchTicketmasterEvents({
    keyword: artist.name,
    countryCode: "FR",
    size: 50
  });

  let upserted = 0;

  for (const ev of tmEvents) {
    const venue = ev._embedded?.venues?.[0];
    const venueName = venue?.name ?? null;
    const cityName = venue?.city?.name ?? null;

    const dateStr = ev.dates?.start?.dateTime ?? ev.dates?.start?.localDate ?? null;
    const dateValue = dateStr ? new Date(dateStr) : null;

    await Event.findOneAndUpdate(
      { source: "ticketmaster", externalId: ev.id },
      {
        source: "ticketmaster",
        externalId: ev.id,

        siteId: site._id,
        artistId: artist._id,
        artistName: artist.name,

        url: ev.url ?? "",
        venue: venueName,
        city: cityName,
        date: dateValue,

        eventTypeId: typeConcert._id,
        lastCheckAt: new Date()
      },
      { upsert: true, new: true }
    );

    upserted++;
  }

  return res.json({
    ok: true,
    artist: { _id: String(artist._id), name: artist.name },
    source: "ticketmaster",
    upserted
  });
});

/**
 * ✅ START
 */
async function start() {
  await connectDB();

  // 💡 si tu lances via Docker et que ça marche pas, mets "0.0.0.0"
  app.listen(port, () => {
    console.log(`✅ API running on http://localhost:${port}`);
    console.log(`✅ OAuth base (Spotify): ${API_BASE_OAUTH}`);
  });
}

start();

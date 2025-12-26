import "dotenv/config";
import express, { type Request, type Response } from "express";
import cors from "cors";

import { connectDB } from "./db";
import { Artist } from "./models/Artist";
import { User } from "./models/User";
import { signJwt } from "./auth";
import { requireAuth, type AuthedRequest } from "./middleware/requireAuth";
import {
  exchangeCodeForToken,
  getMe,
  refreshAccessToken,
  searchArtistsSpotify
} from "./spotify";

const app = express();
app.use(cors());
app.use(express.json());

/**
 * ✅ Base URL API (Spotify OAuth)
 * Spotify n'accepte plus "localhost" pour redirect_uri.
 * En local => loopback IP 127.0.0.1 (HTTP autorisé).
 */
const port = Number(process.env.PORT ?? 3001);
const API_BASE = `http://127.0.0.1:${port}`;

/**
 * ✅ Callback URIs (doivent matcher EXACTEMENT ceux du dashboard Spotify)
 * À ajouter dans Spotify Developer Dashboard > Redirect URIs :
 * - http://127.0.0.1:3001/auth/spotify/callback/web
 * - http://127.0.0.1:3001/auth/spotify/callback/mobile
 */
function callbackUri(kind: "web" | "mobile") {
  return kind === "web"
    ? `${API_BASE}/auth/spotify/callback/web`
    : `${API_BASE}/auth/spotify/callback/mobile`;
}

/**
 * ✅ Health check
 */
app.get("/health", (_req: Request, res: Response) => {
  res.json({ ok: true, service: "api" });
});

/**
 * 1) LOGIN Spotify
 * Redirige vers Spotify /authorize
 */
 /*app.get("/debug/search", async (req: Request, res: Response) => {
  const q = String(req.query.q ?? "drake").trim();

  const user = await User.findOne();
  if (!user) return res.status(404).json({ error: "No user in DB" });

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

  // save mongo
  for (const doc of mapped) {
    await Artist.findOneAndUpdate({ spotifyId: doc.spotifyId }, doc, {
      upsert: true,
      new: true
    });
  }

  return res.json(mapped);
}); */

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

  const url = `https://accounts.spotify.com/authorize?${params.toString()}`;
  console.log(`[OAuth] authorize (${kind}) redirect_uri=`, redirectUri);
  return url;
}

app.get("/auth/spotify/login/web", (_req, res) => res.redirect(buildAuthorizeUrl("web")));
app.get("/auth/spotify/login/mobile", (_req, res) => res.redirect(buildAuthorizeUrl("mobile")));

/**
 * 2) CALLBACK WEB
 * Spotify renvoie ?code=... ou ?error=...
 */
app.get("/auth/spotify/callback/web", async (req: Request, res: Response) => {
  console.log("[OAuth] callback web query:", req.query);

  const code = String(req.query.code ?? "");
  const err = String(req.query.error ?? "");

  if (err) return res.status(400).send(`Spotify error: ${err}`);
  if (!code) return res.status(400).send("Missing code");

  const redirectUri = callbackUri("web");

  // code -> tokens
  const token = await exchangeCodeForToken(code, redirectUri);
  console.log("[OAuth] exchange OK, refresh token present:", !!token.refresh_token);

  // profil Spotify
  const me = await getMe(token.access_token);

  // upsert user (refresh token)
  const user = await User.findOneAndUpdate(
    { spotifyUserId: me.id },
    {
      spotifyUserId: me.id,
      displayName: me.display_name,
      refreshToken: token.refresh_token
    },
    { upsert: true, new: true }
  );

  // JWT interne app
  const jwt = signJwt({ userId: String(user._id) });

  // redirection vers le front web
  const webUrl = process.env.WEB_APP_URL ?? "http://localhost:8081";
  return res.redirect(`${webUrl}/auth/callback?token=${encodeURIComponent(jwt)}`);
});

/**
 * 3) CALLBACK MOBILE
 * Même flow, mais on renvoie un deep link
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
    {
      spotifyUserId: me.id,
      displayName: me.display_name,
      refreshToken: token.refresh_token
    },
    { upsert: true, new: true }
  );

  const jwt = signJwt({ userId: String(user._id) });

  const scheme = process.env.MOBILE_SCHEME ?? "spotifytracker";
  return res.redirect(`${scheme}://auth/callback?token=${encodeURIComponent(jwt)}`);
});

/**
 * 4) SEARCH Spotify réel + save en DB
 * GET /spotify/artists/search?q=drake
 *
 * Auth: Authorization: Bearer <jwt>
 */
app.get("/spotify/artists/search", requireAuth, async (req: AuthedRequest, res: Response) => {
  const q = String(req.query.q ?? "").trim();
  if (!q) return res.json([]);

  const user = await User.findById(req.userId);
  if (!user) return res.status(401).json({ error: "User not found" });

  // refresh access token Spotify (via refresh token DB)
  const { access_token } = await refreshAccessToken(user.refreshToken);

  // appel Spotify /search
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

  // upsert Mongo
  for (const doc of mapped) {
    await Artist.findOneAndUpdate({ spotifyId: doc.spotifyId }, doc, {
      upsert: true,
      new: true
    });
  }

  return res.json(mapped);
});

/**
 * ✅ START
 */
async function start() {
  await connectDB();

  app.listen(port, () => {
    console.log(`✅ API running on http://localhost:${port}`);
    console.log(`✅ OAuth base (Spotify): ${API_BASE}`);
  });
}

start();

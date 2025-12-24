import "dotenv/config";
import express, { type Request, type Response } from "express";
import cors from "cors";

import { connectDB } from "./db";
import { Artist } from "./models/Artist";
import { User } from "./models/User";
import { signJwt } from "./auth";
import { requireAuth, type AuthedRequest } from "./middleware/requireAuth";
import { exchangeCodeForToken, getMe, refreshAccessToken, searchArtistsSpotify } from "./spotify";

const app = express();
app.use(cors());
app.use(express.json());

app.get("/health", (_req: Request, res: Response) => {
  res.json({ ok: true, service: "api" });
});

/**
 * 1) LOGIN Spotify
 * /auth/spotify/login/web
 * /auth/spotify/login/mobile
 */
function buildAuthorizeUrl(kind: "web" | "mobile") {
  const redirectUri =
    kind === "web"
      ? "http://localhost:3001/auth/spotify/callback/web"
      : "http://localhost:3001/auth/spotify/callback/mobile";

  const params = new URLSearchParams({
    client_id: process.env.SPOTIFY_CLIENT_ID ?? "",
    response_type: "code",
    redirect_uri: redirectUri,
    scope: ["user-read-email", "user-read-private"].join(" "),
    show_dialog: "false"
  });

  return `https://accounts.spotify.com/authorize?${params.toString()}`;
}

app.get("/auth/spotify/login/web", (_req, res) => res.redirect(buildAuthorizeUrl("web")));
app.get("/auth/spotify/login/mobile", (_req, res) => res.redirect(buildAuthorizeUrl("mobile")));

/**
 * 2) CALLBACK WEB
 * -> échange code -> récupère refresh token -> crée user -> renvoie JWT vers front web
 */
app.get("/auth/spotify/callback/web", async (req: Request, res: Response) => {
  const code = String(req.query.code ?? "");
  if (!code) return res.status(400).send("Missing code");

  const redirectUri = "http://localhost:3001/auth/spotify/callback/web";
  const token = await exchangeCodeForToken(code, redirectUri);
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
 * -> renvoie deep link vers Expo
 */
app.get("/auth/spotify/callback/mobile", async (req: Request, res: Response) => {
  const code = String(req.query.code ?? "");
  if (!code) return res.status(400).send("Missing code");

  const redirectUri = "http://localhost:3001/auth/spotify/callback/mobile";
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
 * 4) SEARCH Spotify réel + save en DB
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

  // upsert en DB
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

  res.json(mapped);
});

const port = Number(process.env.PORT ?? 3001);

async function start() {
  await connectDB();
  app.listen(port, () => console.log(`✅ API running on http://localhost:${port}`));
}

start();

import axios from "axios";

const accounts = axios.create({
  baseURL: "https://accounts.spotify.com",
  headers: { "Content-Type": "application/x-www-form-urlencoded" }
});

const api = axios.create({
  baseURL: "https://api.spotify.com/v1"
});

function basicAuthHeader() {
  const raw = `${process.env.SPOTIFY_CLIENT_ID}:${process.env.SPOTIFY_CLIENT_SECRET}`;
  const b64 = Buffer.from(raw).toString("base64");
  return `Basic ${b64}`;
}

export async function exchangeCodeForToken(code: string, redirectUri: string) {
  const params = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: redirectUri
  });

  const { data } = await accounts.post("/api/token", params.toString(), {
    headers: { Authorization: basicAuthHeader() }
  });

  return data as {
    access_token: string;
    refresh_token: string;
    expires_in: number;
    token_type: "Bearer";
    scope: string;
  };
}

export async function refreshAccessToken(refreshToken: string) {
  const params = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken
  });

  const { data } = await accounts.post("/api/token", params.toString(), {
    headers: { Authorization: basicAuthHeader() }
  });

  return data as {
    access_token: string;
    expires_in: number;
    token_type: "Bearer";
    scope: string;
  };
}

export async function getMe(accessToken: string) {
  const { data } = await api.get("/me", {
    headers: { Authorization: `Bearer ${accessToken}` }
  });

  return data as { id: string; display_name: string };
}

export async function searchArtistsSpotify(accessToken: string, q: string) {
  const { data } = await api.get("/search", {
    headers: { Authorization: `Bearer ${accessToken}` },
    params: { q, type: "artist", limit: 10 }
  });

  return data as any;
}

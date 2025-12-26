import { useState } from "react";
import { View, TextInput, Button, Text, FlatList, Image, Platform } from "react-native";
import { useAuthStore } from "../../src/store/authStore";
import { API_BASE } from "../../src/lib/api";

type Artist = {
  spotifyId: string;
  name: string;
  image?: string;
  followers?: number;
  popularity?: number;
};

export default function Home() {
  const token = useAuthStore((s) => s.token);
  const logout = useAuthStore((s) => s.logout);

  const [q, setQ] = useState("drake");
  const [data, setData] = useState<Artist[]>([]);
  const [loading, setLoading] = useState(false);

  // ✅ Login Spotify (WEB)
  function login() {
    if (Platform.OS === "web") {
      window.location.href = `${API_BASE}/auth/spotify/login/web`;
    } else {
      alert("Login mobile après (deep link). Là on valide le web d'abord.");
    }
  }

  // ✅ Search via l'API (JWT obligatoire)
  async function search() {
    if (!token) {
      alert("T'es pas connecté. Clique sur Login Spotify.");
      return;
    }

    setLoading(true);
    try {
      const res = await fetch(
        `${API_BASE}/spotify/artists/search?q=${encodeURIComponent(q)}`,
        { headers: { Authorization: `Bearer ${token}` } }
      );

      if (!res.ok) {
        const txt = await res.text();
        throw new Error(txt);
      }

      const json = await res.json();
      setData(json);
    } catch (e: any) {
      console.log(e);
      alert(`Erreur API: ${e?.message ?? "unknown"}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={{ padding: 16, gap: 12 }}>
      <Text style={{ fontSize: 20, fontWeight: "700" }}>Spotify Tracker</Text>

      <Text>Status: {token ? "✅ connecté" : "❌ pas connecté"}</Text>

      <View style={{ flexDirection: "row", gap: 10 }}>
        <Button title="Login Spotify" onPress={login} />
        <Button title="Logout" onPress={logout} />
      </View>

      <TextInput
        value={q}
        onChangeText={setQ}
        placeholder="Rechercher un artiste"
        style={{ borderWidth: 1, borderColor: "#ccc", padding: 10, borderRadius: 10 }}
      />

      <Button title={loading ? "..." : "Search"} onPress={search} />

      <FlatList
        data={data}
        keyExtractor={(item) => item.spotifyId}
        renderItem={({ item }) => (
          <View style={{ flexDirection: "row", gap: 12, alignItems: "center", paddingVertical: 10 }}>
            {item.image ? (
              <Image source={{ uri: item.image }} style={{ width: 48, height: 48, borderRadius: 24 }} />
            ) : (
              <View style={{ width: 48, height: 48, borderRadius: 24, backgroundColor: "#ddd" }} />
            )}

            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 16, fontWeight: "600" }}>{item.name}</Text>
              <Text style={{ color: "#666" }}>
                {item.followers ? `${item.followers} followers` : ""}
                {item.popularity != null ? ` • pop ${item.popularity}` : ""}
              </Text>
            </View>
          </View>
        )}
      />
    </View>
  );
}

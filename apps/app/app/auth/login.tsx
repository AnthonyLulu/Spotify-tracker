import { useState } from "react";
import {
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

import { API_BASE } from "../../src/lib/api";
import { useAuthStore } from "../../src/store/authStore";

export default function Login() {
  const token = useAuthStore((s) => s.token);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const helperMessage = token
    ? "✅ Vous êtes déjà connecté."
    : "Connectez-vous pour lancer le suivi Spotify.";

  function loginSpotify() {
    if (Platform.OS === "web") {
      window.location.href = `${API_BASE}/auth/spotify/login/web`;
      return;
    }

    alert("Login mobile bientôt disponible via deep link.");
  }

  function loginWithCredentials() {
    alert("Connexion classique bientôt disponible.");
  }

  return (
    <View style={styles.container}>
      <View style={styles.hero}>
        <Text style={styles.logo}>Spotify Tracker</Text>
        <Text style={styles.subtitle}>Suivez vos artistes favoris en un clic.</Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.title}>Connexion</Text>
        <Text style={styles.helper}>{helperMessage}</Text>

        <View style={styles.form}>
          <TextInput
            autoCapitalize="none"
            keyboardType="email-address"
            placeholder="Email"
            placeholderTextColor="#9AA3AF"
            style={styles.input}
            value={email}
            onChangeText={setEmail}
          />
          <TextInput
            placeholder="Mot de passe"
            placeholderTextColor="#9AA3AF"
            secureTextEntry
            style={styles.input}
            value={password}
            onChangeText={setPassword}
          />
        </View>

        <Pressable style={styles.primaryButton} onPress={loginWithCredentials}>
          <Text style={styles.primaryButtonText}>Se connecter</Text>
        </Pressable>

        <Text style={styles.dividerText}>ou</Text>

        <Pressable style={styles.spotifyButton} onPress={loginSpotify}>
          <Text style={styles.spotifyButtonText}>Continuer avec Spotify</Text>
        </Pressable>
      </View>

      <Text style={styles.footerText}>
        Pas encore de compte ? Créez-en un dès que l'inscription sera ouverte.
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#0B0B0F",
    paddingHorizontal: 20,
    paddingTop: 60,
  },
  hero: {
    marginBottom: 28,
  },
  logo: {
    fontSize: 28,
    fontWeight: "700",
    color: "#FFFFFF",
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    color: "#C8CDD6",
  },
  card: {
    backgroundColor: "#12141B",
    borderRadius: 20,
    padding: 20,
    gap: 16,
    shadowColor: "#000",
    shadowOpacity: 0.2,
    shadowRadius: 10,
  },
  title: {
    fontSize: 20,
    fontWeight: "700",
    color: "#FFFFFF",
  },
  helper: {
    fontSize: 13,
    color: "#9AA3AF",
  },
  form: {
    gap: 12,
  },
  input: {
    borderWidth: 1,
    borderColor: "#262B35",
    borderRadius: 14,
    paddingHorizontal: 14,
    paddingVertical: 12,
    color: "#FFFFFF",
    backgroundColor: "#0F1117",
  },
  primaryButton: {
    backgroundColor: "#1F2937",
    borderRadius: 14,
    paddingVertical: 12,
    alignItems: "center",
  },
  primaryButtonText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "600",
  },
  dividerText: {
    textAlign: "center",
    color: "#6B7280",
    fontSize: 12,
    textTransform: "uppercase",
    letterSpacing: 1,
  },
  spotifyButton: {
    backgroundColor: "#1DB954",
    borderRadius: 14,
    paddingVertical: 12,
    alignItems: "center",
  },
  spotifyButtonText: {
    color: "#0B0B0F",
    fontSize: 15,
    fontWeight: "700",
  },
  footerText: {
    marginTop: 24,
    textAlign: "center",
    color: "#9AA3AF",
    fontSize: 12,
  },
});

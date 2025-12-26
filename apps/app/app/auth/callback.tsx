import { useEffect } from "react";
import { Text, View } from "react-native";
import { Redirect, useLocalSearchParams } from "expo-router";
import { useAuthStore } from "../../src/store/authStore";

export default function Callback() {
  const { token } = useLocalSearchParams<{ token?: string }>();
  const setToken = useAuthStore((s) => s.setToken);

  useEffect(() => {
    if (typeof token === "string" && token.length > 0) {
      setToken(token);
      console.log("✅ JWT reçu:", token);
    }
  }, [token, setToken]);

  if (typeof token !== "string" || token.length === 0) {
    return (
      <View style={{ padding: 16 }}>
        <Text>Token manquant dans l’URL.</Text>
      </View>
    );
  }

  return <Redirect href="/(tabs)" />;
}

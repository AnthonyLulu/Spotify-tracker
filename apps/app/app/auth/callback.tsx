import { useEffect } from "react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useAuthStore } from "../../src/store/authStore";

export default function Callback() {
  const { token } = useLocalSearchParams<{ token?: string }>();
  const setToken = useAuthStore((s) => s.setToken);
  const router = useRouter();

  useEffect(() => {
    if (token) {
      setToken(token);
      router.replace("/");
    }
  }, [token]);

  return null;
}

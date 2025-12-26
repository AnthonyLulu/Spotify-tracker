import { Platform } from "react-native";

// Web: 127.0.0.1 OK
// Android emulator: 10.0.2.2
// iOS simulator: 127.0.0.1
// Tel réel: IP du PC ou ngrok
export const API_BASE =
  Platform.OS === "web"
    ? "http://127.0.0.1:3001"
    : "http://10.0.2.2:3001";

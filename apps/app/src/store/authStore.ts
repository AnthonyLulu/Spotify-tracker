/*import { create } from "zustand";

type AuthState = {
  token: string | null;
  setToken: (token: string) => void;
  clearToken: () => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  setToken: (token) => set({ token }),
  clearToken: () => set({ token: null })
})); */

import { create } from "zustand";

type AuthState = {
  token: string | null;
  setToken: (t: string) => void;
  logout: () => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  setToken: (t) => set({ token: t }),
  logout: () => set({ token: null }),
}));

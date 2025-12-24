import jwt from "jsonwebtoken";

export function signJwt(payload: object) {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET manquant");
  return jwt.sign(payload, secret, { expiresIn: "7d" });
}

export function verifyJwt(token: string) {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET manquant");
  return jwt.verify(token, secret) as { userId: string };
}

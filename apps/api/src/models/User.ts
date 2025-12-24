import mongoose from "mongoose";

const UserSchema = new mongoose.Schema(
  {
    spotifyUserId: { type: String, required: true, unique: true },
    displayName: { type: String },
    refreshToken: { type: String, required: true }
  },
  { timestamps: true }
);

export const User = mongoose.model("User", UserSchema);

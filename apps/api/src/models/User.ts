import { Schema, model, type InferSchemaType } from "mongoose";

const userSchema = new Schema(
  {
    spotifyUserId: { type: String, required: true, unique: true, index: true },
    displayName: { type: String },
    refreshToken: { type: String, required: true },

    trackedArtistIds: [{ type: Schema.Types.ObjectId, ref: "Artist" }]
  },
  { timestamps: true }
);

export type UserDoc = InferSchemaType<typeof userSchema>;
export const User = model("User", userSchema);

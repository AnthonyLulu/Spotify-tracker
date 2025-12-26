import { Schema, model, type InferSchemaType } from "mongoose";

const artistSchema = new Schema(
  {
    spotifyId: { type: String, required: true, unique: true, index: true },
    name: { type: String, required: true },
    genres: { type: [String], default: [] },
    popularity: { type: Number },
    followers: { type: Number },
    image: { type: String }
  },
  { timestamps: true }
);

// (optionnel, mais j’aime bien être explicite)
artistSchema.index({ spotifyId: 1 }, { unique: true });

export type ArtistDoc = InferSchemaType<typeof artistSchema>;
export const Artist = model("Artist", artistSchema);

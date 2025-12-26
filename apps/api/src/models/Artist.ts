import { Schema, model, type InferSchemaType } from "mongoose";

const artistSchema = new Schema(
  {
    spotifyId: { type: String, required: true, unique: true, index: true },
    name: { type: String, required: true, index: true },
    genres: { type: [String], default: [] },
    image: { type: String },
    followers: { type: Number },
    popularity: { type: Number },
    officialUrl: { type: String }
  },
  { timestamps: true }
);

export type ArtistDoc = InferSchemaType<typeof artistSchema>;
export const Artist = model("Artist", artistSchema);

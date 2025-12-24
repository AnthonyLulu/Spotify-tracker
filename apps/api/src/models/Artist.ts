import mongoose from "mongoose";

const ArtistSchema = new mongoose.Schema(
  {
    spotifyId: { type: String, required: true, unique: true },
    name: { type: String, required: true },
    genres: { type: [String], default: [] },
    popularity: { type: Number },
    followers: { type: Number },
    image: { type: String }
  },
  { timestamps: true }
);

export const Artist = mongoose.model("Artist", ArtistSchema);
import { Schema, model, type InferSchemaType } from "mongoose";

export type EventSource = "ticketmaster" | "songkick" | "scraping" | "spotify";

const eventSchema = new Schema(
  {
    // 🔥 origine de l'event (anti-doublons multi sources)
    source: {
      type: String,
      required: true,
      enum: ["ticketmaster", "songkick", "scraping", "spotify"],
      index: true
    },

    // 🔥 id externe (ex: id Ticketmaster)
    externalId: { type: String, required: true, index: true },

    artistId: { type: Schema.Types.ObjectId, ref: "Artist", required: true, index: true },
    artistName: { type: String, required: true }, // denormalize utile

    siteId: { type: Schema.Types.ObjectId, ref: "Site", required: true, index: true },

    url: { type: String, required: true },
    venue: { type: String },
    city: { type: String },
    date: { type: Date, index: true },

    eventTypeId: { type: Schema.Types.ObjectId, ref: "EventType", required: true },

    lastAvailability: { type: Boolean, default: null },
    lastCheckAt: { type: Date, default: null }
  },
  { timestamps: true }
);

// ✅ anti doublons fiable : même event renvoyé 50 fois -> upsert tranquille
eventSchema.index({ source: 1, externalId: 1 }, { unique: true });

// (optionnel) tu peux garder celui-là si tu veux aussi bloquer des doublons url/site
// eventSchema.index({ siteId: 1, url: 1 }, { unique: true });

export type EventDoc = InferSchemaType<typeof eventSchema>;
export const Event = model("Event", eventSchema);

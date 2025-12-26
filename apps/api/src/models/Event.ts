import { Schema, model, Types, type InferSchemaType } from "mongoose";

const eventSchema = new Schema(
  {
    artistId: { type: Schema.Types.ObjectId, ref: "Artist", required: true, index: true },
    artistName: { type: String, required: true }, // petit denormalize utile

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

// Unicité logique (évite doublons : même event sur même site + même url)
eventSchema.index({ siteId: 1, url: 1 }, { unique: true });

export type EventDoc = InferSchemaType<typeof eventSchema>;
export const Event = model("Event", eventSchema);

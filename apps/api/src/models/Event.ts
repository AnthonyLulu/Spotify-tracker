import { Schema, model, type InferSchemaType } from "mongoose";

const eventSchema = new Schema(
  {
    // lien vers l'artiste
    artistId: { type: Schema.Types.ObjectId, ref: "Artist", required: true, index: true },
    artistName: { type: String, required: true }, // denormalize utile (affichage)

    // lien vers le "site/source" (Ticketmaster = un site)
    siteId: { type: Schema.Types.ObjectId, ref: "Site", required: true, index: true },

    // ✅ NOUVEAU : origine de la donnée
    // (tu peux enlever enum si tu veux être plus flexible)
    source: {
      type: String,
      required: true,
      enum: ["ticketmaster", "songkick", "scraping"]
    },

    // ✅ NOUVEAU : id externe (Ticketmaster id, Songkick id, etc.)
    externalId: { type: String, required: true },

    // infos event
    url: { type: String }, // plus "required" (parfois t'auras pas une URL stable)
    venue: { type: String },
    city: { type: String },
    date: { type: Date, index: true },

    eventTypeId: { type: Schema.Types.ObjectId, ref: "EventType", required: true },

    // dispo tracking
    lastAvailability: { type: Boolean, default: null },
    lastCheckAt: { type: Date, default: null }
  },
  { timestamps: true }
);

/**
 * ✅ Index principal anti-doublon : 1 event externe = 1 doc Mongo
 * Exemple : ("ticketmaster", "G5vYZ...") unique
 */
eventSchema.index({ source: 1, externalId: 1 }, { unique: true });

/**
 * ✅ Index secondaire utile pour scraping
 * (évite doublons basés sur URL quand source = scraping)
 * Sparse => ne casse pas si url est null/undefined
 */
eventSchema.index({ siteId: 1, url: 1 }, { unique: true, sparse: true });

export type EventDoc = InferSchemaType<typeof eventSchema>;
export const Event = model("Event", eventSchema);
